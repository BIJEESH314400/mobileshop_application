/// Splash only ever needs to be in one of these states, so a plain enum
/// is enough here -- no fields to carry, so no need for a class +
/// Equatable like LoginState has.
///
/// `authenticatedNeedsPin` (added 2026-09-24) sits between the other
/// two "resolved" states: Firebase Auth says someone's still signed
/// in, but that account also has a Quick PIN set (see PinRepository),
/// so SplashScreen routes to PinUnlockScreen instead of straight to
/// Dashboard -- see the project status doc's "Quick PIN" section.
///
/// `authenticatedNeedsSetPin` (added 2026-09-25, once Quick PIN became
/// a REQUIRED step of login rather than optional): Firebase Auth says
/// someone's still signed in, but this account has NO PIN saved. In
/// the normal flow that only happens mid-setup -- e.g. the app was
/// killed after LoginScreen's username+password step succeeded but
/// before SetPinScreen finished saving one -- so a cold start in that
/// state must still finish the required setup rather than let them
/// straight into Dashboard with no PIN ever saved. (`authenticated`,
/// the plain "let them straight in" case, is effectively unreachable
/// now that PIN setup is required, but is kept rather than removed --
/// no harm in the fallback existing.)
enum AuthStatus { checking, authenticated, authenticatedNeedsPin, authenticatedNeedsSetPin, unauthenticated }
