import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/corrida/corrida_calorias.dart';

void main() {
  test('corrida a 10 km/h com 70 kg gasta cerca de 12,9 kcal/min', () {
    final kcal = CaloriasCorrida.trecho(
      velocidadeMetrosPorSegundo: 10000 / 3600,
      intervaloSegundos: 60,
      pesoKg: 70,
    );
    expect(kcal, closeTo(12.9, 0.1));
  });

  test('caminhada gasta menos que corrida e a transição é contínua', () {
    expect(CaloriasCorrida.vo2(80), closeTo(11.5, 0.01));
    expect(CaloriasCorrida.vo2(134), closeTo(30.3, 0.01));
    expect(CaloriasCorrida.vo2(117), greaterThan(CaloriasCorrida.vo2(100)));
    expect(CaloriasCorrida.vo2(117), lessThan(CaloriasCorrida.vo2(134)));
  });

  test('entradas inválidas retornam zero', () {
    expect(
      CaloriasCorrida.trecho(
        velocidadeMetrosPorSegundo: 3,
        intervaloSegundos: 10,
        pesoKg: 0,
      ),
      0,
    );
  });
}
