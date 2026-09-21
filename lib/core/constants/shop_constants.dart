/// Every product/sale/etc. document is scoped to a shop via this id —
/// this is the hook the "each branch keeps its own independent stock"
/// decision (from planning) attaches to in the actual data.
///
/// TODO: once the real login API and BranchSelectDialog are wired up
/// (see login_bloc.dart's TODOs), replace this constant with the
/// signed-in account's actual active branch id — set at login, and
/// changeable later from Profile — instead of this single hardcoded
/// value. Until then, every product/sale belongs to this one default
/// shop, which is fine for a single-branch setup.
const String currentShopId = 'main';
