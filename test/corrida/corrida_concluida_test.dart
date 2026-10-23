import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/corrida/corrida_banco.dart';

void main() {
  test('converte uma corrida finalizada do banco para o painel', () {
    final corrida = CorridaConcluida.fromRegistro({
      'id': 'corrida-1',
      'inicio_ms': DateTime(2026, 10, 20, 6, 30).millisecondsSinceEpoch,
      'fim_ms': DateTime(2026, 10, 20, 7, 15).millisecondsSinceEpoch,
      'duracao_segundos': 2700,
      'distancia_metros': 6500.5,
    });

    expect(corrida.id, 'corrida-1');
    expect(corrida.inicio, DateTime(2026, 10, 20, 6, 30));
    expect(corrida.fim, DateTime(2026, 10, 20, 7, 15));
    expect(corrida.duracaoSegundos, 2700);
    expect(corrida.distanciaMetros, 6500.5);
  });

  test('usa o início quando a corrida finalizada não tem fim salvo', () {
    final inicio = DateTime(2026, 10, 20, 6, 30);
    final corrida = CorridaConcluida.fromRegistro({
      'id': 'corrida-antiga',
      'inicio_ms': inicio.millisecondsSinceEpoch,
    });

    expect(corrida.fim, inicio);
    expect(corrida.duracaoSegundos, 0);
    expect(corrida.distanciaMetros, 0);
  });
}
