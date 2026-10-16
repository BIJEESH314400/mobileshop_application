import 'package:flutter/material.dart';

import '../../../core/repositories/lookup_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/text_case.dart';
import '../../../core/widgets/confirm_delete_dialog.dart';
import '../../../core/widgets/lookup_picker_dialog.dart';
import '../../../core/widgets/owner_only_gate.dart';

/// Owner-only screen for managing the shop's product taxonomy itself:
/// which categories exist, and which brands belong under which
/// category. Replaces the old, narrower "Manage Brands" screen (which
/// only let the owner re-tag an existing brand's category) -- this one
/// also adds and removes categories and brands outright, matching the
/// owner's request to be able to "add category and add corresponding
/// brand above added category" and "remove category" as the shop's
/// real-world product range changes (not deployed to a client yet, so
/// this is still free to evolve).
///
/// Wrapped in [OwnerOnlyGate] the same way Staff Management is --
/// someone who reaches this route directly without being signed in as
/// the owner gets bounced straight back out. The real backstop is in
/// `firestore.rules` (categories/brands writes are owner-only there
/// too), this is just so an employee never even sees the screen.
class ManageBrandsScreen extends StatelessWidget {
  const ManageBrandsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const OwnerOnlyGate(child: _ManageCategoriesView());
  }
}

class _ManageCategoriesView extends StatefulWidget {
  const _ManageCategoriesView();

  @override
  State<_ManageCategoriesView> createState() => _ManageCategoriesViewState();
}

class _ManageCategoriesViewState extends State<_ManageCategoriesView> {
  final _repository = LookupRepository();

  /// Opens the "Add Category" bottom sheet -- styled to match Add
  /// Product's own form fields (`_FieldLabel` + `_FieldBox`, below)
  /// rather than a generic Material dialog, per the owner's feedback
  /// that the old plain popup "didn't follow our design." Lets the
  /// owner add the new category's first brand in the same step
  /// (optional) instead of always needing a second trip through
  /// "+ Brand" on the category card right after.
  Future<void> _addCategory() async {
    final result = await showModalBottomSheet<_AddCategoryResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddCategorySheet(),
    );
    if (result == null) return;
    await _repository.addName('categories', result.categoryName);
    if (result.brandName != null) {
      await _repository.addName('brands', result.brandName!, category: result.categoryName);
    }
    // Shown from THIS screen's own context (a real Scaffold), not
    // from inside the sheet -- a SnackBar raised while the modal
    // bottom sheet is still on screen renders underneath it (the
    // sheet sits above the Scaffold in the stacking order), so it was
    // invisible until the sheet closed. By the time we get here the
    // sheet is already gone, so the SnackBar shows normally.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.brandName != null
              ? 'Added "${result.categoryName}" with brand "${result.brandName}"'
              : 'Added "${result.categoryName}"',
        ),
      ),
    );
  }

  /// Opens the "Add Brand" bottom sheet for an existing category --
  /// same field styling as [_addCategory]'s sheet, just the one
  /// required Brand Name field (the category is already fixed, from
  /// whichever card's "+ Brand" button was tapped).
  Future<void> _addBrand(String category) async {
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddBrandSheet(category: category),
    );
    if (name == null) return;
    await _repository.addName('brands', name, category: category);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added "$name" to "$category"')),
    );
  }

  /// Opens the "Rename Category" sheet, pre-filled with the current
  /// name -- the equivalent, for a category, of the pencil icon a
  /// brand row already had (which lets the owner change a BRAND's
  /// category; a category has no parent to reassign, so its own
  /// equivalent edit action is renaming its own name instead).
  /// Cascades through [LookupRepository.renameCategory] -- see that
  /// method's own doc comment for exactly what else gets updated.
  Future<void> _renameCategory(String oldName) async {
    final newName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RenameCategorySheet(currentName: oldName),
    );
    if (newName == null) return;
    final renamed = await _repository.renameCategory(oldName, newName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          renamed ? 'Renamed "$oldName" to "$newName"' : 'A category named "$newName" already exists',
        ),
        backgroundColor: renamed ? null : AppColors.danger,
      ),
    );
  }

  /// Opens the "Rename Brand" sheet, pre-filled with the current
  /// name -- the brand-name equivalent of [_renameCategory] above.
  /// This is a different action from the brand row's OTHER pencil
  /// icon (`onEditBrandCategory` / [_setBrandCategory]), which only
  /// ever reassigns which category the brand sits under and never
  /// touches its name -- the two icons are now visually distinct so
  /// they don't get confused with each other. Cascades through
  /// [LookupRepository.renameBrand] -- see that method's own doc
  /// comment for exactly what else gets updated.
  Future<void> _renameBrand(String oldName) async {
    final newName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RenameBrandSheet(currentName: oldName),
    );
    if (newName == null) return;
    final renamed = await _repository.renameBrand(oldName, newName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          renamed ? 'Renamed "$oldName" to "$newName"' : 'A brand named "$newName" already exists',
        ),
        backgroundColor: renamed ? null : AppColors.danger,
      ),
    );
  }

  Future<void> _deleteCategory(String name, int brandCount) async {
    final message = brandCount == 0
        ? 'This category has no brands under it. This can\'t be undone.'
        : '$brandCount brand${brandCount == 1 ? '' : 's'} filed under "$name" will become uncategorized (they\'ll show up under every category again until reassigned). The brands themselves won\'t be deleted. This can\'t be undone.';
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Delete "$name"?',
      message: message,
      confirmLabel: 'Delete Category',
      cancelLabel: 'Keep Category',
    );
    if (!confirmed) return;
    await _repository.deleteCategory(name);
  }

  Future<void> _deleteBrand(String name) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Delete "$name"?',
      message: 'This removes the brand from every picker. Products already saved with this brand keep showing it as text -- this only stops it being offered again. This can\'t be undone.',
      confirmLabel: 'Delete Brand',
      cancelLabel: 'Keep Brand',
    );
    if (!confirmed) return;
    await _repository.deleteBrand('brands', name);
  }

  Future<void> _setBrandCategory(String brandName, String? currentCategory) async {
    final picked = await LookupPickerDialog.show(
      context,
      title: 'Select Category',
      subtitle: 'Category for "$brandName"',
      itemLabel: 'category',
      collection: 'categories',
      selected: currentCategory,
    );
    if (picked == null) return;
    await _repository.setCategory('brands', brandName, picked);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

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
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Row(
                        children: [
                          Icon(Icons.arrow_back_rounded, size: 20, color: p.textPrimary),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Manage Categories & Brands',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: p.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _addCategory,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text('New', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                'Add or remove categories, and the brands filed under each one.',
                style: TextStyle(fontSize: 12.5, color: p.textSecondary),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<LookupEntry>>(
                stream: _repository.watchEntries('categories'),
                builder: (context, categorySnapshot) {
                  if (!categorySnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
                  }
                  final categories = categorySnapshot.data!;

                  return StreamBuilder<List<LookupEntry>>(
                    stream: _repository.watchEntries('brands'),
                    builder: (context, brandSnapshot) {
                      final brands = brandSnapshot.data ?? const <LookupEntry>[];

                      if (categories.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No categories yet — tap "+ Category" above to add the first one.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: p.textSecondary, fontSize: 14),
                            ),
                          ),
                        );
                      }

                      final uncategorizedBrands = brands.where((b) => b.category.isEmpty).toList();

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        children: [
                          for (final category in categories)
                            _CategoryCard(
                              palette: p,
                              category: category.name,
                              brands: brands.where((b) => b.category == category.name).toList(),
                              onAddBrand: () => _addBrand(category.name),
                              onEditCategory: () => _renameCategory(category.name),
                              onDeleteCategory: (count) => _deleteCategory(category.name, count),
                              onDeleteBrand: _deleteBrand,
                              onEditBrandCategory: _setBrandCategory,
                              onEditBrandName: _renameBrand,
                            ),
                          if (uncategorizedBrands.isNotEmpty)
                            _CategoryCard(
                              palette: p,
                              category: null,
                              brands: uncategorizedBrands,
                              onAddBrand: null,
                              onEditCategory: null,
                              onDeleteCategory: null,
                              onDeleteBrand: _deleteBrand,
                              onEditBrandCategory: _setBrandCategory,
                              onEditBrandName: _renameBrand,
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One category's card: its name, an edit (rename) button and a
/// delete button (both skipped for the "Uncategorized" pseudo-
/// category, which isn't a real category doc and can't be renamed or
/// deleted), an "+ Add brand" action, and every brand currently filed
/// under it.
class _CategoryCard extends StatelessWidget {
  final AppPalette palette;
  final String? category; // null = the "Uncategorized" bucket
  final List<LookupEntry> brands;
  final VoidCallback? onAddBrand;
  final VoidCallback? onEditCategory;
  final void Function(int brandCount)? onDeleteCategory;
  final void Function(String brandName) onDeleteBrand;
  final void Function(String brandName, String? currentCategory) onEditBrandCategory;
  final void Function(String brandName) onEditBrandName;

  const _CategoryCard({
    required this.palette,
    required this.category,
    required this.brands,
    required this.onAddBrand,
    required this.onEditCategory,
    required this.onDeleteCategory,
    required this.onDeleteBrand,
    required this.onEditBrandCategory,
    required this.onEditBrandName,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final isUncategorized = category == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isUncategorized ? 'Uncategorized' : category!,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isUncategorized ? AppColors.danger : p.textPrimary,
                  ),
                ),
              ),
              if (onAddBrand != null)
                GestureDetector(
                  onTap: onAddBrand,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: p.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: p.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 14, color: p.textPrimary),
                        const SizedBox(width: 3),
                        Text('Brand', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: p.textPrimary)),
                      ],
                    ),
                  ),
                ),
              if (onEditCategory != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onEditCategory,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(color: p.background, shape: BoxShape.circle),
                    child: Icon(Icons.edit_outlined, size: 15, color: p.textSecondary),
                  ),
                ),
              ],
              if (onDeleteCategory != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => onDeleteCategory!(brands.length),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger),
                  ),
                ),
              ],
            ],
          ),
          if (isUncategorized) ...[
            const SizedBox(height: 4),
            Text(
              'Shows under every category until reassigned.',
              style: TextStyle(fontSize: 11.5, color: p.textSecondary),
            ),
          ],
          if (brands.isEmpty) ...[
            const SizedBox(height: 10),
            Text('No brands yet.', style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
          ] else ...[
            const SizedBox(height: 10),
            for (final brand in brands)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: p.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          brand.name,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: p.textPrimary),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => onEditBrandName(brand.name),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.edit_outlined, size: 15, color: p.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 2),
                      GestureDetector(
                        onTap: () => onEditBrandCategory(brand.name, brand.category.isEmpty ? null : brand.category),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.category_outlined, size: 15, color: p.textSecondary),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => onDeleteBrand(brand.name),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.delete_outline_rounded, size: 15, color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Result of [_AddCategorySheet]: the new category's name, plus an
/// optional brand to create under it in the same step.
class _AddCategoryResult {
  final String categoryName;
  final String? brandName;
  const _AddCategoryResult({required this.categoryName, this.brandName});
}

/// "Add Category" bottom sheet -- styled like every other sheet/form
/// in this app (rounded top corners, drag handle, `_FieldLabel` +
/// `_FieldBox` fields matching Add Product's Product Name/Price
/// fields) instead of a generic `AlertDialog`. Category Name is
/// required; Brand Name is optional, so the owner can seed the new
/// category's first brand in one step without a second trip through
/// "+ Brand" on the category card right after.
class _AddCategorySheet extends StatefulWidget {
  const _AddCategorySheet();

  @override
  State<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<_AddCategorySheet> {
  final _categoryController = TextEditingController();
  final _brandController = TextEditingController();

  // Shown as inline red text under the Category Name field instead of
  // a SnackBar -- a SnackBar raised from inside this sheet's own
  // context rendered BEHIND the sheet (it's attached to the Scaffold
  // underneath, which sits lower in the stacking order than this
  // modal), so the owner only ever saw it after closing the sheet.
  // Inline text can't have that problem -- it's drawn as part of the
  // sheet itself.
  String? _categoryError;

  @override
  void initState() {
    super.initState();
    // Repaints the submit button's label whenever the (optional) Brand
    // field changes, so it always names exactly what this tap will do
    // -- "Add Category" alone, or "Add Category & Brand" once a brand
    // name is actually typed. A static label here was the root of the
    // "name confused" feedback: it said "Add Category" even when a
    // brand was also about to be created with it.
    _brandController.addListener(_onBrandFieldChanged);
  }

  void _onBrandFieldChanged() => setState(() {});

  @override
  void dispose() {
    _brandController.removeListener(_onBrandFieldChanged);
    _categoryController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  void _submit() {
    // Title-cased before anything else sees them -- typing "smart
    // phone" (or "SMART PHONE", or any other casing) saves and shows
    // as "Smart Phone", same reasoning as the Brand field right below.
    final categoryName = toTitleCase(_categoryController.text);
    if (categoryName.isEmpty) {
      setState(() => _categoryError = 'Category name is required');
      return;
    }
    final brandName = toTitleCase(_brandController.text);
    Navigator.of(context).pop(
      _AddCategoryResult(categoryName: categoryName, brandName: brandName.isEmpty ? null : brandName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    // The button below names exactly what this tap will do -- plain
    // "Add Category" while Brand is empty, "Add Category & Brand" the
    // moment a brand name is actually typed -- instead of a fixed
    // label that always said "Add Category" even when a brand was
    // about to be created with it (the source of the "name confused"
    // feedback, together with the sheet's heading below repeating the
    // exact same words).
    final hasBrand = _brandController.text.trim().isNotEmpty;
    final submitLabel = hasBrand ? 'Add Category & Brand' : 'Add Category';

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
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
                            'New Category',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.textPrimary),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Category is required; add its first brand too if you like.',
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
                const SizedBox(height: 18),
                _FieldLabel('Category Name', palette: p, required: true),
                const SizedBox(height: 7),
                _FieldBox(
                  palette: p,
                  hasError: _categoryError != null,
                  child: TextField(
                    controller: _categoryController,
                    autofocus: true,
                    style: TextStyle(fontSize: 14, color: p.textPrimary),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: 'e.g. Smart Phone, Flowers...',
                      hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9C9CA6)),
                    ),
                    // Clears the error the moment they start fixing it,
                    // rather than leaving a stale "required" message
                    // showing under a field that's no longer empty.
                    onChanged: (_) {
                      if (_categoryError != null) setState(() => _categoryError = null);
                    },
                  ),
                ),
                if (_categoryError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _categoryError!,
                    style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 14),
                _FieldLabel('Brand', palette: p),
                const SizedBox(height: 7),
                _FieldBox(
                  palette: p,
                  child: TextField(
                    controller: _brandController,
                    style: TextStyle(fontSize: 14, color: p.textPrimary),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: 'e.g. Samsung, iPhone... (optional)',
                      hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9C9CA6)),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Leave Brand empty to just add the category -- you can add brands later from its card.',
                  style: TextStyle(fontSize: 11.5, color: p.textSecondary),
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: _submit,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      submitLabel,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Rename Category" bottom sheet -- same field styling as
/// [_AddCategorySheet]/[_AddBrandSheet], just the one required
/// Category Name field, pre-filled with the current name instead of
/// starting blank. This is the category-side equivalent of the pencil
/// icon a brand row already had; a category has nothing else to
/// reassign, so its own edit action is renaming itself.
class _RenameCategorySheet extends StatefulWidget {
  final String currentName;
  const _RenameCategorySheet({required this.currentName});

  @override
  State<_RenameCategorySheet> createState() => _RenameCategorySheetState();
}

class _RenameCategorySheetState extends State<_RenameCategorySheet> {
  late final TextEditingController _controller;

  // Same reasoning as _AddCategorySheetState._categoryError /
  // _AddBrandSheetState._brandError -- inline text instead of a
  // SnackBar, which would render behind this still-open sheet.
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    // Title-cased the same way as every other name entered from this
    // screen -- see toTitleCase's own doc comment.
    final name = toTitleCase(_controller.text);
    if (name.isEmpty) {
      setState(() => _nameError = 'Category name is required');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
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
                      child: Text('Rename Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.textPrimary)),
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
                const SizedBox(height: 18),
                _FieldLabel('Category Name', palette: p, required: true),
                const SizedBox(height: 7),
                _FieldBox(
                  palette: p,
                  hasError: _nameError != null,
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    style: TextStyle(fontSize: 14, color: p.textPrimary),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (_) {
                      if (_nameError != null) setState(() => _nameError = null);
                    },
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                if (_nameError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _nameError!,
                    style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Updates every brand and product already filed under "${widget.currentName}" to the new name too.',
                  style: TextStyle(fontSize: 11.5, color: p.textSecondary),
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: _submit,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                    child: const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Rename Brand" bottom sheet -- same field styling and shape as
/// [_RenameCategorySheet], just the one required Brand Name field,
/// pre-filled with the current name. This is the brand-name
/// equivalent of that sheet; the brand row's OTHER pencil icon
/// (reassigning category) keeps using [LookupPickerDialog] instead,
/// completely unchanged.
class _RenameBrandSheet extends StatefulWidget {
  final String currentName;
  const _RenameBrandSheet({required this.currentName});

  @override
  State<_RenameBrandSheet> createState() => _RenameBrandSheetState();
}

class _RenameBrandSheetState extends State<_RenameBrandSheet> {
  late final TextEditingController _controller;

  // Same reasoning as _RenameCategorySheetState._nameError -- inline
  // text instead of a SnackBar, which would render behind this
  // still-open sheet.
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    // Title-cased the same way as every other name entered from this
    // screen -- see toTitleCase's own doc comment.
    final name = toTitleCase(_controller.text);
    if (name.isEmpty) {
      setState(() => _nameError = 'Brand name is required');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
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
                      child: Text('Rename Brand', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.textPrimary)),
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
                const SizedBox(height: 18),
                _FieldLabel('Brand Name', palette: p, required: true),
                const SizedBox(height: 7),
                _FieldBox(
                  palette: p,
                  hasError: _nameError != null,
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    style: TextStyle(fontSize: 14, color: p.textPrimary),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (_) {
                      if (_nameError != null) setState(() => _nameError = null);
                    },
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                if (_nameError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _nameError!,
                    style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Updates every product already saved with brand "${widget.currentName}" to the new name too.',
                  style: TextStyle(fontSize: 11.5, color: p.textSecondary),
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: _submit,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                    child: const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Add Brand" bottom sheet for an existing category -- same field
/// styling as [_AddCategorySheet], just the one required Brand Name
/// field, with the target category named in the subtitle.
class _AddBrandSheet extends StatefulWidget {
  final String category;
  const _AddBrandSheet({required this.category});

  @override
  State<_AddBrandSheet> createState() => _AddBrandSheetState();
}

class _AddBrandSheetState extends State<_AddBrandSheet> {
  final _controller = TextEditingController();

  // Inline red text under the field instead of a SnackBar -- same
  // reasoning as `_AddCategorySheetState._categoryError`: a SnackBar
  // raised from this sheet's own context rendered behind the sheet
  // itself, so it was invisible until after closing it.
  String? _brandError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    // Title-cased the same way as _AddCategorySheetState._submit --
    // typing "samsung" saves and shows as "Samsung".
    final name = toTitleCase(_controller.text);
    if (name.isEmpty) {
      setState(() => _brandError = 'Brand name is required');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
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
                          Text('Add Brand', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.textPrimary)),
                          const SizedBox(height: 3),
                          Text('Under "${widget.category}"', style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
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
                const SizedBox(height: 18),
                _FieldLabel('Brand Name', palette: p, required: true),
                const SizedBox(height: 7),
                _FieldBox(
                  palette: p,
                  hasError: _brandError != null,
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    style: TextStyle(fontSize: 14, color: p.textPrimary),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: 'e.g. Samsung, iPhone...',
                      hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9C9CA6)),
                    ),
                    onChanged: (_) {
                      if (_brandError != null) setState(() => _brandError = null);
                    },
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                if (_brandError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _brandError!,
                    style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: _submit,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                    child: const Text('Add Brand', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A bold field label matching Add Product's own `_FieldLabel` --
/// red " *" suffix when [required] is true. Kept as a private copy
/// here (rather than importing Add Product's, which is itself private
/// to that file) -- matches this codebase's existing convention of
/// small per-screen style-matching widgets (see `_RadioDot` in
/// `lookup_picker_dialog.dart`, `_CategoryCard` in this same file).
class _FieldLabel extends StatelessWidget {
  final String text;
  final AppPalette palette;
  final bool required;
  const _FieldLabel(this.text, {required this.palette, this.required = false});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: palette.textPrimary),
        children: [
          TextSpan(text: text),
          if (required) const TextSpan(text: ' *', style: TextStyle(color: AppColors.danger)),
        ],
      ),
    );
  }
}

/// A bordered 48px field container matching Add Product's own
/// `_FieldBox` -- except filled with [AppPalette.background] rather
/// than [AppPalette.card], since (unlike Add Product's Scaffold) this
/// sheet's own container is already card-colored: a card-on-card box
/// would have no contrast. Same choice `_CategoryCard`'s brand rows
/// already make elsewhere in this file. The child (a `TextField`)
/// supplies its own borderless, dense `InputDecoration`.
class _FieldBox extends StatelessWidget {
  final AppPalette palette;
  final Widget child;
  final bool hasError;
  const _FieldBox({required this.palette, required this.child, this.hasError = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: hasError ? AppColors.danger : palette.border, width: hasError ? 1.4 : 1),
      ),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }
}

