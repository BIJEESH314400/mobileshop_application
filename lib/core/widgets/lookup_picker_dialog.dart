import 'package:flutter/material.dart';

import '../repositories/lookup_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

/// Below this many options, the list is short enough to just scan —
/// the search bar only earns its place once there's actually something
/// to scroll through.
const int _searchVisibleThreshold = 5;

/// A picker bottom sheet backed by a live Firestore list, with a
/// built-in "add new" row — so picking "Category" or "Brand" and
/// adding a brand-new one someone hasn't used before are the same
/// sheet, not a separate settings page to go find. Generic over which
/// Firestore collection it reads/writes, so one widget serves both the
/// Category and Brand pickers instead of two near-identical ones.
class LookupPickerDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final String itemLabel;
  final String collection;
  final String? selected;

  const LookupPickerDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.itemLabel,
    required this.collection,
    this.selected,
  });

  /// Shows the picker as a bottom sheet and returns the name the
  /// person picked (or the one they just added), or null if they
  /// dismissed it without choosing.
  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String itemLabel,
    required String collection,
    String? selected,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Off, on purpose: the sheet's own drag-to-close gesture was
      // fighting with the category/brand list's scroll gesture right
      // underneath it, which is what caused the vibrate/blink when
      // scrolling. The X button and tapping outside still close it.
      enableDrag: false,
      builder: (_) => LookupPickerDialog(
        title: title,
        subtitle: subtitle,
        itemLabel: itemLabel,
        collection: collection,
        selected: selected,
      ),
    );
  }

  @override
  State<LookupPickerDialog> createState() => _LookupPickerDialogState();
}

class _LookupPickerDialogState extends State<LookupPickerDialog> {
  final _repository = LookupRepository();
  final _searchController = TextEditingController();
  final _newNameController = TextEditingController();
  String _query = '';
  bool _adding = false;

  @override
  void dispose() {
    _searchController.dispose();
    _newNameController.dispose();
    super.dispose();
  }

  Future<void> _addNew() async {
    final name = _newNameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _adding = true);
    try {
      await _repository.addName(widget.collection, name);
      // Popping with the typed name (rather than waiting for the stream
      // to push it back) means the sheet closes immediately instead of
      // the person watching their own entry pop into the list first.
      if (mounted) {
        Navigator.of(context).pop(name);
      }
    } catch (_) {
      // Without this, a failed write (e.g. Firestore rules blocking it)
      // left the spinner running forever with no explanation.
      if (mounted) {
        setState(() => _adding = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save — check your connection and try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      // Pushes the whole sheet up above the keyboard when the search or
      // "add custom" field is focused, instead of the keyboard covering it.
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(color: p.border, borderRadius: BorderRadius.circular(999)),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.textPrimary),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.subtitle,
                              style: TextStyle(fontSize: 12.5, color: p.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(color: p.background, shape: BoxShape.circle),
                          child: Icon(Icons.close_rounded, size: 16, color: p.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: StreamBuilder<List<String>>(
                      stream: _repository.watchNames(widget.collection),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 28),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2.2)),
                          );
                        }
                        final allNames = snapshot.data ?? const <String>[];

                        if (allNames.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'No options yet — add the first one below.',
                              style: TextStyle(fontSize: 13, color: p.textSecondary),
                            ),
                          );
                        }

                        // Search only earns its place once there's enough
                        // to actually scroll through — checked against the
                        // full list so it doesn't flicker away mid-search.
                        final showSearch = allNames.length > _searchVisibleThreshold;
                        final names = showSearch && _query.isNotEmpty
                            ? allNames.where((name) => name.toLowerCase().contains(_query)).toList()
                            : allNames;

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showSearch) ...[
                              Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: p.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: p.border),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.search_rounded, size: 18, color: p.textSecondary),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                                        style: TextStyle(fontSize: 13.5, color: p.textPrimary),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          border: InputBorder.none,
                                          hintText: 'Search ${widget.itemLabel}...',
                                          hintStyle: TextStyle(fontSize: 13.5, color: p.textSecondary),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            Flexible(
                              child: names.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Text(
                                        'No match for "${_searchController.text.trim()}"',
                                        style: TextStyle(fontSize: 13, color: p.textSecondary),
                                      ),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.zero,
                                      itemCount: names.length,
                                      itemBuilder: (context, i) {
                                        final name = names[i];
                                        final isSelected = name == widget.selected;
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 4),
                                          child: GestureDetector(
                                            onTap: () => Navigator.of(context).pop(name),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                              decoration: BoxDecoration(
                                                color: isSelected ? AppColors.iconTint : Colors.transparent,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      name,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: isSelected ? AppColors.accent : p.textPrimary,
                                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                  _RadioDot(selected: isSelected, palette: p),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "CAN'T FIND A ${widget.itemLabel.toUpperCase()}?",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.textSecondary, letterSpacing: 0.4),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newNameController,
                          style: TextStyle(fontSize: 14, color: p.textPrimary),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Add custom ${widget.itemLabel}...',
                            hintStyle: TextStyle(fontSize: 13, color: p.textSecondary),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.border)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.accent)),
                          ),
                          onSubmitted: (_) => _adding ? null : _addNew(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _adding ? null : _addNew,
                        child: Container(
                          height: 46,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                          child: Center(
                            child: _adding
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                                  )
                                : const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_rounded, color: Colors.white, size: 18),
                                      SizedBox(width: 4),
                                      Text('Add', style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The purple filled check-circle (selected) / outline circle (not
/// selected) on the right side of each row — matches the radio-style
/// indicator in the design.
class _RadioDot extends StatelessWidget {
  final bool selected;
  final AppPalette palette;

  const _RadioDot({required this.selected, required this.palette});

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, size: 13, color: Colors.white),
      );
    }
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: palette.border, width: 1.5)),
    );
  }
}
