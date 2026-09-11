import 'dart:math';

// ============================================================
// MODELOS
// ============================================================

// Los ids se generan en el dispositivo, sin coordinación con el
// servidor, así que tienen que ser únicos por las suyas.
//
// El timestamp solo no alcanza: su resolución real depende del sistema
// operativo (en Windows ronda el milisegundo), y varias altas seguidas
// caen en el mismo "microsegundo". Por eso van tres partes:
//
//   - el timestamp, que ordena y separa por momento;
//   - un contador de proceso, que hace imposible que dos ids de este
//     teléfono coincidan por más rápido que se generen;
//   - 32 bits de azar, que es lo que separa a dos teléfonos del grupo
//     generando ids en el mismo instante.
final Random _random = Random();

int _sequence = 0;

String newId() {
  final micros = DateTime.now().microsecondsSinceEpoch;
  final sequence = _sequence++;
  final noise = _random.nextInt(0xFFFFFFFF);

  return '$micros-$sequence-$noise';
}

class Player {
  final String id;
  String name;

  Player({required this.id, required this.name});

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(id: json['id'], name: json['name']);
  }
}

class Deck {
  final String id;
  String name;
  String commander;
  String playerId;

  Deck({
    required this.id,
    required this.name,
    required this.commander,
    required this.playerId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'commander': commander,
      'playerId': playerId,
    };
  }

  factory Deck.fromJson(Map<String, dynamic> json) {
    return Deck(
      id: json['id'],
      name: json['name'],
      commander: json['commander'],
      playerId: json['playerId'],
    );
  }
}

class MatchRecord {
  final String id;
  final DateTime date;

  // playerId -> deckId
  final Map<String, String> participants;

  final String winnerPlayerId;

  final String? seasonId;

  MatchRecord({
    required this.id,
    required this.date,
    required this.participants,
    required this.winnerPlayerId,
    this.seasonId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'participants': participants,
      'winnerPlayerId': winnerPlayerId,
      'seasonId': seasonId,
    };
  }

  factory MatchRecord.fromJson(Map<String, dynamic> json) {
    return MatchRecord(
      id: json['id'],
      date: DateTime.parse(json['date']),
      participants: Map<String, String>.from(json['participants']),
      winnerPlayerId: json['winnerPlayerId'],
      seasonId: json['seasonId'] as String?,
    );
  }
}

class Season {
  final String id;
  String name;
  final DateTime startDate;
  DateTime? endDate;

  Season({
    required this.id,
    required this.name,
    required this.startDate,
    this.endDate,
  });

  bool get isActive => endDate == null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
    };
  }

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      id: json['id'],
      name: json['name'],
      startDate: DateTime.parse(json['startDate']),
      endDate: json['endDate'] == null ? null : DateTime.parse(json['endDate']),
    );
  }
}

// ============================================================
// HELPERS COMPARTIDOS
// ============================================================

Deck? findDeckById(List<Deck> decks, String id) {
  for (final deck in decks) {
    if (deck.id == id) return deck;
  }
  return null;
}

Player? findPlayerById(List<Player> players, String id) {
  for (final player in players) {
    if (player.id == id) return player;
  }
  return null;
}

Season? findSeasonById(List<Season> seasons, String? id) {
  if (id == null) return null;
  for (final season in seasons) {
    if (season.id == id) return season;
  }
  return null;
}

// Racha actual: victorias consecutivas contando desde la partida más
// reciente hacia atrás, hasta la primera derrota. La lista recibida
// debe venir ordenada de más vieja a más nueva.
int currentStreak(
  List<MatchRecord> chronologicalAsc,
  bool Function(MatchRecord match) isWin,
) {
  int streak = 0;

  for (int i = chronologicalAsc.length - 1; i >= 0; i--) {
    if (isWin(chronologicalAsc[i])) {
      streak++;
    } else {
      break;
    }
  }

  return streak;
}

// Racha récord: la mayor cantidad de victorias consecutivas en toda
// la historia. La lista recibida debe venir ordenada de más vieja a
// más nueva.
int bestStreak(
  List<MatchRecord> chronologicalAsc,
  bool Function(MatchRecord match) isWin,
) {
  int best = 0;
  int current = 0;

  for (final match in chronologicalAsc) {
    if (isWin(match)) {
      current++;
      if (current > best) best = current;
    } else {
      current = 0;
    }
  }

  return best;
}

class MatchupStat {
  int wins = 0;
  int losses = 0;

  int get total => wins + losses;

  double get rate => total == 0 ? 0 : wins / total * 100;
}
