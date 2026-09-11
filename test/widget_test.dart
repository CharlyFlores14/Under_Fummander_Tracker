import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:under_fummander_tracker/main.dart';
import 'package:under_fummander_tracker/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Lo que se está probando acá es que la app arranca entera sin ningún
  // proyecto de Firebase configurado: la sincronización es opcional y
  // nada del árbol de widgets puede tocar Firebase al construirse.
  testWidgets('La aplicación inicia correctamente', (tester) async {
    await tester.pumpWidget(const UnderFummanderTracker());
    await tester.pumpAndSettle();

    expect(find.text('⚔️ Under Fummander Tracker'), findsOneWidget);
    expect(find.text('Nueva partida'), findsOneWidget);
  });

  testWidgets('Sin configurar, arranca en modo local', (tester) async {
    await tester.pumpWidget(const UnderFummanderTracker());
    await tester.pumpAndSettle();

    expect(
      find.byTooltip('Sincronización (solo en este teléfono)'),
      findsOneWidget,
    );
  });

  testWidgets('Levanta los datos guardados en el teléfono', (tester) async {
    SharedPreferences.setMockInitialValues({
      'uft_players': jsonEncode([
        Player(id: 'p1', name: 'Gerico').toJson(),
        Player(id: 'p2', name: 'Fummander').toJson(),
      ]),
    });

    await tester.pumpWidget(const UnderFummanderTracker());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jugadores'));
    await tester.pumpAndSettle();

    expect(find.text('Gerico'), findsOneWidget);
    expect(find.text('Fummander'), findsOneWidget);
  });
}
