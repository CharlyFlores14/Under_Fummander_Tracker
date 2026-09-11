import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_config.dart';
import '../firebase_options.dart';

// ============================================================
// AUTENTICACIÓN
// ============================================================

// Error con un mensaje ya listo para mostrarle a la persona. Todo lo
// que sale de acá se puede tirar directo en un SnackBar.
class SyncException implements Exception {
  final String message;

  SyncException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  bool _initialized = false;

  bool get isInitialized => _initialized;

  // Firebase se toca recién acá, nunca al construir la interfaz. Eso
  // es lo que permite que la app arranque (y que corran los tests) sin
  // ningún proyecto configurado.
  Future<void> ensureInitialized() async {
    if (_initialized) return;

    if (!isFirebaseConfigured) {
      throw SyncException(
        'Firebase todavía no está configurado.\n\n'
        'Seguí los pasos de SETUP.md: correr "flutterfire configure" '
        'y completar googleWebClientId en lib/firebase_config.dart.',
      );
    }

    if (!isGoogleSignInConfigured) {
      throw SyncException(
        'Falta completar googleWebClientId en lib/firebase_config.dart.\n\n'
        'Tiene que ser el client ID de tipo WEB (client_type: 3 en '
        'google-services.json), no el de Android.',
      );
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // La caché offline ya viene activada por defecto en Android/iOS,
      // pero la dejamos explícita: es lo que permite registrar partidas
      // sin señal en el local y que se sincronicen solas después.
      if (!kIsWeb) {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      }

      await GoogleSignIn.instance.initialize(
        serverClientId: googleWebClientId,
      );

      _initialized = true;
    } on FirebaseException catch (error) {
      throw SyncException(
        'No se pudo inicializar Firebase: ${error.message ?? error.code}',
      );
    }
  }

  User? get currentUser => _initialized ? FirebaseAuth.instance.currentUser : null;

  Stream<User?> authStateChanges() {
    if (!_initialized) return const Stream<User?>.empty();

    return FirebaseAuth.instance.authStateChanges();
  }

  Future<User> signInWithGoogle() async {
    await ensureInitialized();

    final signIn = GoogleSignIn.instance;

    if (!signIn.supportsAuthenticate()) {
      throw SyncException(
        'El inicio de sesión con Google no está disponible en esta '
        'plataforma.',
      );
    }

    final GoogleSignInAccount account;

    try {
      account = await signIn.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw SyncException('Inicio de sesión cancelado.');
      }

      // El motivo casi siempre es que falta registrar la huella SHA-1
      // del proyecto en la consola de Firebase.
      throw SyncException(
        'No se pudo iniciar sesión con Google (${error.code.name}).\n\n'
        'Revisá que la huella SHA-1 esté registrada en Firebase y que '
        'googleWebClientId sea el client ID de tipo web. Ver SETUP.md.',
      );
    }

    final idToken = account.authentication.idToken;

    if (idToken == null) {
      throw SyncException(
        'Google no devolvió un token de identidad. Suele pasar cuando '
        'googleWebClientId no es el client ID de tipo web.',
      );
    }

    try {
      final result = await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );

      final user = result.user;

      if (user == null) {
        throw SyncException('Firebase no devolvió ningún usuario.');
      }

      return user;
    } on FirebaseAuthException catch (error) {
      throw SyncException(
        'Firebase rechazó el inicio de sesión: ${error.message ?? error.code}',
      );
    }
  }

  Future<void> signOut() async {
    if (!_initialized) return;

    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
  }
}
