import 'package:flutter/material.dart';

import '../repositories/lookup_repository.dart';
import '../routes/app_routes.dart';
import '../routes/root_navigator_key.dart';
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

  /// When set, both the shown list and any name added from here are
  /// scoped to this category (see [LookupRepository.watchNames] /
  /// [LookupRepository.addName] for exactly what that filtering does).
  /// Left null for pickers that don't have a category to scope by
  /// (the Category picker itself, for one).
  final String? filterCategory;

  const LookupPickerDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.itemLabel,
    required this.collection,
    this.selected,
    this.filterCategory,
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
    String? filterCategory,
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
        filterCategory: filterCategory,
      ),
    );
  }

  @override
  State<LookupPickerDialog> createState() => _LookupPickerDialogState();
}

class _LookupPickerDialogState extends State<LookupPickerDialog> {
  final _repository = LookupRepository();
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Closes this picker and opens the owner-only Manage Categories &
  /// Brands screen -- the one place a new category/brand can actually
  /// be created now (see that screen and `firestore.rules`). Reached
  /// by everyone, owner or employee: there's no separate check here
  /// for whether to *show* this row (that's what caused the jank/blink
  /// bug -- the row used to wait on an async owner lookup before
  /// appearing, shifting the whole sheet's layout once it resolved).
  /// An employee who taps it just gets bounced straight back out by
  /// `OwnerOnlyGate` on that screen, same as reaching any other
  /// owner-only route directly -- the real gate lives there and in
  /// the Firestore rules, not in this picker.
  void _goToManageCategories() {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      rootNavigatorKey.currentState?.pushNamed(AppRoutes.manageCategories);
    });
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
                      stream: _repository.watchNames(widget.collection, category: widget.filterCategory),
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
                                            onTap: () {
                                              // Fire-and-forget: this list only ever shows a
                                              // name that's untagged or already matches
                                              // filterCategory, so this can only fill in a
                                              // blank, never overwrite an existing tag -- and
                                              // the picker shouldn't wait on it to close.
                                              if (widget.filterCategory != null) {
                                                _repository.tagExistingIfUntagged(
                                                  widget.collection,
                                                  name,
                                                  widget.filterCategory!,
                                                );
                                              }
                                              Navigator.of(context).pop(name);
                                            },
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
                  // No inline "add it here" box any more -- creating a
                  // brand-new category/brand is now only done from the
                  // owner-only Manage Categories & Brands screen (see
                  // `_goToManageCategories` above for why this row itself
                  // isn't conditionally hidden).
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: _goToManageCategories,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: p.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: p.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.category_outlined, size: 17, color: p.textSecondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Can't find a ${widget.itemLabel}? Manage Categories & Brands",
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: p.textPrimary),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, size: 18, color: p.textSecondary),
                        ],
                      ),
                    ),
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
        decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
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
