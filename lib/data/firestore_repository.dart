import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models.dart';
import 'tracker_repository.dart';

// ============================================================
// MODO NUBE (Cloud Firestore)
// ============================================================

// Cada entidad es un documento propio dentro del grupo:
//
//   groups/{groupId}/players/{playerId}
//   groups/{groupId}/decks/{deckId}
//   groups/{groupId}/matches/{matchId}
//   groups/{groupId}/seasons/{seasonId}
//
// Guardar documento por documento (en vez de un JSON gigante) es lo
// que hace que dos personas puedan registrar partidas distintas la
// misma noche sin pisarse los cambios.
//
// Firestore trae caché offline activada por defecto en Android/iOS:
// las escrituras hechas sin señal quedan encoladas y se sincronizan
// solas al volver la conexión.
class FirestoreRepository implements TrackerRepository {
  final FirebaseFirestore _db;
  final String groupId;

  FirestoreRepository({required this.groupId, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final StreamController<TrackerData> _controller =
      StreamController<TrackerData>.broadcast();

  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _subs = [];

  List<Player> _players = [];
  List<Deck> _decks = [];
  List<MatchRecord> _matches = [];
  List<Season> _seasons = [];

  // Las cuatro colecciones llegan por separado. Esperamos a tener la
  // primera foto de todas antes de emitir, si no la pantalla parpadea
  // con listas a medio llenar.
  final Set<String> _ready = {};
  bool get _hasData => _ready.length == 4;

  DocumentReference<Map<String, dynamic>> get _groupDoc =>
      _db.collection('groups').doc(groupId);

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _groupDoc.collection(name);

  @override
  Stream<TrackerData> watch() async* {
    if (_subs.isEmpty) _start();

    if (_hasData) yield _snapshot();

    yield* _controller.stream;
  }

  void _start() {
    _listen<Player>('players', Player.fromJson, (list) => _players = list);
    _listen<Deck>('decks', Deck.fromJson, (list) => _decks = list);
    _listen<MatchRecord>(
      'matches',
      MatchRecord.fromJson,
      (list) => _matches = list,
    );
    _listen<Season>('seasons', Season.fromJson, (list) => _seasons = list);
  }

  void _listen<T>(
    String name,
    T Function(Map<String, dynamic>) fromJson,
    void Function(List<T>) assign,
  ) {
    final sub = _col(name).snapshots().listen(
      (snapshot) {
        assign(snapshot.docs.map((doc) => fromJson(doc.data())).toList());

        _ready.add(name);

        if (_hasData) _controller.add(_snapshot());
      },
      onError: (Object error, StackTrace stackTrace) {
        _controller.addError(error, stackTrace);
      },
    );

    _subs.add(sub);
  }

  TrackerData _snapshot() {
    return TrackerData(
      players: _players,
      decks: _decks,
      matches: _matches,
      seasons: _seasons,
    );
  }

  @override
  Future<void> upsertPlayer(Player player) {
    return _col('players').doc(player.id).set(player.toJson());
  }

  @override
  Future<void> deletePlayer(String playerId) async {
    // Misma cascada que hacía _deletePlayer en local: se van también
    // los mazos de ese jugador.
    final decks = await _col(
      'decks',
    ).where('playerId', isEqualTo: playerId).get();

    final batch = _db.batch();

    batch.delete(_col('players').doc(playerId));

    for (final doc in decks.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  @override
  Future<void> upsertDeck(Deck deck) {
    return _col('decks').doc(deck.id).set(deck.toJson());
  }

  @override
  Future<void> upsertMatch(MatchRecord match) {
    return _col('matches').doc(match.id).set(match.toJson());
  }

  @override
  Future<void> deleteMatch(String matchId) {
    return _col('matches').doc(matchId).delete();
  }

  @override
  Future<void> upsertSeason(Season season) {
    return _col('seasons').doc(season.id).set(season.toJson());
  }

  @override
  Future<void> replaceAll(TrackerData data) async {
    final writes = <MapEntry<DocumentReference<Map<String, dynamic>>,
        Map<String, dynamic>>>[
      for (final p in data.players)
        MapEntry(_col('players').doc(p.id), p.toJson()),
      for (final d in data.decks) MapEntry(_col('decks').doc(d.id), d.toJson()),
      for (final m in data.matches)
        MapEntry(_col('matches').doc(m.id), m.toJson()),
      for (final s in data.seasons)
        MapEntry(_col('seasons').doc(s.id), s.toJson()),
    ];

    // Un batch de Firestore admite hasta 500 operaciones.
    const chunkSize = 450;

    for (int i = 0; i < writes.length; i += chunkSize) {
      final batch = _db.batch();

      final end = (i + chunkSize).clamp(0, writes.length);

      for (final write in writes.sublist(i, end)) {
        batch.set(write.key, write.value);
      }

      await batch.commit();
    }
  }

  @override
  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }

    _subs.clear();
    _ready.clear();

    await _controller.close();
  }
}
