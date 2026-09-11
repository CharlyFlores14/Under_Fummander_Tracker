import 'package:flutter_test/flutter_test.dart';
import 'package:under_fummander_tracker/models.dart';

void main() {
  group('Serialización', () {
    test('Player sobrevive la ida y vuelta a JSON', () {
      final original = Player(id: 'p1', name: 'Gerico');

      final copy = Player.fromJson(original.toJson());

      expect(copy.id, original.id);
      expect(copy.name, original.name);
    });

    test('Deck sobrevive la ida y vuelta a JSON', () {
      final original = Deck(
        id: 'd1',
        name: 'Aristócratas',
        commander: 'Korvold, Fae-Cursed King',
        playerId: 'p1',
      );

      final copy = Deck.fromJson(original.toJson());

      expect(copy.id, original.id);
      expect(copy.name, original.name);
      expect(copy.commander, original.commander);
      expect(copy.playerId, original.playerId);
    });

    test('MatchRecord sobrevive la ida y vuelta a JSON', () {
      final original = MatchRecord(
        id: 'm1',
        date: DateTime(2026, 3, 14, 21, 30, 5, 123, 456),
        participants: {'p1': 'd1', 'p2': 'd2', 'p3': 'd3'},
        winnerPlayerId: 'p2',
        seasonId: 's1',
      );

      final copy = MatchRecord.fromJson(original.toJson());

      expect(copy.id, original.id);
      expect(copy.date, original.date);
      expect(copy.participants, original.participants);
      expect(copy.winnerPlayerId, original.winnerPlayerId);
      expect(copy.seasonId, original.seasonId);
    });

    test('MatchRecord sin temporada mantiene seasonId en null', () {
      final original = MatchRecord(
        id: 'm2',
        date: DateTime(2026, 1, 2),
        participants: {'p1': 'd1', 'p2': 'd2'},
        winnerPlayerId: 'p1',
      );

      expect(MatchRecord.fromJson(original.toJson()).seasonId, isNull);
    });

    test('Season abierta y cerrada sobreviven la ida y vuelta', () {
      final open = Season(
        id: 's1',
        name: 'Temporada 1',
        startDate: DateTime(2026, 1, 1),
      );

      final openCopy = Season.fromJson(open.toJson());

      expect(openCopy.endDate, isNull);
      expect(openCopy.isActive, isTrue);

      final closed = Season(
        id: 's2',
        name: 'Temporada 2',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 6, 30, 23, 59),
      );

      final closedCopy = Season.fromJson(closed.toJson());

      expect(closedCopy.endDate, closed.endDate);
      expect(closedCopy.isActive, isFalse);
    });

    // Los documentos que vuelven de Firestore llegan como
    // Map<String, dynamic> con mapas anidados sin tipar. Si fromJson
    // no tolerara eso, la app rompería solo en modo nube.
    test('MatchRecord.fromJson acepta un participants sin tipar', () {
      final raw = <String, dynamic>{
        'id': 'm3',
        'date': '2026-03-14T21:30:00.000',
        'participants': <dynamic, dynamic>{'p1': 'd1', 'p2': 'd2'},
        'winnerPlayerId': 'p1',
        'seasonId': null,
      };

      final match = MatchRecord.fromJson(raw);

      expect(match.participants, {'p1': 'd1', 'p2': 'd2'});
    });
  });

  group('newId', () {
    // La resolución del reloj depende del sistema operativo: en Windows
    // ronda el milisegundo, así que miles de ids seguidos comparten
    // timestamp. Con solo azar detrás, ahí aparecen las colisiones.
    test('no repite ids en un bucle cerrado', () {
      final ids = <String>{};

      for (int i = 0; i < 50000; i++) {
        ids.add(newId());
      }

      expect(ids.length, 50000);
    });

    test('tiene las tres partes: momento, secuencia y azar', () {
      final parts = newId().split('-');

      expect(parts, hasLength(3));

      for (final part in parts) {
        expect(int.tryParse(part), isNotNull);
      }
    });

    test('la secuencia avanza aunque el reloj no se mueva', () {
      final first = newId().split('-')[1];
      final second = newId().split('-')[1];

      expect(int.parse(second), int.parse(first) + 1);
    });
  });

  group('Rachas', () {
    // Las listas van de la partida más vieja a la más nueva.
    List<MatchRecord> build(List<bool> wins) {
      return [
        for (int i = 0; i < wins.length; i++)
          MatchRecord(
            id: 'm$i',
            date: DateTime(2026, 1, 1).add(Duration(days: i)),
            participants: {'p1': 'd1', 'p2': 'd2'},
            winnerPlayerId: wins[i] ? 'p1' : 'p2',
          ),
      ];
    }

    bool wonByP1(MatchRecord match) => match.winnerPlayerId == 'p1';

    test('la racha actual cuenta desde la última partida hacia atrás', () {
      expect(currentStreak(build([true, false, true, true]), wonByP1), 2);
    });

    test('la racha actual se corta con una derrota al final', () {
      expect(currentStreak(build([true, true, false]), wonByP1), 0);
    });

    test('la racha récord toma la mejor de toda la historia', () {
      expect(
        bestStreak(build([true, true, true, false, true]), wonByP1),
        3,
      );
    });

    test('sin partidas las dos rachas son cero', () {
      expect(currentStreak(const [], wonByP1), 0);
      expect(bestStreak(const [], wonByP1), 0);
    });
  });
}
