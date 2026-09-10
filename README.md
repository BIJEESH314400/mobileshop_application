# CellPoint — Mobile Shop (Flutter, full Bloc)

Feature-first project structure. `Splash` and `Login` are fully wired
with **full Bloc** (Events → Bloc → States, not Cubit); every other
screen is a working placeholder with the bottom nav already in place,
so the app runs end-to-end today and you fill in one feature at a time.

## Why full Bloc instead of Cubit here

Cubit is Bloc with the Event step removed — simpler, less boilerplate.
This project deliberately uses the full pattern instead, because:

- **Every user action is a named `Event` class** (e.g. `LoginSubmitted`),
  so anyone can see every possible action a screen supports just by
  reading its `*_event.dart` file, without reading the UI code.
- **Better traceability**: a Bloc's unit of work is Event → old State →
  new State, which tools like `BlocObserver` and `bloc_test` hook into
  cleanly — you get an audit trail of *why* a state changed, not just
  that it did.
- **It's the "complete" mental model.** Once you know full Bloc, Cubit
  is trivial (it's just Bloc with the Event step skipped). This is also
  what most teams that standardize on `flutter_bloc` at scale actually
  use, so it's the more hireable skill to have depth in.

## Structure

```
lib/
  main.dart               entry point
  app.dart                MaterialApp + routes
  core/
    theme/                colors + ThemeData
    routes/                app_routes.dart — every named route
    widgets/               shared widgets (app_bottom_nav.dart)
    utils/                 currency_formatter.dart, etc.
  features/
    splash/
      bloc/                 splash_event.dart, splash_state.dart, splash_bloc.dart   [done]
      view/                 splash_screen.dart                                        [done]
    auth/
      bloc/                 login_event.dart, login_state.dart, login_bloc.dart      [done]
      view/                 login_screen.dart                                         [done]
    dashboard/
      bloc/                 (empty — build next)
      view/                 dashboard_screen.dart (placeholder)
    products/
      bloc/                 (empty)
      view/                 products_screen.dart, add_product_screen.dart (placeholders)
    sales/
      bloc/ view/            (placeholder)
    service/
      bloc/ view/            (placeholder)
    customers/
      bloc/ view/            (placeholder)
    reports/
      bloc/ view/            (placeholder)
    profile/
      bloc/ view/            (placeholder)
  data/
    models/                 (empty — plain Dart classes for Product, SaleItem, Job, Customer...)
    repositories/           (empty — where API/DB calls will live)
assets/
  images/
  icons/
test/
```

## ⚠️ One manual cleanup step

This project originally used Cubit, and those files are still sitting
on disk at:

```
lib/features/splash/cubit/   (old splash_cubit.dart)
lib/features/auth/cubit/     (old login_cubit.dart, login_state.dart)
```

They are **no longer used by anything** (nothing imports them anymore —
`app_routes.dart` points at the new `view/` files, which now import
from `bloc/`, not `cubit/`). Delete these two `cubit/` folders by hand
in File Explorer or Android Studio's project tree:

```
lib/features/splash/cubit/
lib/features/auth/cubit/
```

The other features' `cubit/.gitkeep` placeholder folders are empty and
harmless either way — a matching `bloc/.gitkeep` now sits next to each
one; when you build that feature, put its `*_event.dart`, `*_state.dart`
and `*_bloc.dart` in `bloc/`, and you can delete the empty `cubit/`
folder at that point too.

## How the Event → Bloc → State flow works here (Login example)

1. User taps **Sign In** → the View does
   `context.read<LoginBloc>().add(LoginSubmitted(email: ..., password: ...))`
   — no logic in the View, just "here's what happened."
2. `LoginBloc`'s `on<LoginSubmitted>` handler runs, validates the input,
   and calls `emit()` one or more times as the async login proceeds
   (`isSubmitting: true` → then `isSuccess: true` or an error).
3. `BlocConsumer<LoginBloc, LoginState>` in the View rebuilds on every
   `emit()` (the `builder`) and separately reacts to success by
   navigating away (the `listener`) — same split Cubit used, this part
   didn't change.

Splash follows the identical shape, just with no fields on its Event
(`SplashStarted`) and a plain `enum` as its State since it never needs
to carry data — only Cubit forces you to be terse about this; Bloc
lets a State be as simple or complex as the screen actually needs.

## Getting it running

This was generated without running Flutter tooling, so before opening
it in Android Studio:

```bash
cd "D:\MyProject\2026\Mobile Shop"
flutter create . --platforms=android,ios   # adds the android/ios/ platform folders
flutter pub get
flutter run
```

`flutter create .` on an existing folder only adds the missing
platform scaffolding (android/, ios/, etc.) — it will NOT overwrite
`lib/` or `pubspec.yaml`.

## Suggested build order

1. **Dashboard** — stats cards, quick actions, recent sales/service
   preview (mostly static data + navigation, good warm-up).
2. **Products** — list + category filter + FAB → Add Product.
3. **Add Product** — the form.
4. **Sales** — cart with live total (the one screen with real
   calculation logic — good Bloc practice: try modeling each cart
   action, e.g. `SaleItemAdded`, `SaleItemQuantityChanged`, as its own
   Event).
5. **Service** — job list + status filter.
6. **Customers**, **Reports**, **Profile** — round out the rest.

Say which feature you want next and I'll build that Bloc (events +
state + bloc) + screen into this same structure.
