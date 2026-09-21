import 'package:flutter/material.dart';

import '../repositories/lookup_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

/// A picker popup backed by a live Firestore list, with a built-in
/// "add new" row at the bottom — so picking "Category" or "Brand" and
/// adding a brand-new one someone hasn't used before are the same
/// screen, not a separate settings page to go find. Generic over which
/// Firestore collection it reads/writes, so one widget serves both the
/// Category and Brand pickers instead of two near-identical ones.
class LookupPickerDialog extends StatefulWidget {
  final String title;
  final String collection;
  final String? selected;

  const LookupPickerDialog({
    super.key,
    required this.title,
    required this.collection,
    this.selected,
  });

  /// Shows the dialog and returns the name the person picked (or the
  /// one they just added), or null if they dismissed it without
  /// choosing.
  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String collection,
    String? selected,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => LookupPickerDialog(title: title, collection: collection, selected: selected),
    );
  }

  @override
  State<LookupPickerDialog> createState() => _LookupPickerDialogState();
}

class _LookupPickerDialogState extends State<LookupPickerDialog> {
  final _repository = LookupRepository();
  final _newNameController = TextEditingController();
  bool _adding = false;

  @override
  void dispose() {
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
      // to push it back) means the picker closes immediately instead of
      // the person watching their own entry pop into the list first.
      if (mounted) {
        Navigator.of(context).pop(name);
      }
    } catch (_) {
      // Without this, a failed write (e.g. Firestore rules blocking it)
      // left the spinner running forever with no explanation — this is
      // the exact "progress running only" bug.
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

    return Dialog(
      backgroundColor: p.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.textPrimary),
              ),
              const SizedBox(height: 12),
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
                    final names = snapshot.data ?? const <String>[];
                    if (names.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No options yet — add the first one below.',
                          style: TextStyle(fontSize: 13, color: p.textSecondary),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: names.length,
                      itemBuilder: (context, i) {
                        final name = names[i];
                        final isSelected = name == widget.selected;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            name,
                            style: TextStyle(
                              fontSize: 14,
                              color: p.textPrimary,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_rounded, color: AppColors.accent, size: 18)
                              : null,
                          onTap: () => Navigator.of(context).pop(name),
                        );
                      },
                    );
                  },
                ),
              ),
              Divider(height: 24, color: p.border),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newNameController,
                      style: TextStyle(fontSize: 14, color: p.textPrimary),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Add new...',
                        hintStyle: TextStyle(fontSize: 13, color: p.textSecondary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: p.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent)),
                      ),
                      onSubmitted: (_) => _adding ? null : _addNew(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _adding ? null : _addNew,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
                      child: _adding
                          ? const Padding(
                              padding: EdgeInsets.all(11),
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                            )
                          : const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
