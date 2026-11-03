import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/passos/passos_do_dia.dart';

void main() {
  final segunda = DateTime(2026, 11, 2, 9);
  final terca = DateTime(2026, 11, 3, 9);

  test('primeira leitura do dia vira a base', () {
    final r = calcularPassosDoDia(
      leituraSensor: 5000,
      agora: segunda,
      referencia: null,
    );
    expect(r.passos, 0);
    expect(r.referencia.base, 5000);
  });

  test('passos do dia = leitura menos a base', () {
    final ref = ReferenciaPassos(dia: chaveDia(segunda), base: 5000);
    final r = calcularPassosDoDia(
      leituraSensor: 5750,
      agora: segunda,
      referencia: ref,
    );
    expect(r.passos, 750);
  });

  test('novo dia zera a base', () {
    final ref = ReferenciaPassos(dia: chaveDia(segunda), base: 5000);
    final r = calcularPassosDoDia(
      leituraSensor: 9000,
      agora: terca,
      referencia: ref,
    );
    expect(r.passos, 0);
    expect(r.referencia.dia, chaveDia(terca));
  });

  test('reinício do aparelho recomeça do zero do sensor', () {
    final ref = ReferenciaPassos(dia: chaveDia(segunda), base: 5000);
    final r = calcularPassosDoDia(
      leituraSensor: 120,
      agora: segunda,
      referencia: ref,
    );
    expect(r.passos, 120);
    expect(r.referencia.base, 0);
  });
}
