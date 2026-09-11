import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const UnderFummanderTracker());
}

// ============================================================
// APP
// ============================================================

class UnderFummanderTracker extends StatelessWidget {
  const UnderFummanderTracker({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Under Fummander Tracker',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const TrackerHome(),
    );
  }
}

// ============================================================
// MODELOS
// ============================================================

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
// STORAGE
// ============================================================

class Storage {
  static const playersKey = 'uft_players';
  static const decksKey = 'uft_decks';
  static const matchesKey = 'uft_matches';
  static const seasonsKey = 'uft_seasons';

  static Future<void> save({
    required List<Player> players,
    required List<Deck> decks,
    required List<MatchRecord> matches,
    required List<Season> seasons,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      playersKey,
      jsonEncode(players.map((p) => p.toJson()).toList()),
    );

    await prefs.setString(
      decksKey,
      jsonEncode(decks.map((d) => d.toJson()).toList()),
    );

    await prefs.setString(
      matchesKey,
      jsonEncode(matches.map((m) => m.toJson()).toList()),
    );

    await prefs.setString(
      seasonsKey,
      jsonEncode(seasons.map((s) => s.toJson()).toList()),
    );
  }

  static Future<Map<String, dynamic>> load() async {
    final prefs = await SharedPreferences.getInstance();

    final playersData = prefs.getString(playersKey);
    final decksData = prefs.getString(decksKey);
    final matchesData = prefs.getString(matchesKey);
    final seasonsData = prefs.getString(seasonsKey);

    if (playersData == null) {
      return {
        'players': <Player>[],
        'decks': <Deck>[],
        'matches': <MatchRecord>[],
        'seasons': <Season>[],
      };
    }

    final players = (jsonDecode(playersData) as List)
        .map((e) => Player.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final decks = decksData == null
        ? <Deck>[]
        : (jsonDecode(decksData) as List)
              .map((e) => Deck.fromJson(Map<String, dynamic>.from(e)))
              .toList();

    final matches = matchesData == null
        ? <MatchRecord>[]
        : (jsonDecode(matchesData) as List)
              .map((e) => MatchRecord.fromJson(Map<String, dynamic>.from(e)))
              .toList();

    final seasons = seasonsData == null
        ? <Season>[]
        : (jsonDecode(seasonsData) as List)
              .map((e) => Season.fromJson(Map<String, dynamic>.from(e)))
              .toList();

    return {
      'players': players,
      'decks': decks,
      'matches': matches,
      'seasons': seasons,
    };
  }
}

// ============================================================
// HOME
// ============================================================

class TrackerHome extends StatefulWidget {
  const TrackerHome({super.key});

  @override
  State<TrackerHome> createState() => _TrackerHomeState();
}

class _TrackerHomeState extends State<TrackerHome> {
  List<Player> players = [];
  List<Deck> decks = [];
  List<MatchRecord> matches = [];
  List<Season> seasons = [];

  bool loading = true;

  int currentPage = 0;

  // 'ALL' = todas las partidas, 'NONE' = sin temporada, o el id de una temporada
  String historySeasonFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final data = await Storage.load();

    players = data['players'] as List<Player>;
    decks = data['decks'] as List<Deck>;
    matches = data['matches'] as List<MatchRecord>;
    seasons = data['seasons'] as List<Season>;

    if (!mounted) return;

    setState(() {
      loading = false;
    });
  }

  Future<void> saveData() async {
    await Storage.save(
      players: players,
      decks: decks,
      matches: matches,
      seasons: seasons,
    );
  }

  Season? get activeSeason {
    for (final season in seasons) {
      if (season.isActive) return season;
    }
    return null;
  }

  Future<void> _createSeason(Season season) async {
    seasons.add(season);
    await saveData();
    setState(() {});
  }

  Future<void> _closeSeason(Season season) async {
    season.endDate = DateTime.now();
    await saveData();
    setState(() {});
  }

  Player? playerById(String id) {
    for (final player in players) {
      if (player.id == id) return player;
    }

    return null;
  }

  Deck? deckById(String id) {
    for (final deck in decks) {
      if (deck.id == id) return deck;
    }

    return null;
  }

  int playerWins(String playerId) {
    return matches.where((match) => match.winnerPlayerId == playerId).length;
  }

  int playerLosses(String playerId) {
    int losses = 0;

    for (final match in matches) {
      if (match.participants.containsKey(playerId) &&
          match.winnerPlayerId != playerId) {
        losses++;
      }
    }

    return losses;
  }

  int deckWins(String deckId) {
    return matches
        .where((match) => match.participants[match.winnerPlayerId] == deckId)
        .length;
  }

  int deckLosses(String deckId) {
    int losses = 0;

    for (final match in matches) {
      if (match.participants.containsValue(deckId)) {
        final winningDeck = match.participants[match.winnerPlayerId];

        if (winningDeck != deckId) {
          losses++;
        }
      }
    }

    return losses;
  }

  // Partidas de un jugador ordenadas de más vieja a más nueva
  List<MatchRecord> matchesForPlayer(String playerId) {
    final list = matches
        .where((m) => m.participants.containsKey(playerId))
        .toList();

    list.sort((a, b) => a.date.compareTo(b.date));

    return list;
  }

  // Partidas de un mazo ordenadas de más vieja a más nueva
  List<MatchRecord> matchesForDeck(String deckId) {
    final list = matches
        .where((m) => m.participants.values.contains(deckId))
        .toList();

    list.sort((a, b) => a.date.compareTo(b.date));

    return list;
  }

  bool deckWonMatch(MatchRecord match, String deckId) {
    return match.participants[match.winnerPlayerId] == deckId;
  }

  int playerCurrentStreak(String playerId) {
    return currentStreak(
      matchesForPlayer(playerId),
      (m) => m.winnerPlayerId == playerId,
    );
  }

  int deckCurrentStreak(String deckId) {
    return currentStreak(
      matchesForDeck(deckId),
      (m) => deckWonMatch(m, deckId),
    );
  }

  void newMatch() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewMatchScreen(
          players: players,
          decks: decks,
          activeSeasonId: activeSeason?.id,
          onMatchCreated: (match) async {
            matches.add(match);
            await saveData();
            setState(() {});
          },
        ),
      ),
    );

    setState(() {});
  }

  void _editMatch(MatchRecord match) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewMatchScreen(
          players: players,
          decks: decks,
          existingMatch: match,
          activeSeasonId: activeSeason?.id,
          onMatchCreated: (updatedMatch) async {
            final index = matches.indexWhere((m) => m.id == match.id);

            if (index != -1) {
              matches[index] = updatedMatch;
            } else {
              matches.add(updatedMatch);
            }

            await saveData();
            setState(() {});
          },
        ),
      ),
    );

    setState(() {});
  }

  void _openSeasons() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SeasonsScreen(
          seasons: seasons,
          matches: matches,
          onCreateSeason: _createSeason,
          onCloseSeason: _closeSeason,
        ),
      ),
    );

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = [_homePage(), _playersPage(), _decksPage(), _historyPage()];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '⚔️ Under Fummander Tracker',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _openSeasons,
            icon: const Icon(Icons.calendar_month),
            tooltip: activeSeason == null
                ? 'Temporadas'
                : 'Temporada activa: ${activeSeason!.name}',
          ),
        ],
      ),

      body: pages[currentPage],

      floatingActionButton: currentPage == 0
          ? FloatingActionButton.extended(
              onPressed: newMatch,
              icon: const Icon(Icons.sports_mma),
              label: const Text('Nueva partida'),
            )
          : null,

      bottomNavigationBar: NavigationBar(
        selectedIndex: currentPage,
        onDestinationSelected: (index) {
          setState(() {
            currentPage = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Ranking',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Jugadores',
          ),
          NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style),
            label: 'Mazos',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history),
            label: 'Historial',
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // RANKING
  // ==========================================================

  Widget _homePage() {
    final ranking = [...players];

    ranking.sort((a, b) {
      final aw = playerWins(a.id);
      final al = playerLosses(a.id);

      final bw = playerWins(b.id);
      final bl = playerLosses(b.id);

      final at = aw + al;
      final bt = bw + bl;

      final ar = at == 0 ? 0.0 : aw / at;
      final br = bt == 0 ? 0.0 : bw / bt;

      return br.compareTo(ar);
    });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '🏆 Ranking',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 6),

        Text(
          '${matches.length} partidas registradas',
          style: TextStyle(color: Colors.grey.shade400),
        ),

        const SizedBox(height: 16),

        ...List.generate(ranking.length, (index) {
          final player = ranking[index];

          final wins = playerWins(player.id);
          final losses = playerLosses(player.id);
          final streak = playerCurrentStreak(player.id);

          final total = wins + losses;

          final rate = total == 0 ? 0.0 : wins / total * 100;

          String position;

          if (index == 0) {
            position = '🥇';
          } else if (index == 1) {
            position = '🥈';
          } else if (index == 2) {
            position = '🥉';
          } else {
            position = '${index + 1}';
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  SizedBox(
                    width: 42,
                    child: Text(
                      position,
                      style: const TextStyle(fontSize: 23),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          player.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          streak >= 2
                              ? '$wins victorias • $losses derrotas • 🔥$streak seguidas'
                              : '$wins victorias • $losses derrotas',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),

                  Text(
                    '${rate.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ==========================================================
  // JUGADORES
  // ==========================================================

  Widget _playersPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '👥 Jugadores',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              onPressed: _addPlayer,
              icon: const Icon(Icons.person_add),
              tooltip: 'Agregar jugador',
            ),
          ],
        ),

        const SizedBox(height: 10),

        if (players.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.people_outline, size: 60),
                  SizedBox(height: 15),
                  Text(
                    'Todavía no hay jugadores',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text('Agregá el primer jugador para comenzar.'),
                ],
              ),
            ),
          ),

        ...players.map((player) {
          final wins = playerWins(player.id);
          final losses = playerLosses(player.id);
          final playerDecks = decks
              .where((deck) => deck.playerId == player.id)
              .toList();

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),

              title: Text(
                player.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),

              subtitle: Text(
                '${wins}W / ${losses}L • '
                '${playerDecks.length} mazo(s)',
              ),

              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _editPlayer(player);
                  } else if (value == 'delete') {
                    _deletePlayer(player);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('Editar'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete),
                      title: Text('Eliminar'),
                    ),
                  ),
                ],
              ),

              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerStatsScreen(
                      player: player,
                      players: players,
                      decks: decks,
                      matches: matches,
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }

  Future<void> _addPlayer() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nuevo jugador'),

          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Ej: Martín',
            ),
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),

            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();

                if (name.isEmpty) return;

                final alreadyExists = players.any(
                  (player) => player.name.toLowerCase() == name.toLowerCase(),
                );

                if (alreadyExists) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ya existe un jugador con ese nombre.'),
                    ),
                  );
                  return;
                }

                players.add(
                  Player(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    name: name,
                  ),
                );

                await saveData();

                if (!mounted) return;

                Navigator.pop(dialogContext);
                setState(() {});
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  Future<void> _editPlayer(Player player) async {
    final controller = TextEditingController(text: player.name);

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Editar jugador'),

          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),

            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();

                if (name.isEmpty) return;

                final alreadyExists = players.any(
                  (otherPlayer) =>
                      otherPlayer.id != player.id &&
                      otherPlayer.name.toLowerCase() == name.toLowerCase(),
                );

                if (alreadyExists) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ya existe otro jugador con ese nombre.'),
                    ),
                  );
                  return;
                }

                player.name = name;

                await saveData();

                if (!mounted) return;

                Navigator.pop(dialogContext);
                setState(() {});
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  Future<void> _deletePlayer(Player player) async {
    final playerHasMatches = matches.any(
      (match) => match.participants.containsKey(player.id),
    );

    final playerDecks = decks
        .where((deck) => deck.playerId == player.id)
        .toList();

    if (playerHasMatches) {
      await showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('No se puede eliminar'),
            content: Text(
              'El jugador "${player.name}" tiene partidas registradas. '
              'No se puede eliminar porque sus estadísticas e historial '
              'quedarían incompletos.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Entendido'),
              ),
            ],
          );
        },
      );

      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('¿Eliminar jugador?'),

          content: Text(
            'Se va a eliminar a "${player.name}".'
            '${playerDecks.isNotEmpty ? '\n\nTambién se eliminarán sus ${playerDecks.length} mazo(s).' : ''}'
            '\n\nEsta acción no se puede deshacer.',
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),

            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    players.removeWhere((item) => item.id == player.id);

    decks.removeWhere((deck) => deck.playerId == player.id);

    await saveData();

    if (!mounted) return;

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Jugador "${player.name}" eliminado.')),
    );
  }
  // ==========================================================
  // MAZOS
  // ==========================================================

  Widget _decksPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '🃏 Mazos',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
              ),
            ),

            IconButton(
              onPressed: _addDeck,
              icon: const Icon(Icons.add),
              tooltip: 'Agregar mazo',
            ),
          ],
        ),

        const SizedBox(height: 10),

        ...decks.map((deck) {
          final player = playerById(deck.playerId);

          final wins = deckWins(deck.id);
          final losses = deckLosses(deck.id);
          final streak = deckCurrentStreak(deck.id);

          final total = wins + losses;

          final rate = total == 0 ? 0.0 : wins / total * 100;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),

            child: ListTile(
              leading: const Icon(Icons.style, size: 30),

              title: Text(
                deck.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),

              subtitle: Text(
                '${player?.name ?? "Sin jugador"}\n'
                '${deck.commander}'
                '${streak >= 2 ? ' • 🔥$streak seguidas' : ''}',
              ),

              isThreeLine: true,

              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  Text(
                    '${rate.toStringAsFixed(1)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),

                  Text(
                    '${wins}W / ${losses}L',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                ],
              ),

              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DeckStatsScreen(
                      deck: deck,
                      players: players,
                      decks: decks,
                      matches: matches,
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }

  Future<void> _addDeck() async {
    if (players.isEmpty) return;

    final nameController = TextEditingController();
    final commanderController = TextEditingController();

    String selectedPlayer = players.first.id;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Nuevo mazo'),

              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del mazo',
                        hintText: 'Ej: Ral Storm',
                      ),
                    ),

                    const SizedBox(height: 10),

                    TextField(
                      controller: commanderController,
                      decoration: const InputDecoration(
                        labelText: 'Comandante',
                        hintText: 'Ej: Ral, Leyline Prodigy',
                      ),
                    ),

                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      initialValue: selectedPlayer,
                      decoration: const InputDecoration(labelText: 'Jugador'),
                      items: players.map((player) {
                        return DropdownMenuItem(
                          value: player.id,
                          child: Text(player.name),
                        );
                      }).toList(),

                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          selectedPlayer = value;
                        });
                      },
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),

                FilledButton(
                  onPressed: () async {
                    final name = nameController.text.trim();

                    final commander = commanderController.text.trim();

                    if (name.isEmpty || commander.isEmpty) {
                      return;
                    }

                    decks.add(
                      Deck(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        name: name,
                        commander: commander,
                        playerId: selectedPlayer,
                      ),
                    );

                    await saveData();

                    if (mounted) {
                      Navigator.pop(context);
                      setState(() {});
                    }
                  },
                  child: const Text('Agregar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================================
  // HISTORIAL
  // ==========================================================

  Widget _historyPage() {
    if (matches.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 60),

            SizedBox(height: 15),

            Text(
              'Todavía no hay partidas',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            SizedBox(height: 5),

            Text('Registrá la primera partida'),
          ],
        ),
      );
    }

    final sortedSeasons = [...seasons]
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    final history = matches.where((match) {
      switch (historySeasonFilter) {
        case 'ALL':
          return true;
        case 'NONE':
          return match.seasonId == null;
        default:
          return match.seasonId == historySeasonFilter;
      }
    }).toList()..sort((a, b) => b.date.compareTo(a.date));

    return ListView(
      padding: const EdgeInsets.all(16),

      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '📜 Historial',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
              ),
            ),

            IconButton(
              onPressed: _openSeasons,
              icon: const Icon(Icons.calendar_month),
              tooltip: 'Gestionar temporadas',
            ),
          ],
        ),

        const SizedBox(height: 10),

        DropdownButtonFormField<String>(
          initialValue: historySeasonFilter,
          decoration: const InputDecoration(
            labelText: 'Temporada',
            isDense: true,
          ),
          items: [
            const DropdownMenuItem(
              value: 'ALL',
              child: Text('Todas las partidas'),
            ),
            const DropdownMenuItem(value: 'NONE', child: Text('Sin temporada')),
            ...sortedSeasons.map(
              (season) => DropdownMenuItem(
                value: season.id,
                child: Text(
                  season.isActive ? '${season.name} (en curso)' : season.name,
                ),
              ),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              historySeasonFilter = value;
            });
          },
        ),

        const SizedBox(height: 15),

        if (history.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: Text('No hay partidas para esta temporada.')),
          ),

        ...history.map((match) {
          final winner = playerById(match.winnerPlayerId);

          final date = match.date;

          final dateText =
              '${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}/'
              '${date.year}';

          return Dismissible(
            key: ValueKey(match.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.only(bottom: 10),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
              return await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('¿Eliminar partida?'),
                  content: Text(
                    'Se va a borrar la partida del $dateText '
                    'donde ganó ${winner?.name ?? "desconocido"}. '
                    'Esta acción no se puede deshacer.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Eliminar'),
                    ),
                  ],
                ),
              );
            },
            onDismissed: (direction) async {
              matches.removeWhere((m) => m.id == match.id);
              await saveData();
              setState(() {});
            },
            child: Card(
              margin: const EdgeInsets.only(bottom: 10),

              child: ExpansionTile(
                leading: const Icon(Icons.emoji_events),

                title: Text(
                  winner?.name ?? 'Ganador desconocido',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                subtitle: Text(
                  '$dateText • '
                  '${match.participants.length} jugadores'
                  '${match.seasonId == null ? '' : ' • ${findSeasonById(seasons, match.seasonId)?.name ?? ""}'}',
                ),

                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Editar partida',
                  onPressed: () => _editMatch(match),
                ),

                children: [
                  ...match.participants.entries.map((entry) {
                    final player = playerById(entry.key);

                    final deck = deckById(entry.value);

                    final isWinner = entry.key == match.winnerPlayerId;

                    return ListTile(
                      leading: Icon(
                        isWinner ? Icons.emoji_events : Icons.person,
                      ),

                      title: Text(player?.name ?? 'Jugador desconocido'),

                      subtitle: Text(deck?.name ?? 'Mazo desconocido'),

                      trailing: isWinner
                          ? const Text(
                              'GANADOR',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            )
                          : const Text('Derrota'),
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ============================================================
// NUEVA PARTIDA / EDITAR PARTIDA
// ============================================================

class NewMatchScreen extends StatefulWidget {
  final List<Player> players;
  final List<Deck> decks;
  final MatchRecord? existingMatch;
  final String? activeSeasonId;

  final Future<void> Function(MatchRecord match) onMatchCreated;

  const NewMatchScreen({
    super.key,
    required this.players,
    required this.decks,
    required this.onMatchCreated,
    this.existingMatch,
    this.activeSeasonId,
  });

  @override
  State<NewMatchScreen> createState() => _NewMatchScreenState();
}

class _NewMatchScreenState extends State<NewMatchScreen> {
  final Set<String> selectedPlayers = {};

  final Map<String, String> selectedDecks = {};

  String? winnerPlayerId;

  bool get isEditing => widget.existingMatch != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existingMatch;

    if (existing != null) {
      selectedPlayers.addAll(existing.participants.keys);
      selectedDecks.addAll(existing.participants);
      winnerPlayerId = existing.winnerPlayerId;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '✏️ Editar partida' : '⚔️ Nueva partida'),
      ),

      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  '¿Quiénes jugaron?',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 5),

                Text(
                  '${selectedPlayers.length} '
                  'participantes seleccionados',
                  style: TextStyle(color: Colors.grey.shade400),
                ),

                const SizedBox(height: 15),

                ...widget.players.map((player) {
                  final selected = selectedPlayers.contains(player.id);

                  final playerDecks = widget.decks
                      .where((deck) => deck.playerId == player.id)
                      .toList();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),

                    child: Padding(
                      padding: const EdgeInsets.all(8),

                      child: Column(
                        children: [
                          CheckboxListTile(
                            value: selected,

                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  selectedPlayers.add(player.id);

                                  if (playerDecks.isNotEmpty) {
                                    selectedDecks[player.id] ??=
                                        playerDecks.first.id;
                                  }
                                } else {
                                  selectedPlayers.remove(player.id);

                                  selectedDecks.remove(player.id);

                                  if (winnerPlayerId == player.id) {
                                    winnerPlayerId = null;
                                  }
                                }
                              });
                            },

                            title: Text(
                              player.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            subtitle: Text(
                              '${playerDecks.length} '
                              'mazo(s)',
                            ),

                            secondary: selected
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                : const Icon(Icons.person_outline),
                          ),

                          if (selected)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                              child: DropdownButtonFormField<String>(
                                initialValue: selectedDecks[player.id],

                                decoration: const InputDecoration(
                                  labelText: 'Mazo utilizado',
                                ),

                                items: playerDecks.map((deck) {
                                  return DropdownMenuItem(
                                    value: deck.id,
                                    child: Text(deck.name),
                                  );
                                }).toList(),

                                onChanged: playerDecks.isEmpty
                                    ? null
                                    : (value) {
                                        if (value == null) {
                                          return;
                                        }

                                        setState(() {
                                          selectedDecks[player.id] = value;
                                        });
                                      },
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 10),

                if (selectedPlayers.length >= 2) _winnerSection(),

                if (selectedPlayers.length < 2)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text('Seleccioná al menos 2 jugadores.'),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _canRegister() ? _registerMatch : null,

                icon: const Icon(Icons.emoji_events),

                label: Text(
                  isEditing ? 'GUARDAR CAMBIOS' : 'REGISTRAR PARTIDA',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _winnerSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text(
              '🏆 ¿Quién ganó?',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            ...widget.players
                .where((player) => selectedPlayers.contains(player.id))
                .map((player) {
                  final deckId = selectedDecks[player.id];

                  final deck = deckId == null
                      ? null
                      : widget.decks.firstWhere(
                          (d) => d.id == deckId,
                          orElse: () => Deck(
                            id: '',
                            name: 'Sin mazo',
                            commander: '',
                            playerId: '',
                          ),
                        );

                  return RadioListTile<String>(
                    value: player.id,
                    groupValue: winnerPlayerId,

                    onChanged: deck == null || deck.id.isEmpty
                        ? null
                        : (value) {
                            setState(() {
                              winnerPlayerId = value;
                            });
                          },

                    title: Text(player.name),

                    subtitle: Text(
                      deck == null ? '⚠️ Sin mazo' : '🃏 ${deck.name}',
                    ),
                  );
                }),
          ],
        ),
      ),
    );
  }

  bool _canRegister() {
    if (selectedPlayers.length < 2) {
      return false;
    }

    if (winnerPlayerId == null) {
      return false;
    }

    for (final playerId in selectedPlayers) {
      if (!selectedDecks.containsKey(playerId)) {
        return false;
      }
    }

    return true;
  }

  Future<void> _registerMatch() async {
    if (!_canRegister()) return;

    final match = MatchRecord(
      id:
          widget.existingMatch?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),

      date: widget.existingMatch?.date ?? DateTime.now(),

      participants: {
        for (final playerId in selectedPlayers)
          playerId: selectedDecks[playerId]!,
      },

      winnerPlayerId: winnerPlayerId!,

      seasonId: widget.existingMatch?.seasonId ?? widget.activeSeasonId,
    );

    await widget.onMatchCreated(match);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        final winner = widget.players.firstWhere((p) => p.id == winnerPlayerId);

        return AlertDialog(
          title: Text(
            isEditing ? '✏️ ¡Partida actualizada!' : '🏆 ¡Partida registrada!',
          ),

          content: Text(
            '${winner.name} ganó.\n\n'
            'Participaron '
            '${selectedPlayers.length} jugadores.',
          ),

          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Perfecto'),
            ),
          ],
        );
      },
    );

    if (mounted) {
      Navigator.pop(context);
    }
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

// ============================================================
// TEMPORADAS
// ============================================================

class SeasonsScreen extends StatefulWidget {
  final List<Season> seasons;
  final List<MatchRecord> matches;
  final Future<void> Function(Season season) onCreateSeason;
  final Future<void> Function(Season season) onCloseSeason;

  const SeasonsScreen({
    super.key,
    required this.seasons,
    required this.matches,
    required this.onCreateSeason,
    required this.onCloseSeason,
  });

  @override
  State<SeasonsScreen> createState() => _SeasonsScreenState();
}

class _SeasonsScreenState extends State<SeasonsScreen> {
  Season? get _active {
    for (final season in widget.seasons) {
      if (season.isActive) return season;
    }
    return null;
  }

  int _matchCount(Season season) {
    return widget.matches.where((m) => m.seasonId == season.id).length;
  }

  String _fmt(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  Future<void> _createSeason() async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nueva temporada'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              hintText: 'Ej: Temporada 1 - Verano 2026',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );

    if (name == null || name.isEmpty) return;

    if (_active != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('¿Cerrar temporada activa?'),
            content: Text(
              'Ya hay una temporada activa ("${_active!.name}"). '
              'Al crear una nueva, la actual se va a cerrar '
              'automáticamente.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continuar'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) return;

      await widget.onCloseSeason(_active!);
    }

    final season = Season(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      startDate: DateTime.now(),
    );

    await widget.onCreateSeason(season);

    if (mounted) setState(() {});
  }

  Future<void> _closeSeason(Season season) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('¿Cerrar temporada?'),
          content: Text(
            'Se va a cerrar "${season.name}". Las próximas partidas '
            'van a quedar sin temporada hasta que crees una nueva.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await widget.onCloseSeason(season);

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.seasons]
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    return Scaffold(
      appBar: AppBar(title: const Text('🗓️ Temporadas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createSeason,
        icon: const Icon(Icons.add),
        label: const Text('Nueva temporada'),
      ),
      body: sorted.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavía no creaste ninguna temporada.\n'
                  'Las partidas que registres sin temporada activa '
                  'van a quedar como "Sin temporada".',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: sorted.map((season) {
                final count = _matchCount(season);

                final rangeText = season.isActive
                    ? 'Desde ${_fmt(season.startDate)} • En curso'
                    : '${_fmt(season.startDate)} — '
                          '${_fmt(season.endDate!)}';

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Icon(
                      season.isActive
                          ? Icons.play_circle_fill
                          : Icons.check_circle_outline,
                      color: season.isActive ? Colors.green : null,
                    ),
                    title: Text(
                      season.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('$rangeText\n$count partidas'),
                    isThreeLine: true,
                    trailing: season.isActive
                        ? TextButton(
                            onPressed: () => _closeSeason(season),
                            child: const Text('Cerrar'),
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
    );
  }
}

// ============================================================
// GRÁFICO DE EVOLUCIÓN DE WIN RATE
// ============================================================

class WinRateChart extends StatelessWidget {
  final List<double> values;

  const WinRateChart({super.key, required this.values});

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(
        height: 140,
        child: Center(
          child: Text(
            'Necesitás al menos 2 partidas para ver la evolución',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ),
      );
    }

    return SizedBox(
      height: 140,
      child: CustomPaint(
        painter: _WinRateChartPainter(values),
        size: Size.infinite,
      ),
    );
  }
}

class _WinRateChartPainter extends CustomPainter {
  final List<double> values;

  _WinRateChartPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    TextPainter textPainterFor(int pct) {
      final tp = TextPainter(
        text: TextSpan(
          text: '$pct%',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      return tp;
    }

    for (final pct in [0, 25, 50, 75, 100]) {
      final y = size.height - (pct / 100 * size.height);
      canvas.drawLine(Offset(28, y), Offset(size.width, y), gridPaint);

      final tp = textPainterFor(pct);
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    final chartWidth = size.width - 28;

    final linePaint = Paint()
      ..color = Colors.deepPurpleAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = Colors.deepPurpleAccent.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < values.length; i++) {
      final x = 28 + i / (values.length - 1) * chartWidth;
      final y = size.height - (values[i] / 100 * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(28 + chartWidth, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = Colors.deepPurpleAccent;

    for (int i = 0; i < values.length; i++) {
      final x = 28 + i / (values.length - 1) * chartWidth;
      final y = size.height - (values[i] / 100 * size.height);
      canvas.drawCircle(Offset(x, y), 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WinRateChartPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

// ============================================================
// ESTADÍSTICAS POR JUGADOR
// ============================================================

class PlayerStatsScreen extends StatelessWidget {
  final Player player;
  final List<Player> players;
  final List<Deck> decks;
  final List<MatchRecord> matches;

  const PlayerStatsScreen({
    super.key,
    required this.player,
    required this.players,
    required this.decks,
    required this.matches,
  });

  List<MatchRecord> get _playerMatches {
    final list = matches
        .where((m) => m.participants.containsKey(player.id))
        .toList();

    list.sort((a, b) => a.date.compareTo(b.date));

    return list;
  }

  int get _wins =>
      _playerMatches.where((m) => m.winnerPlayerId == player.id).length;

  int get _losses => _playerMatches.length - _wins;

  double get _winRate =>
      _playerMatches.isEmpty ? 0 : _wins / _playerMatches.length * 100;

  int get _currentStreak =>
      currentStreak(_playerMatches, (m) => m.winnerPlayerId == player.id);

  int get _bestStreak =>
      bestStreak(_playerMatches, (m) => m.winnerPlayerId == player.id);

  Deck? get _favoriteDeck {
    final counts = <String, int>{};

    for (final match in _playerMatches) {
      final deckId = match.participants[player.id];
      if (deckId != null) {
        counts[deckId] = (counts[deckId] ?? 0) + 1;
      }
    }

    if (counts.isEmpty) return null;

    var topId = counts.keys.first;
    var topCount = counts.values.first;

    counts.forEach((id, count) {
      if (count > topCount) {
        topId = id;
        topCount = count;
      }
    });

    return findDeckById(decks, topId);
  }

  List<double> get _cumulativeWinRates {
    final rates = <double>[];
    int wins = 0;

    for (int i = 0; i < _playerMatches.length; i++) {
      if (_playerMatches[i].winnerPlayerId == player.id) wins++;
      rates.add(wins / (i + 1) * 100);
    }

    return rates;
  }

  Map<String, MatchupStat> get _matchupsVsDecks {
    final map = <String, MatchupStat>{};

    for (final match in _playerMatches) {
      final won = match.winnerPlayerId == player.id;

      for (final entry in match.participants.entries) {
        if (entry.key == player.id) continue;

        final oppDeckId = entry.value;

        map.putIfAbsent(oppDeckId, () => MatchupStat());

        if (won) {
          map[oppDeckId]!.wins++;
        } else {
          map[oppDeckId]!.losses++;
        }
      }
    }

    return map;
  }

  @override
  Widget build(BuildContext context) {
    final matchups = _matchupsVsDecks.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    return Scaffold(
      appBar: AppBar(title: Text(player.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_wins victorias • $_losses derrotas',
                          style: const TextStyle(fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_playerMatches.length} partidas jugadas',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${_winRate.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          if (_favoriteDeck != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.favorite, color: Colors.pinkAccent),
                title: const Text('Mazo favorito'),
                subtitle: Text(
                  '${_favoriteDeck!.name} (${_favoriteDeck!.commander})',
                ),
              ),
            ),

          if (_currentStreak >= 2)
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.local_fire_department,
                  color: Colors.orange,
                ),
                title: const Text('Racha actual'),
                subtitle: Text('$_currentStreak victorias seguidas'),
              ),
            ),

          if (_bestStreak >= 2)
            Card(
              child: ListTile(
                leading: const Icon(Icons.emoji_events, color: Colors.amber),
                title: const Text('Racha récord'),
                subtitle: Text('$_bestStreak victorias seguidas'),
              ),
            ),

          const SizedBox(height: 16),

          const Text(
            '📈 Evolución del win rate',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
              child: WinRateChart(values: _cumulativeWinRates),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            '⚔️ Matchups contra mazos rivales',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          if (matchups.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Todavía no hay partidas registradas.'),
            ),

          ...matchups.map((entry) {
            final deck = findDeckById(decks, entry.key);
            final stat = entry.value;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(deck?.name ?? 'Mazo desconocido'),
                subtitle: Text('${stat.wins}W / ${stat.losses}L'),
                trailing: Text(
                  '${stat.rate.toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ============================================================
// ESTADÍSTICAS POR MAZO
// ============================================================

class DeckStatsScreen extends StatelessWidget {
  final Deck deck;
  final List<Player> players;
  final List<Deck> decks;
  final List<MatchRecord> matches;

  const DeckStatsScreen({
    super.key,
    required this.deck,
    required this.players,
    required this.decks,
    required this.matches,
  });

  List<MatchRecord> get _deckMatches {
    final list = matches
        .where((m) => m.participants.values.contains(deck.id))
        .toList();

    list.sort((a, b) => a.date.compareTo(b.date));

    return list;
  }

  bool _deckWon(MatchRecord match) {
    return match.participants[match.winnerPlayerId] == deck.id;
  }

  int get _wins => _deckMatches.where(_deckWon).length;

  int get _losses => _deckMatches.length - _wins;

  double get _winRate =>
      _deckMatches.isEmpty ? 0 : _wins / _deckMatches.length * 100;

  int get _currentStreak => currentStreak(_deckMatches, _deckWon);

  int get _bestStreak => bestStreak(_deckMatches, _deckWon);

  List<double> get _cumulativeWinRates {
    final rates = <double>[];
    int wins = 0;

    for (int i = 0; i < _deckMatches.length; i++) {
      if (_deckWon(_deckMatches[i])) wins++;
      rates.add(wins / (i + 1) * 100);
    }

    return rates;
  }

  Map<String, MatchupStat> get _matchupsVsDecks {
    final map = <String, MatchupStat>{};

    for (final match in _deckMatches) {
      final won = _deckWon(match);

      for (final oppDeckId in match.participants.values) {
        if (oppDeckId == deck.id) continue;

        map.putIfAbsent(oppDeckId, () => MatchupStat());

        if (won) {
          map[oppDeckId]!.wins++;
        } else {
          map[oppDeckId]!.losses++;
        }
      }
    }

    return map;
  }

  @override
  Widget build(BuildContext context) {
    final owner = findPlayerById(players, deck.playerId);

    final matchups = _matchupsVsDecks.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    MapEntry<String, MatchupStat>? best;
    MapEntry<String, MatchupStat>? worst;

    final withEnoughGames = matchups.where((e) => e.value.total >= 2).toList();

    if (withEnoughGames.isNotEmpty) {
      best = withEnoughGames.reduce(
        (a, b) => a.value.rate >= b.value.rate ? a : b,
      );
      worst = withEnoughGames.reduce(
        (a, b) => a.value.rate <= b.value.rate ? a : b,
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(deck.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deck.commander,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Jugador: ${owner?.name ?? "Sin jugador"}'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$_wins victorias • $_losses derrotas\n'
                          '${_deckMatches.length} partidas jugadas',
                        ),
                      ),
                      Text(
                        '${_winRate.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          if (best != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.thumb_up, color: Colors.green),
                title: const Text('Mejor matchup'),
                subtitle: Text(
                  '${findDeckById(decks, best.key)?.name ?? "Desconocido"} '
                  '(${best.value.rate.toStringAsFixed(0)}% de victorias)',
                ),
              ),
            ),

          if (worst != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.thumb_down, color: Colors.redAccent),
                title: const Text('Peor matchup'),
                subtitle: Text(
                  '${findDeckById(decks, worst.key)?.name ?? "Desconocido"} '
                  '(${worst.value.rate.toStringAsFixed(0)}% de victorias)',
                ),
              ),
            ),

          if (_currentStreak >= 2)
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.local_fire_department,
                  color: Colors.orange,
                ),
                title: const Text('Racha actual'),
                subtitle: Text('$_currentStreak victorias seguidas'),
              ),
            ),

          if (_bestStreak >= 2)
            Card(
              child: ListTile(
                leading: const Icon(Icons.emoji_events, color: Colors.amber),
                title: const Text('Racha récord'),
                subtitle: Text('$_bestStreak victorias seguidas'),
              ),
            ),

          const SizedBox(height: 16),

          const Text(
            '📈 Evolución del win rate',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
              child: WinRateChart(values: _cumulativeWinRates),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            '⚔️ Matchups contra mazos rivales',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          if (matchups.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Todavía no hay partidas registradas.'),
            ),

          ...matchups.map((entry) {
            final oppDeck = findDeckById(decks, entry.key);
            final stat = entry.value;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(oppDeck?.name ?? 'Mazo desconocido'),
                subtitle: Text('${stat.wins}W / ${stat.losses}L'),
                trailing: Text(
                  '${stat.rate.toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
