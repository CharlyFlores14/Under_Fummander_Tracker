import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import 'tracker_repository.dart';

// ============================================================
// MODO LOCAL (SharedPreferences)
// ============================================================

// Es el modo por defecto: la app funciona sin cuenta, sin internet y
// sin ninguna configuración de Firebase, exactamente igual que antes.
//
// Las claves son las mismas de siempre, así que una instalación vieja
// abre con todos sus datos intactos.
class LocalRepository implements TrackerRepository {
  static const playersKey = 'uft_players';
  static const decksKey = 'uft_decks';
  static const matchesKey = 'uft_matches';
  static const seasonsKey = 'uft_seasons';

  List<Player> _players = [];
  List<Deck> _decks = [];
  List<MatchRecord> _matches = [];
  List<Season> _seasons = [];

  bool _loaded = false;

  @override
  Stream<TrackerData> watch() async* {
    yield await load();
  }

  Future<TrackerData> load() async {
    final prefs = await SharedPreferences.getInstance();

    _players = _decode(prefs.getString(playersKey), Player.fromJson);
    _decks = _decode(prefs.getString(decksKey), Deck.fromJson);
    _matches = _decode(prefs.getString(matchesKey), MatchRecord.fromJson);
    _seasons = _decode(prefs.getString(seasonsKey), Season.fromJson);

    _loaded = true;

    return _snapshot();
  }

  static List<T> _decode<T>(
    String? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (raw == null) return <T>[];

    return (jsonDecode(raw) as List)
        .map((e) => fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  TrackerData _snapshot() {
    return TrackerData(
      players: _players,
      decks: _decks,
      matches: _matches,
      seasons: _seasons,
    );
  }

  // Hay que cargar ANTES de tocar las listas: si cargáramos dentro de
  // _persist(), la lectura del disco pisaría el cambio que venimos a
  // guardar.
  Future<void> _ensureLoaded() async {
    if (!_loaded) await load();
  }

  // Guardar en disco local es barato, así que seguimos escribiendo los
  // cuatro blobs enteros como hacía Storage.save().
  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      playersKey,
      jsonEncode(_players.map((p) => p.toJson()).toList()),
    );

    await prefs.setString(
      decksKey,
      jsonEncode(_decks.map((d) => d.toJson()).toList()),
    );

    await prefs.setString(
      matchesKey,
      jsonEncode(_matches.map((m) => m.toJson()).toList()),
    );

    await prefs.setString(
      seasonsKey,
      jsonEncode(_seasons.map((s) => s.toJson()).toList()),
    );
  }

  static void _upsert<T>(List<T> list, T item, bool Function(T) matches) {
    final index = list.indexWhere(matches);

    if (index == -1) {
      list.add(item);
    } else {
      list[index] = item;
    }
  }

  @override
  Future<void> upsertPlayer(Player player) async {
    await _ensureLoaded();
    _upsert(_players, player, (p) => p.id == player.id);
    await _persist();
  }

  @override
  Future<void> deletePlayer(String playerId) async {
    await _ensureLoaded();
    _players.removeWhere((p) => p.id == playerId);
    _decks.removeWhere((d) => d.playerId == playerId);
    await _persist();
  }

  @override
  Future<void> upsertDeck(Deck deck) async {
    await _ensureLoaded();
    _upsert(_decks, deck, (d) => d.id == deck.id);
    await _persist();
  }

  @override
  Future<void> upsertMatch(MatchRecord match) async {
    await _ensureLoaded();
    _upsert(_matches, match, (m) => m.id == match.id);
    await _persist();
  }

  @override
  Future<void> deleteMatch(String matchId) async {
    await _ensureLoaded();
    _matches.removeWhere((m) => m.id == matchId);
    await _persist();
  }

  @override
  Future<void> upsertSeason(Season season) async {
    await _ensureLoaded();
    _upsert(_seasons, season, (s) => s.id == season.id);
    await _persist();
  }

  @override
  Future<void> replaceAll(TrackerData data) async {
    _players = [...data.players];
    _decks = [...data.decks];
    _matches = [...data.matches];
    _seasons = [...data.seasons];
    _loaded = true;
    await _persist();
  }

  @override
  Future<void> dispose() async {}
}
