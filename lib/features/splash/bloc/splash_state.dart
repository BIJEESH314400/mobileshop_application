/// Splash only ever needs to be in one of three states, so a plain enum
/// is enough here — no fields to carry, so no need for a class +
/// Equatable like LoginState has.
enum AuthStatus { checking, authenticated, unauthenticated }
