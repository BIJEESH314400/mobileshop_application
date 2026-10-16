import 'package:cloud_firestore/cloud_firestore.dart';

/// Backs the small growable lists used by pickers — today `categories`
/// and `brands`. Each is just a Firestore collection of documents
/// shaped like `{ name: "Smartphones" }`; this class doesn't care which
/// collection it's pointed at, so the same code serves both lists
/// instead of writing near-duplicate Category/Brand repositories.
///
/// `brands` documents can optionally carry a `category` field so the
/// Brand picker can be filtered to the product's selected category
/// (e.g. only perfume brands when Category is "Perfume"). `categories`
/// documents never get this field -- [category] is only ever passed
/// when reading/writing the `brands` collection.
class LookupRepository {
  final FirebaseFirestore _db;

  LookupRepository({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;

  /// A live, alphabetically-sorted list of names in [collection] — used
  /// to fill a picker and to instantly show a name someone just added,
  /// without needing to close and reopen the picker.
  ///
  /// When [category] is given, only names tagged with that exact
  /// category are kept -- plus any name with no category tag at all,
  /// since every brand added before this filtering existed has no
  /// `category` field yet and would otherwise vanish from every
  /// picker until someone manually re-tagged it. The filter is applied
  /// client-side (these lists are small, growable, hand-curated ones,
  /// not worth a composite index over) rather than as a Firestore
  /// `where`, since "category == x OR category is missing" isn't a
  /// single equality filter Firestore can express directly.
  Stream<List<String>> watchNames(String collection, {String? category}) {
    return _db.collection(collection).orderBy('name').snapshots().map(
          (snapshot) => snapshot.docs
              .where((doc) {
                if (category == null) return true;
                final docCategory = doc.data()['category'] as String? ?? '';
                return docCategory.isEmpty || docCategory == category;
              })
              .map((doc) => doc.data()['name'] as String? ?? '')
              .where((name) => name.isNotEmpty)
              .toList(),
        );
  }

  /// Adds a new name to [collection], unless one already exists with
  /// the same text (checked case-insensitively client-side, since
  /// Firestore queries are always case-sensitive) — avoids ending up
  /// with both "Apple" and "apple" as separate brands from a typo.
  ///
  /// [category], when given, is stored alongside the new name so it
  /// shows up under [watchNames]'s filter for that category from then
  /// on. Left out entirely (not even as an empty string) when
  /// [category] is null, so `categories` documents keep their existing
  /// shape instead of gaining an always-blank field.
  Future<void> addName(String collection, String name, {String? category}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final existing = await _db.collection(collection).get();
    final alreadyThere = existing.docs.any(
      (doc) => (doc.data()['name'] as String? ?? '').toLowerCase() == trimmed.toLowerCase(),
    );
    if (alreadyThere) return;

    await _db.collection(collection).add({
      'name': trimmed,
      if (category != null) 'category': category,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Live list of every entry in [collection] as (name, category)
  /// pairs, sorted alphabetically by name -- what a management screen
  /// needs to show and edit, unlike [watchNames]'s plain name list
  /// (built for pickers, which only ever need the text).
  Stream<List<LookupEntry>> watchEntries(String collection) {
    return _db.collection(collection).orderBy('name').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => LookupEntry(
                    name: doc.data()['name'] as String? ?? '',
                    category: doc.data()['category'] as String? ?? '',
                  ))
              .where((entry) => entry.name.isNotEmpty)
              .toList(),
        );
  }

  /// Tags an existing [name] in [collection] with [category], but only
  /// if it doesn't already carry a category. Called when someone picks
  /// a name from a category-filtered picker list: since that list only
  /// ever shows names that are untagged or already match the selected
  /// category (see [watchNames]), a pick can never conflict with an
  /// existing tag -- so this either fills in a blank or does nothing,
  /// never silently overwrites a brand someone already categorized.
  /// This is how an old brand (added before category-filtering
  /// existed) quietly "learns" its category the first time it's
  /// actually used under one, with no extra screen or step needed.
  Future<void> tagExistingIfUntagged(String collection, String name, String category) async {
    final snapshot = await _db.collection(collection).where('name', isEqualTo: name).limit(1).get();
    if (snapshot.docs.isEmpty) return;
    final doc = snapshot.docs.first;
    final existingCategory = doc.data()['category'] as String? ?? '';
    if (existingCategory.isNotEmpty) return;
    await doc.reference.update({'category': category});
  }

  /// Sets [name]'s category in [collection] directly, overwriting
  /// whatever was there before (or filling it in for the first time).
  /// Unlike [tagExistingIfUntagged]'s softer "only if nobody's told it
  /// yet" behaviour, this is for a deliberate, explicit choice -- the
  /// Manage Brands screen, where picking a new category for a brand
  /// should actually change it, even one that was already tagged.
  Future<void> setCategory(String collection, String name, String category) async {
    final snapshot = await _db.collection(collection).where('name', isEqualTo: name).limit(1).get();
    if (snapshot.docs.isEmpty) return;
    await snapshot.docs.first.reference.update({'category': category});
  }

  /// Deletes a category outright, and un-tags (not deletes) every
  /// brand currently filed under it -- those brands go back to being
  /// untagged, the same state a pre-existing legacy brand is in, so
  /// they simply show up again under every category's picker until
  /// someone re-tags them. Deleting the category should never make a
  /// brand's own stock/products disappear or orphan silently, so the
  /// brand itself is left alone; only its `category` link is cleared.
  Future<void> deleteCategory(String name) async {
    final categorySnapshot = await _db.collection('categories').where('name', isEqualTo: name).limit(1).get();
    for (final doc in categorySnapshot.docs) {
      await doc.reference.delete();
    }

    final taggedBrands = await _db.collection('brands').where('category', isEqualTo: name).get();
    for (final doc in taggedBrands.docs) {
      await doc.reference.update({'category': ''});
    }
  }

  /// Deletes a single brand outright from [collection] (used for the
  /// `brands` collection). Unlike [deleteCategory], there's nothing to
  /// un-tag first -- a brand doesn't have anything filed under it.
  Future<void> deleteBrand(String collection, String name) async {
    final snapshot = await _db.collection(collection).where('name', isEqualTo: name).limit(1).get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  /// Renames a category everywhere its old name is stored as plain
  /// text, not just the `categories` doc itself -- unlike `brands`,
  /// which only ever gets re-tagged from one existing category to
  /// another (see [setCategory]), a category never had its own
  /// "change this" action at all until this method, so renaming it
  /// has to cascade by hand to everything that was matching it by
  /// name:
  /// - the `categories` document's own `name` field;
  /// - every `brands` document currently tagged `category: oldName`
  ///   (left as-is, they'd otherwise silently stop matching ANY
  ///   category's filtered picker -- not even falling back to
  ///   "uncategorized," since their tag isn't blank, just stale);
  /// - every `products` document already saved with `category:
  ///   oldName` (reached directly here, same pragmatic "read the
  ///   collection straight from its name" shortcut `ProductRepository`
  ///   already takes with `product_units`, rather than taking a
  ///   dependency on `ProductRepository` just for this one bulk
  ///   update) -- otherwise existing products would keep showing the
  ///   old category name forever while new ones show the new name.
  ///
  /// Returns `false` without changing anything if [newName] is blank,
  /// unchanged, or already used by a *different* category
  /// (case-insensitively, same duplicate check as [addName]) -- the
  /// caller shows that as an error rather than silently merging two
  /// categories into one.
  Future<bool> renameCategory(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == oldName) return false;

    final existingCategories = await _db.collection('categories').get();
    final clashesWithAnother = existingCategories.docs.any(
      (doc) =>
          (doc.data()['name'] as String? ?? '').toLowerCase() == trimmed.toLowerCase() &&
          (doc.data()['name'] as String? ?? '') != oldName,
    );
    if (clashesWithAnother) return false;

    final categorySnapshot = await _db.collection('categories').where('name', isEqualTo: oldName).limit(1).get();
    for (final doc in categorySnapshot.docs) {
      await doc.reference.update({'name': trimmed});
    }

    final taggedBrands = await _db.collection('brands').where('category', isEqualTo: oldName).get();
    for (final doc in taggedBrands.docs) {
      await doc.reference.update({'category': trimmed});
    }

    final taggedProducts = await _db.collection('products').where('category', isEqualTo: oldName).get();
    for (final doc in taggedProducts.docs) {
      await doc.reference.update({'category': trimmed});
    }

    return true;
  }

  /// Renames a brand everywhere its old name is stored as plain text --
  /// the `brands` document's own `name` field, and every `products`
  /// document already saved with `brand: oldName` (same direct-
  /// collection shortcut [renameCategory] already takes for
  /// `products.category`) -- so an existing product doesn't keep
  /// showing the old brand name forever while new ones show the new
  /// one. Unlike a category, a brand has nothing filed *under* it, so
  /// there's no further cascade the way renaming a category also has
  /// to walk every brand tagged with it.
  ///
  /// Returns `false` without changing anything if [newName] is blank,
  /// unchanged, or already used by a *different* brand
  /// (case-insensitively) -- same duplicate-guard shape as
  /// [renameCategory].
  Future<bool> renameBrand(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == oldName) return false;

    final existingBrands = await _db.collection('brands').get();
    final clashesWithAnother = existingBrands.docs.any(
      (doc) =>
          (doc.data()['name'] as String? ?? '').toLowerCase() == trimmed.toLowerCase() &&
          (doc.data()['name'] as String? ?? '') != oldName,
    );
    if (clashesWithAnother) return false;

    final brandSnapshot = await _db.collection('brands').where('name', isEqualTo: oldName).limit(1).get();
    for (final doc in brandSnapshot.docs) {
      await doc.reference.update({'name': trimmed});
    }

    final taggedProducts = await _db.collection('products').where('brand', isEqualTo: oldName).get();
    for (final doc in taggedProducts.docs) {
      await doc.reference.update({'brand': trimmed});
    }

    return true;
  }
}

/// One row of a lookup list with its category alongside its name --
/// what [LookupRepository.watchEntries] returns for a management
/// screen to display and edit. `category` is `''` for an entry that
/// hasn't been tagged yet (e.g. a brand added before category
/// filtering existed, or a `categories` entry, which never has one).
class LookupEntry {
  final String name;
  final String category;

  const LookupEntry({required this.name, required this.category});
}
