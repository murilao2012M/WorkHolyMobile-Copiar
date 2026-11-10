import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/corrida/plano_corrida.dart';
import 'package:workholy_mobile/voz/mensagens_voz.dart';
import 'package:workholy_mobile/voz/voz_treinador.dart';

void main() {
  test('quilômetro ignora ritmo implausível', () {
    expect(MensagensVoz.quilometro(1), '1 quilômetro.');
    expect(MensagensVoz.quilometro(2, ritmoSegundosPorKm: 5), '2 quilômetros.');
    expect(MensagensVoz.quilometro(2, ritmoSegundosPorKm: 330), contains('5'));
  });

  test('descanso e exercício falam números em português', () {
    expect(MensagensVoz.descansoIniciado(90), contains('1 minuto'));
    expect(MensagensVoz.descansoIniciado(90), contains('30 segundos'));
    final frase = MensagensVoz.exercicioAtual(
      nome: 'Supino reto',
      serie: 2,
      totalSeries: 3,
      repeticoes: 10,
      cargaKg: 22.5,
    );
    expect(frase, contains('Supino reto'));
    expect(frase, contains('22,5'));
  });

  test('blocos de corrida têm frase', () {
    final plano = PlanoCorrida.gerar(experiencia: 'Iniciante', minutos: 30);
    for (final b in plano.blocos) {
      expect(MensagensVoz.inicioDeBloco(b), isNotEmpty);
    }
  });

  test('VozTreinador respeita o interruptor e evita repetição', () async {
    final faladas = <String>[];
    VozTreinador.falarSubstituto = (t) async => faladas.add(t);
    final voz = VozTreinador.instancia;
    await voz.definirAtiva(false).catchError((_) {});
    await voz.falar('a');
    expect(faladas, isEmpty);
    await voz.definirAtiva(true).catchError((_) {});
    await voz.falar('b');
    await voz.falar('b');
    expect(faladas, ['b']);
    VozTreinador.falarSubstituto = null;
  });
}
