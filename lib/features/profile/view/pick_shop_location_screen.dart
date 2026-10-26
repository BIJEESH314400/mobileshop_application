import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/app_logger.dart';

/// What `PickShopLocationScreen` hands back once "Use This Location"
/// is tapped -- a resolved, human-readable address (best-effort, may
/// be empty if reverse geocoding failed) plus the exact coordinates,
/// which Shop Details saves alongside the typed address text.
class PickedShopLocation {
  final String address;
  final double latitude;
  final double longitude;
  const PickedShopLocation({required this.address, required this.latitude, required this.longitude});
}

/// One candidate place from a text search ("Kozhikode", "MG Road
/// Kochi", ...) -- `label` is a best-effort reverse-geocoded
/// description of `point`, shown so the owner can tell two
/// same-named places apart (e.g. two towns called Kozhikode in
/// different states) before picking one.
class _SearchResult {
  final String label;
  final LatLng point;
  const _SearchResult({required this.label, required this.point});
}

/// A free, no-API-key map (OpenStreetMap tiles via `flutter_map`) for
/// pinning the shop's exact location -- opened from Shop Details'
/// "Pick on Map" link next to the Address field. Starts centered on
/// the device's current GPS position (or `initialLatLng`, if Shop
/// Details already has a saved pin, e.g. when re-opening to adjust
/// it) -- falls back to a plain India-wide view if location can't be
/// read at all, so the screen is always usable, just without a
/// pre-picked starting point.
///
/// Deliberately a tap-to-place pin, not a draggable marker -- tapping
/// anywhere on the map moves the pin there, which needs no extra
/// gesture-handling package and is simple enough that exact placement
/// just takes one or two taps (zoom in, tap again to fine-tune).
///
/// A search box at the top (added 2026-10-19) lets the owner type a
/// place/city name, see a short list of matches, and tap one to jump
/// straight there -- the map still re-centers rather than guessing a
/// single "best" match, since a name like "Kozhikode" can be
/// ambiguous. Picking a search result still leaves the tap-to-
/// fine-tune behavior above available afterward.
class PickShopLocationScreen extends StatefulWidget {
  final LatLng? initialLatLng;
  const PickShopLocationScreen({super.key, this.initialLatLng});

  @override
  State<PickShopLocationScreen> createState() => _PickShopLocationScreenState();
}

// Roughly the geographic center of India -- only ever shown when GPS
// can't be read AND no `initialLatLng` was passed in, so the map still
// opens to something sensible rather than the middle of the ocean
// (LatLng(0, 0)).
const LatLng _fallbackCenter = LatLng(20.5937, 78.9629);

class _PickShopLocationScreenState extends State<PickShopLocationScreen> {
  final _mapController = MapController();

  bool _loadingInitial = true;
  LatLng? _picked;
  String? _resolvedAddress;
  bool _resolvingAddress = false;
  String? _locationNotice;
  bool _locatingNow = false;

  final _searchCtrl = TextEditingController();
  bool _searching = false;
  List<_SearchResult> _searchResults = [];
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (widget.initialLatLng != null) {
      _picked = widget.initialLatLng;
    } else {
      final point = await _readCurrentLocation();
      if (point == null) {
        _locationNotice = "Couldn't get your current location -- tap the map to pick your shop's spot.";
      } else {
        _picked = point;
      }
    }
    if (_picked != null) {
      unawaited(_reverseGeocode(_picked!));
    }
    if (mounted) setState(() => _loadingInitial = false);
  }

  /// Returns the device's current position as a [LatLng], or `null` if
  /// location services are off, permission is denied, or the read
  /// itself fails for any other reason -- every case fails safe to
  /// "just show the fallback map", never a crash or a stuck spinner.
  Future<LatLng?> _readCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition();
      return LatLng(position.latitude, position.longitude);
    } catch (e, st) {
      AppLogger.error('PickShopLocationScreen._readCurrentLocation', e, st);
      return null;
    }
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _resolvingAddress = true);
    try {
      final placemarks = await placemarkFromCoordinates(point.latitude, point.longitude);
      String address = '';
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        address = [p.street, p.subLocality, p.locality, p.administrativeArea, p.postalCode]
            .where((part) => part != null && part.trim().isNotEmpty)
            .join(', ');
      }
      if (!mounted) return;
      setState(() {
        _resolvedAddress = address;
        _resolvingAddress = false;
      });
    } catch (e, st) {
      AppLogger.error('PickShopLocationScreen._reverseGeocode', e, st);
      if (!mounted) return;
      setState(() {
        _resolvedAddress = null;
        _resolvingAddress = false;
      });
    }
  }

  void _onMapTapped(LatLng point) {
    setState(() {
      _picked = point;
      _locationNotice = null;
    });
    unawaited(_reverseGeocode(point));
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locatingNow = true);
    final point = await _readCurrentLocation();
    if (!mounted) return;
    setState(() => _locatingNow = false);
    if (point == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text("Couldn't get your location -- check that location is turned on.")));
      return;
    }
    setState(() {
      _picked = point;
      _locationNotice = null;
    });
    _mapController.move(point, 16);
    unawaited(_reverseGeocode(point));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Forward-geocodes the typed place/city name into one or more
  /// candidate coordinates (the device's own native geocoder, same
  /// one `_reverseGeocode` already uses, just the other direction --
  /// no API key, no network call this app manages itself). Each
  /// candidate is then reverse-geocoded back into a short label so
  /// the results list reads as real places, not bare coordinates --
  /// a handful of extra geocoder calls is fine since there are only
  /// ever a few candidates.
  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _searchError = null;
      _searchResults = [];
    });
    try {
      final locations = await locationFromAddress(q);
      if (!mounted) return;
      if (locations.isEmpty) {
        setState(() {
          _searching = false;
          _searchError = 'No places found for "$q"';
        });
        return;
      }
      final results = <_SearchResult>[];
      for (final loc in locations.take(5)) {
        final point = LatLng(loc.latitude, loc.longitude);
        String label = '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
        try {
          final placemarks = await placemarkFromCoordinates(point.latitude, point.longitude);
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final parts = [p.name, p.locality, p.administrativeArea, p.country]
                .where((part) => part != null && part.trim().isNotEmpty)
                .toSet() // drop an exact duplicate (e.g. name == locality)
                .join(', ');
            if (parts.isNotEmpty) label = parts;
          }
        } catch (e, st) {
          AppLogger.error('PickShopLocationScreen._search (reverse)', e, st);
          // Keep the coordinate fallback label -- one bad reverse
          // lookup shouldn't drop an otherwise-valid search result.
        }
        results.add(_SearchResult(label: label, point: point));
      }
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchResults = results;
      });
    } catch (e, st) {
      AppLogger.error('PickShopLocationScreen._search', e, st);
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchError = "Couldn't search right now -- check your connection.";
      });
    }
  }

  void _selectSearchResult(_SearchResult result) {
    setState(() {
      _picked = result.point;
      _resolvedAddress = result.label;
      _resolvingAddress = false;
      _locationNotice = null;
      _searchResults = [];
      _searchError = null;
    });
    _mapController.move(result.point, 16);
  }

  void _confirm() {
    final picked = _picked;
    if (picked == null) return;
    Navigator.of(context).pop(PickedShopLocation(
      address: _resolvedAddress ?? '',
      latitude: picked.latitude,
      longitude: picked.longitude,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    if (_loadingInitial) {
      return Scaffold(
        backgroundColor: p.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              decoration: BoxDecoration(
                color: p.background,
                border: Border(bottom: BorderSide(color: p.border)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_back_rounded, size: 20, color: p.textPrimary),
                        const SizedBox(width: 14),
                        Text('Pick Shop Location', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: p.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: BoxDecoration(
                color: p.background,
                border: Border(bottom: BorderSide(color: p.border)),
              ),
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 18, color: p.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _search,
                        onChanged: (_) => setState(() {}), // live-update the clear (x) icon
                        style: TextStyle(fontSize: 13.5, color: p.textPrimary),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: 'Search for a city or place...',
                          hintStyle: TextStyle(fontSize: 13.5, color: p.textSecondary),
                        ),
                      ),
                    ),
                    if (_searching)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (_searchCtrl.text.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(() {
                          _searchCtrl.clear();
                          _searchResults = [];
                          _searchError = null;
                        }),
                        child: Icon(Icons.close_rounded, size: 16, color: p.textSecondary),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _picked ?? _fallbackCenter,
                      initialZoom: _picked != null ? 16 : 5,
                      onTap: (_, point) => _onMapTapped(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.fourbmobiles.app',
                      ),
                      MarkerLayer(
                        markers: [
                          if (_picked != null)
                            Marker(
                              point: _picked!,
                              width: 40,
                              height: 40,
                              child: Icon(Icons.location_pin, size: 40, color: AppColors.accent),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton.small(
                      heroTag: 'shopLocationMyLocation',
                      backgroundColor: p.card,
                      foregroundColor: AppColors.accent,
                      onPressed: _locatingNow ? null : _useCurrentLocation,
                      child: _locatingNow
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location_rounded),
                    ),
                  ),
                  if (_searchResults.isNotEmpty)
                    Positioned(
                      top: 10,
                      left: 16,
                      right: 16,
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 260),
                        decoration: BoxDecoration(
                          color: p.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: p.border),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: p.border),
                          itemBuilder: (_, i) {
                            final result = _searchResults[i];
                            return GestureDetector(
                              onTap: () => _selectSearchResult(result),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    Icon(Icons.place_outlined, size: 17, color: AppColors.accent),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        result.label,
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.textPrimary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    )
                  else if (_searchError != null)
                    Positioned(
                      top: 10,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: p.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: p.border),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                        ),
                        child: Text(_searchError!, style: const TextStyle(fontSize: 12.5, color: AppColors.danger)),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: BoxDecoration(
                color: p.card,
                border: Border(top: BorderSide(color: p.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_locationNotice != null) ...[
                    Text(_locationNotice!, style: TextStyle(fontSize: 12, color: p.textSecondary)),
                    const SizedBox(height: 10),
                  ] else if (_picked == null) ...[
                    Text('Tap anywhere on the map to drop a pin.', style: TextStyle(fontSize: 12, color: p.textSecondary)),
                    const SizedBox(height: 10),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on_rounded, size: 16, color: AppColors.accent),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _resolvingAddress
                              ? Text('Finding address...', style: TextStyle(fontSize: 12.5, color: p.textSecondary))
                              : Text(
                                  (_resolvedAddress == null || _resolvedAddress!.isEmpty)
                                      ? '${_picked!.latitude.toStringAsFixed(5)}, ${_picked!.longitude.toStringAsFixed(5)}'
                                      : _resolvedAddress!,
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.textPrimary),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  GestureDetector(
                    onTap: _picked == null ? null : _confirm,
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _picked == null ? AppColors.accent.withOpacity(0.4) : AppColors.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Use This Location', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

