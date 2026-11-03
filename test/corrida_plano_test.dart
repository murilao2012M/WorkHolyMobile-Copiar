import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/corrida/plano_corrida.dart';

void main() {
  test('plano soma exatamente a duração pedida e abre/fecha com caminhada', () {
    for (final nivel in ['Iniciante', 'Intermediário', 'Avançado']) {
      for (final min in [15, 20, 30, 45, 60, 90]) {
        final p = PlanoCorrida.gerar(experiencia: nivel, minutos: min);
        expect(p.duracaoTotal, min * 60, reason: '$nivel $min');
        expect(p.blocos.first.tipo, TipoBlocoCorrida.aquecimento);
        expect(p.blocos.last.tipo, TipoBlocoCorrida.desaquecimento);
        expect(p.blocos.every((b) => b.segundos > 0), isTrue);
      }
    }
  });

  test('duração fora dos limites é ajustada', () {
    expect(
      PlanoCorrida.gerar(experiencia: 'Iniciante', minutos: 1).duracaoTotal,
      15 * 60,
    );
    expect(
      PlanoCorrida.gerar(experiencia: 'Iniciante', minutos: 500).duracaoTotal,
      90 * 60,
    );
  });

  test('iniciante corre mais a cada semana do ciclo', () {
    int corrida(int semana) =>
        PlanoCorrida.gerar(
              experiencia: 'Iniciante',
              minutos: 30,
              semanaCiclo: semana,
            ).blocos
            .where((b) => b.tipo == TipoBlocoCorrida.corrida)
            .fold(0, (t, b) => t + b.segundos);
    expect(corrida(2), greaterThan(corrida(1)));
    expect(corrida(4), greaterThan(corrida(3)));
  });

  test('posição acompanha o tempo e muda de bloco', () {
    final p = PlanoCorrida.gerar(experiencia: 'Iniciante', minutos: 30);
    expect(p.posicao(0).bloco.tipo, TipoBlocoCorrida.aquecimento);
    expect(p.posicao(0).restanteNoBloco, 300);
    final depois = p.posicao(300);
    expect(depois.bloco.tipo, TipoBlocoCorrida.corrida);
    expect(depois.indice, 1);
    expect(p.posicao(-5).indice, 0);
  });

  test('após o fim o plano está concluído', () {
    final p = PlanoCorrida.gerar(experiencia: 'Avançado', minutos: 20);
    final fim = p.posicao(p.duracaoTotal + 10);
    expect(fim.concluido, isTrue);
    expect(fim.restanteTotal, 0);
    expect(p.proximoBloco(p.blocos.length - 1), isNull);
  });
}
