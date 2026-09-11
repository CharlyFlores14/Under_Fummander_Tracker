import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:under_fummander_tracker/sync/join_code.dart';

void main() {
  group('generateJoinCode', () {
    test('usa el largo y el alfabeto acordados', () {
      for (int i = 0; i < 500; i++) {
        final code = generateJoinCode();

        expect(code.length, joinCodeLength);

        for (final char in code.split('')) {
          expect(joinCodeAlphabet, contains(char));
        }
      }
    });

    // El código se dicta en voz alta y se pasa por mensaje: O/0 e I/1
    // se confunden y mandarían a la gente a un grupo que no existe.
    test('nunca incluye caracteres confundibles', () {
      for (int i = 0; i < 500; i++) {
        expect(generateJoinCode(), isNot(matches(RegExp(r'[O0I1]'))));
      }
    });

    test('no devuelve siempre el mismo código', () {
      final codes = {for (int i = 0; i < 200; i++) generateJoinCode()};

      expect(codes.length, greaterThan(190));
    });

    test('acepta un Random inyectado para poder fijar el resultado', () {
      final a = generateJoinCode(Random(7));
      final b = generateJoinCode(Random(7));

      expect(a, b);
    });
  });

  group('normalizeJoinCode', () {
    test('recorta espacios y pasa a mayúsculas', () {
      expect(normalizeJoinCode('  a7k2qp \n'), 'A7K2QP');
    });

    test('deja intacto un código ya normalizado', () {
      expect(normalizeJoinCode('A7K2QP'), 'A7K2QP');
    });
  });

  group('isValidJoinCode', () {
    test('acepta cualquier código generado', () {
      for (int i = 0; i < 500; i++) {
        expect(isValidJoinCode(generateJoinCode()), isTrue);
      }
    });

    test('rechaza largos distintos', () {
      expect(isValidJoinCode(''), isFalse);
      expect(isValidJoinCode('A7K2Q'), isFalse);
      expect(isValidJoinCode('A7K2QPX'), isFalse);
    });

    test('rechaza caracteres fuera del alfabeto', () {
      expect(isValidJoinCode('A7K2Q0'), isFalse); // cero
      expect(isValidJoinCode('A7K2QI'), isFalse); // i mayúscula
      expect(isValidJoinCode('a7k2qp'), isFalse); // hay que normalizar antes
      expect(isValidJoinCode('A7K2Q-'), isFalse);
    });
  });
}
