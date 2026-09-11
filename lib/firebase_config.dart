import 'package:flutter/foundation.dart' show kIsWeb;

import 'firebase_options.dart';

// ============================================================
// CONFIGURACIÓN DE FIREBASE
// ============================================================

// Este archivo es a propósito el único lugar que hay que tocar a mano
// después de correr `flutterfire configure`.
//
// `firebase_options.dart` lo genera (y sobrescribe) la CLI, así que
// nada escrito por nosotros puede vivir ahí adentro.

const String _placeholder = 'REPLACE_WITH_FLUTTERFIRE_CONFIGURE';

// Client ID de tipo WEB (client_type: 3 en google-services.json).
//
// Solo lo usa la app de Android. En el navegador el login va por
// signInWithPopup() de Firebase Auth, que toma el cliente OAuth del
// proyecto por su cuenta, así que ahí este valor no hace falta.
//
// OJO: es el de tipo web, NO el de Android. Poner el de Android es la
// causa más común de que el login con Google falle en silencio.
//
// Dejarlo vacío deshabilita la sincronización en el teléfono; la app
// sigue andando en modo local.
const String googleWebClientId = '';

// Si `flutterfire configure` todavía no corrió, los valores siguen
// siendo los del placeholder. En ese caso ni siquiera intentamos
// inicializar Firebase: la app arranca en modo local y la pantalla de
// sincronización explica qué falta.
bool get isFirebaseConfigured =>
    DefaultFirebaseOptions.currentPlatform.apiKey != _placeholder &&
    DefaultFirebaseOptions.currentPlatform.projectId != _placeholder;

// En el navegador no hay client ID que completar, así que alcanza con
// que el proyecto esté configurado.
bool get isGoogleSignInConfigured => kIsWeb || googleWebClientId.isNotEmpty;
