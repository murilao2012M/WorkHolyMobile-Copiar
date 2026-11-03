import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/onboarding/perfil_onboarding.dart';

void main() {
  final agora = DateTime(2026, 11, 3);

  Map<String, dynamic> perfilValido() => {
    'nome': 'Murilo',
    'peso': '70,5',
    'altura': '175',
    'nascimento': DateTime(1995, 5, 10).toIso8601String(),
    'objetivo': 'Hipertrofia',
  };

  test('perfil completo é aceito', () {
    expect(PerfilOnboarding.perfilCompleto(perfilValido(), agora: agora), true);
  });

  test('perfil ausente ou com campo faltando é incompleto', () {
    expect(PerfilOnboarding.perfilCompleto(null, agora: agora), false);
    for (final campo in ['nome', 'peso', 'altura', 'nascimento', 'objetivo']) {
      final perfil = perfilValido()..remove(campo);
      expect(
        PerfilOnboarding.perfilCompleto(perfil, agora: agora),
        false,
        reason: campo,
      );
    }
  });

  test('valores fora do limite são recusados', () {
    expect(PerfilOnboarding.validarPeso('5'), isNotNull);
    expect(PerfilOnboarding.validarPeso('abc'), isNotNull);
    expect(PerfilOnboarding.validarPeso('72,3'), isNull);
    expect(PerfilOnboarding.validarAltura('90'), isNotNull);
    expect(PerfilOnboarding.validarAltura('180'), isNull);
    expect(PerfilOnboarding.validarNome(' '), isNotNull);
  });

  test('idade calculada respeita o aniversário', () {
    expect(
      PerfilOnboarding.idadeEm(DateTime(2000, 12, 1), DateTime(2026, 11, 3)),
      25,
    );
    expect(
      PerfilOnboarding.validarNascimento(DateTime(2024, 1, 1), agora: agora),
      isNotNull,
    );
    expect(
      PerfilOnboarding.validarNascimento(DateTime(1990, 1, 1), agora: agora),
      isNull,
    );
  });
}
