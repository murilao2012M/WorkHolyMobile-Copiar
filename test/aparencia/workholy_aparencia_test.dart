import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/aparencia/workholy_aparencia.dart';

double _contraste(Color primeiro, Color segundo) {
  final luminanciaPrimeiro = primeiro.computeLuminance();
  final luminanciaSegundo = segundo.computeLuminance();
  final clara = luminanciaPrimeiro > luminanciaSegundo
      ? luminanciaPrimeiro
      : luminanciaSegundo;
  final escura = luminanciaPrimeiro > luminanciaSegundo
      ? luminanciaSegundo
      : luminanciaPrimeiro;

  return (clara + 0.05) / (escura + 0.05);
}

void main() {
  group('WorkHolyAparencia', () {
    final aparencia = WorkHolyAparencia();

    for (final brilho in Brightness.values) {
      test('mantém contraste legível no tema ${brilho.name}', () {
        final tema = aparencia.criarTema(brilho);
        final cores = tema.colorScheme;

        expect(
          _contraste(cores.onSurface, cores.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contraste(cores.onSurfaceVariant, cores.surfaceContainerLow),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contraste(cores.onPrimary, cores.primary),
          greaterThanOrEqualTo(4.5),
        );
      });
    }

    tearDownAll(aparencia.dispose);
  });
}
