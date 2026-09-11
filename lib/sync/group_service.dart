import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'join_code.dart';

// ============================================================
// GRUPOS DE JUEGO
// ============================================================

// El código de invitación ES el id del documento del grupo. Así no
// hace falta una colección aparte para traducir código -> grupo, y
// unirse es una sola escritura atómica: te agregás vos mismo a
// memberUids de groups/{CODIGO}. Si el código no existe, la escritura
// rebota y mostramos "código inválido".

class PlayGroup {
  final String id; // el código de invitación
  final String name;
  final String ownerUid;
  final List<String> memberUids;

  PlayGroup({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.memberUids,
  });

  factory PlayGroup.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};

    return PlayGroup(
      id: doc.id,
      name: (data['name'] as String?) ?? 'Grupo',
      ownerUid: (data['ownerUid'] as String?) ?? '',
      memberUids: List<String>.from(
        (data['memberUids'] as List?) ?? const <String>[],
      ),
    );
  }
}

class GroupMember {
  final String uid;
  final String displayName;

  GroupMember({required this.uid, required this.displayName});
}

class GroupService {
  GroupService._();

  static final GroupService instance = GroupService._();

  static const String activeGroupKey = 'uft_active_group_id';

  // Alfabeto, largo y generación viven en join_code.dart.

  // Firestore acepta escrituras sin señal y las encola: el Future no
  // termina hasta que el servidor confirma. Para las partidas eso es
  // justo lo que queremos, pero crear o entrar a un grupo necesita la
  // respuesta del servidor, así que cortamos en vez de dejar la
  // pantalla girando para siempre.
  static const Duration _serverTimeout = Duration(seconds: 20);

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');

  // ---------- grupo activo (local) ----------

  Future<String?> loadActiveGroupId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(activeGroupKey);
  }

  Future<void> saveActiveGroupId(String? groupId) async {
    final prefs = await SharedPreferences.getInstance();

    if (groupId == null) {
      await prefs.remove(activeGroupKey);
    } else {
      await prefs.setString(activeGroupKey, groupId);
    }
  }

  // ---------- crear / unirse / salir ----------

  Future<PlayGroup> createGroup(String name) async {
    final user = AuthService.instance.currentUser;

    if (user == null) {
      throw SyncException('Iniciá sesión antes de crear un grupo.');
    }

    // Si el código sorteado ya existe, la regla de seguridad convierte
    // la escritura en un update y la rechaza. Volvemos a sortear.
    for (int attempt = 0; attempt < 8; attempt++) {
      final code = generateJoinCode();

      try {
        await _groups.doc(code).set({
          'name': name,
          'ownerUid': user.uid,
          'memberUids': [user.uid],
          'createdAt': FieldValue.serverTimestamp(),
        }).timeout(_serverTimeout);

        await _writeMemberProfile(code, user.uid, user.displayName, user.email);

        return PlayGroup(
          id: code,
          name: name,
          ownerUid: user.uid,
          memberUids: [user.uid],
        );
      } on TimeoutException {
        throw SyncException(
          'No se pudo crear el grupo: no hay conexión con el servidor.\n\n'
          'Probá de nuevo cuando tengas internet.',
        );
      } on FirebaseException catch (error) {
        if (error.code == 'permission-denied' ||
            error.code == 'already-exists') {
          continue; // código ocupado, probamos con otro
        }

        throw SyncException(_describe(error, 'No se pudo crear el grupo'));
      }
    }

    throw SyncException(
      'No se pudo generar un código libre. Probá de nuevo en un momento.',
    );
  }

  Future<PlayGroup> joinGroup(String rawCode) async {
    final user = AuthService.instance.currentUser;

    if (user == null) {
      throw SyncException('Iniciá sesión antes de unirte a un grupo.');
    }

    final code = normalizeJoinCode(rawCode);

    if (code.isEmpty) {
      throw SyncException('Escribí el código del grupo.');
    }

    // Cortamos acá antes de gastar una ida al servidor, y de paso el
    // mensaje explica por qué un código con O, 0, I o 1 nunca va a
    // andar: esas letras no se usan justamente para no confundirlas.
    if (!isValidJoinCode(code)) {
      throw SyncException(
        'El código "$code" no tiene el formato correcto.\n\n'
        'Son $joinCodeLength caracteres y no se usan las letras O e I '
        'ni los números 0 y 1.',
      );
    }

    try {
      await _groups.doc(code).update({
        'memberUids': FieldValue.arrayUnion([user.uid]),
      }).timeout(_serverTimeout);

      await _writeMemberProfile(code, user.uid, user.displayName, user.email);

      final doc = await _groups.doc(code).get();

      if (!doc.exists) {
        throw SyncException('No existe ningún grupo con el código "$code".');
      }

      return PlayGroup.fromDoc(doc);
    } on TimeoutException {
      throw SyncException(
        'No se pudo entrar al grupo: no hay conexión con el servidor.\n\n'
        'Probá de nuevo cuando tengas internet.',
      );
    } on FirebaseException catch (error) {
      // Un código inexistente y uno sin permiso llegan igual desde el
      // servidor, y desde afuera son lo mismo: el código no sirve.
      if (error.code == 'not-found' || error.code == 'permission-denied') {
        throw SyncException(
          'No existe ningún grupo con el código "$code".\n\n'
          'Revisá que esté bien escrito.',
        );
      }

      throw SyncException(_describe(error, 'No se pudo entrar al grupo'));
    }
  }

  Future<void> leaveGroup(String groupId) async {
    final user = AuthService.instance.currentUser;

    if (user == null) return;

    try {
      // El orden importa: borrar el perfil primero. Apenas salimos de
      // memberUids perdemos permiso sobre las subcolecciones del grupo,
      // así que al revés el borrado quedaría rechazado.
      await _groups
          .doc(groupId)
          .collection('members')
          .doc(user.uid)
          .delete()
          .timeout(_serverTimeout);

      await _groups.doc(groupId).update({
        'memberUids': FieldValue.arrayRemove([user.uid]),
      }).timeout(_serverTimeout);
    } on TimeoutException {
      // Sin señal las dos escrituras quedan encoladas y llegan solas.
      // Igual dejamos salir del grupo en este teléfono: retenerlo acá
      // no cambiaría nada en el servidor.
    } on FirebaseException catch (error) {
      throw SyncException(_describe(error, 'No se pudo salir del grupo'));
    }
  }

  Future<void> _writeMemberProfile(
    String groupId,
    String uid,
    String? displayName,
    String? email,
  ) async {
    try {
      await _groups.doc(groupId).collection('members').doc(uid).set({
        'uid': uid,
        'displayName': displayName ?? email ?? 'Jugador',
        'joinedAt': FieldValue.serverTimestamp(),
      }).timeout(_serverTimeout);
    } on TimeoutException {
      // El perfil solo alimenta la lista de miembros de la pantalla de
      // sincronización. Si tarda, la escritura queda encolada; no vale
      // la pena hacer fallar un alta de grupo que ya se completó.
    }
  }

  // ---------- lecturas ----------

  Future<PlayGroup?> fetchGroup(String groupId) async {
    try {
      final doc = await _groups.doc(groupId).get();

      if (!doc.exists) return null;

      return PlayGroup.fromDoc(doc);
    } on FirebaseException {
      return null;
    }
  }

  Stream<List<GroupMember>> watchMembers(String groupId) {
    return _groups.doc(groupId).collection('members').snapshots().map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data();

        return GroupMember(
          uid: doc.id,
          displayName: (data['displayName'] as String?) ?? 'Jugador',
        );
      }).toList();
    });
  }

  String _describe(FirebaseException error, String prefix) {
    if (error.code == 'permission-denied') {
      return '$prefix: el servidor rechazó la operación.\n\n'
          'Suele ser que las reglas de firestore.rules todavía no '
          'están publicadas. Ver SETUP.md.';
    }

    if (error.code == 'unavailable') {
      return '$prefix: no hay conexión con el servidor.';
    }

    return '$prefix: ${error.message ?? error.code}';
  }
}
