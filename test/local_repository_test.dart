import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:under_fummander_tracker/data/local_repository.dart';
import 'package:under_fummander_tracker/data/tracker_repository.dart';
import 'package:under_fummander_tracker/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Player player(String id, String name) => Player(id: id, name: name);

  Deck deck(String id, String playerId) =>
      Deck(id: id, name: 'Mazo $id', commander: 'Comandante', playerId: playerId);

  MatchRecord match(String id, String winner) => MatchRecord(
    id: id,
    date: DateTime(2026, 2, 1),
    participants: {'p1': 'd1', 'p2': 'd2'},
    winnerPlayerId: winner,
  );

  group('Compatibilidad con instalaciones viejas', () {
    // Lo único que no se puede romper: alguien que ya venía usando la
    // app tiene que abrir la versión nueva y encontrar todo igual.
    test('lee los datos guardados con las claves uft_*', () async {
      SharedPreferences.setMockInitialValues({
        'uft_players': jsonEncode([player('p1', 'Gerico').toJson()]),
        'uft_decks': jsonEncode([deck('d1', 'p1').toJson()]),
        'uft_matches': jsonEncode([match('m1', 'p1').toJson()]),
        'uft_seasons': jsonEncode([
          Season(
            id: 's1',
            name: 'Temporada 1',
            startDate: DateTime(2026, 1, 1),
          ).toJson(),
        ]),
      });

      final data = await LocalRepository().load();

      expect(data.players.single.name, 'Gerico');
      expect(data.decks.single.playerId, 'p1');
      expect(data.matches.single.id, 'm1');
      expect(data.seasons.single.name, 'Temporada 1');
    });

    // La versión anterior devolvía las cuatro listas vacías si faltaba
    // uft_players, aunque hubiera partidas guardadas.
    test('carga cada clave por separado si alguna falta', () async {
      SharedPreferences.setMockInitialValues({
        'uft_matches': jsonEncode([match('m1', 'p1').toJson()]),
      });

      final data = await LocalRepository().load();

      expect(data.players, isEmpty);
      expect(data.matches, hasLength(1));
    });

    test('una instalación nueva arranca vacía', () async {
      final data = await LocalRepository().load();

      expect(data.isEmpty, isTrue);
    });
  });

  group('Escrituras', () {
    test('upsert agrega y después reemplaza el mismo id', () async {
      final repo = LocalRepository();

      await repo.upsertPlayer(player('p1', 'Gerico'));
      await repo.upsertPlayer(player('p1', 'Gerico II'));

      final data = await LocalRepository().load();

      expect(data.players, hasLength(1));
      expect(data.players.single.name, 'Gerico II');
    });

    test('borrar un jugador arrastra sus mazos y respeta los demás', () async {
      final repo = LocalRepository();

      await repo.upsertPlayer(player('p1', 'Gerico'));
      await repo.upsertPlayer(player('p2', 'Fummander'));
      await repo.upsertDeck(deck('d1', 'p1'));
      await repo.upsertDeck(deck('d2', 'p2'));

      await repo.deletePlayer('p1');

      final data = await LocalRepository().load();

      expect(data.players.single.id, 'p2');
      expect(data.decks.single.id, 'd2');
    });

    test('deleteMatch saca solo esa partida', () async {
      final repo = LocalRepository();

      await repo.upsertMatch(match('m1', 'p1'));
      await repo.upsertMatch(match('m2', 'p2'));

      await repo.deleteMatch('m1');

      final data = await LocalRepository().load();

      expect(data.matches.single.id, 'm2');
    });

    test('sigue escribiendo en las claves uft_*', () async {
      await LocalRepository().upsertPlayer(player('p1', 'Gerico'));

      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getString('uft_players'), contains('Gerico'));
    });

    // Escribir sin haber cargado antes no puede borrar lo que ya había
    // en el teléfono.
    test('un upsert sobre una instancia sin cargar no pisa lo guardado', () async {
      SharedPreferences.setMockInitialValues({
        'uft_players': jsonEncode([player('p1', 'Gerico').toJson()]),
      });

      await LocalRepository().upsertPlayer(player('p2', 'Fummander'));

      final data = await LocalRepository().load();

      expect(data.players.map((p) => p.id), containsAll(['p1', 'p2']));
    });
  });

  group('replaceAll', () {
    test('deja exactamente los datos recibidos', () async {
      SharedPreferences.setMockInitialValues({
        'uft_players': jsonEncode([player('viejo', 'Viejo').toJson()]),
      });

      final repo = LocalRepository();

      await repo.replaceAll(
        TrackerData(
          players: [player('p1', 'Gerico')],
          decks: const [],
          matches: const [],
          seasons: const [],
        ),
      );

      final data = await LocalRepository().load();

      expect(data.players.single.id, 'p1');
    });
  });

  group('watch', () {
    test('en local emite una sola vez y termina', () async {
      SharedPreferences.setMockInitialValues({
        'uft_players': jsonEncode([player('p1', 'Gerico').toJson()]),
      });

      final emissions = await LocalRepository().watch().toList();

      expect(emissions, hasLength(1));
      expect(emissions.single.players.single.id, 'p1');
    });
  });
}
