import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';

void main() async {
  // Firebase needs the Flutter binding ready before it can talk to
  // platform channels, and initializeApp() must finish before any
  // screen tries to use Auth/Firestore — so both happen here, before
  // runApp(), rather than inside a widget.
  //dev
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MobileShopApp());
}
