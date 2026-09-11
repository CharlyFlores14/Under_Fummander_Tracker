import 'dart:math';

// ============================================================
// CÓDIGOS DE INVITACIÓN
// ============================================================

// Vive aparte de group_service.dart para poder testearlo sin arrastrar
// Firebase: acá no hay ninguna dependencia de plugins.

// Alfabeto sin los caracteres que se confunden al dictarlos en voz alta
// o al pasarlos por mensaje: sin O/0 ni I/1.
const String joinCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

const int joinCodeLength = 6;

final Random _secureRandom = Random.secure();

// 32^6 ≈ mil millones de combinaciones. Las colisiones son rarísimas y
// cuando pasan el servidor rechaza el alta y se sortea otro código.
String generateJoinCode([Random? random]) {
  final rnd = random ?? _secureRandom;

  return List.generate(
    joinCodeLength,
    (_) => joinCodeAlphabet[rnd.nextInt(joinCodeAlphabet.length)],
  ).join();
}

// Lo que escribe la persona viene con espacios de más y en minúscula
// tan seguido como no.
String normalizeJoinCode(String raw) => raw.trim().toUpperCase();

bool isValidJoinCode(String code) {
  if (code.length != joinCodeLength) return false;

  for (final char in code.split('')) {
    if (!joinCodeAlphabet.contains(char)) return false;
  }

  return true;
}
