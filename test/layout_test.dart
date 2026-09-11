import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:under_fummander_tracker/ui/layout.dart';

void main() {
  // Ancho de la ventana durante la prueba. tester.view espera píxeles
  // físicos, y con devicePixelRatio en 1 coinciden con los lógicos.
  Future<void> setWindowWidth(WidgetTester tester, double width) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 800);

    addTearDown(tester.view.reset);
  }

  // Mide el ancho real que terminó teniendo el hijo de CenteredContent.
  Future<double> widthOfChild(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CenteredContent(
          child: SizedBox.expand(child: Placeholder()),
        ),
      ),
    );

    return tester.getSize(find.byType(Placeholder)).width;
  }

  group('CenteredContent', () {
    testWidgets('en un monitor ancho corta el contenido', (tester) async {
      await setWindowWidth(tester, 1920);

      expect(await widthOfChild(tester), maxContentWidth);
    });

    testWidgets('en un teléfono ocupa todo el ancho', (tester) async {
      await setWindowWidth(tester, 411);

      // Lo importante: en el teléfono no cambia nada respecto de antes.
      expect(await widthOfChild(tester), 411);
    });

    testWidgets('justo en el límite no recorta', (tester) async {
      await setWindowWidth(tester, maxContentWidth);

      expect(await widthOfChild(tester), maxContentWidth);
    });
  });

  group('AppScaffold', () {
    testWidgets('centra el cuerpo pero no la AppBar', (tester) async {
      await setWindowWidth(tester, 1920);

      await tester.pumpWidget(
        MaterialApp(
          home: AppScaffold(
            appBar: AppBar(title: const Text('Título')),
            body: const SizedBox.expand(child: Placeholder()),
          ),
        ),
      );

      // El cuerpo se acota...
      expect(tester.getSize(find.byType(Placeholder)).width, maxContentWidth);

      // ...pero la barra sigue ocupando la ventana entera, que es lo que
      // hace que se vea como una página y no como un teléfono flotando.
      expect(tester.getSize(find.byType(AppBar)).width, 1920);
    });
  });
}
