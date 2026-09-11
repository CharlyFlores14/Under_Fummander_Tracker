// GENERADO POR flutterfire_cli — ESTE ES UN PLACEHOLDER.
//
// Todavía no hay un proyecto de Firebase conectado. El archivo existe
// para que la app compile y funcione en modo local sin ninguna
// configuración previa (ver SETUP.md).
//
// Al correr `flutterfire configure` este archivo se sobrescribe con
// los valores reales del proyecto. Eso es lo esperado: no hace falta
// conservar nada de acá.
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Opciones por defecto para usar con las APIs de Firebase.
///
/// ```dart
/// import 'firebase_options.dart';
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE',
    appId: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE',
    messagingSenderId: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE',
    projectId: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE',
    storageBucket: 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE',
  );

  static const FirebaseOptions ios = android;

  static const FirebaseOptions macos = android;

  static const FirebaseOptions web = android;
}
