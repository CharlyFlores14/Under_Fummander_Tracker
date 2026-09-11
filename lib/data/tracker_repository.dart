import '../models.dart';

// ============================================================
// CONTRATO DE PERSISTENCIA
// ============================================================

// Todo lo que la app necesita cargar de una. Las pantallas siguen
// trabajando con estas cuatro listas en memoria, igual que antes.
class TrackerData {
  final List<Player> players;
  final List<Deck> decks;
  final List<MatchRecord> matches;
  final List<Season> seasons;

  const TrackerData({
    required this.players,
    required this.decks,
    required this.matches,
    required this.seasons,
  });

  const TrackerData.empty()
    : players = const [],
      decks = const [],
      matches = const [],
      seasons = const [];

  bool get isEmpty =>
      players.isEmpty && decks.isEmpty && matches.isEmpty && seasons.isEmpty;
}

// Dos implementaciones: LocalRepository (SharedPreferences, modo por
// defecto, sin configuración) y FirestoreRepository (grupo compartido
// en la nube).
//
// Las operaciones son por entidad y no "guardar todo". Eso es lo que
// permite que dos personas registren partidas distintas la misma noche
// sin pisarse: cada partida es un documento separado.
abstract class TrackerRepository {
  // Modo nube: emite de nuevo cada vez que alguien del grupo cambia
  // algo. Modo local: emite una sola vez, al cargar.
  Stream<TrackerData> watch();

  Future<void> upsertPlayer(Player player);

  // Arrastra los mazos del jugador, igual que hacía _deletePlayer.
  Future<void> deletePlayer(String playerId);

  Future<void> upsertDeck(Deck deck);

  Future<void> upsertMatch(MatchRecord match);

  Future<void> deleteMatch(String matchId);

  Future<void> upsertSeason(Season season);

  // Se usa una sola vez, al crear un grupo con datos locales previos.
  Future<void> replaceAll(TrackerData data);

  Future<void> dispose();
}
