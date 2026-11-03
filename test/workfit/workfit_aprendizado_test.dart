import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/workfit/workfit_aprendizado.dart';

SessaoAprendizado sessao(
  DateTime fim,
  Map<String, List<bool>> series, {
  int? rpe,
}) {
  return SessaoAprendizado(
    fim: fim,
    rpe: rpe,
    series: [
      for (final e in series.entries)
        for (final ok in e.value)
          SerieAprendizado(catalogoId: e.key, nome: e.key, concluida: ok),
    ],
  );
}

void main() {
  final agora = DateTime(2025, 6, 30);

  test('sem evidência não altera nada', () {
    final a = AprendizadoWorkFit.vazio;
    expect(a.bonus('x'), 0);
    expect(a.evitar('x'), isFalse);
    expect(a.insights(diasPlanejadosPorSemana: 4), isEmpty);
  });

  test('uma única sessão não gera bônus nem insights', () {
    final a = AprendizadoWorkFit.construir(
      sessoes: [
        sessao(agora, {
          'x': [false, false, false],
        }),
      ],
      agora: agora,
    );
    expect(a.bonus('x'), 0);
    expect(a.evitar('x'), isFalse);
    expect(a.insights(), isEmpty);
  });

  test('duas remoções fazem evitar o exercício', () {
    final a = AprendizadoWorkFit.construir(
      sessoes: const [],
      remocoes: [
        RemocaoAprendizado(catalogoId: 'x', em: agora),
        RemocaoAprendizado(catalogoId: 'x', em: agora),
      ],
      agora: agora,
    );
    expect(a.evitar('x'), isTrue);
    expect(a.bonus('x'), lessThan(0));
  });

  test('baixa conclusão penaliza e alta conclusão favorece', () {
    final sessoes = [
      for (var i = 0; i < 4; i++)
        sessao(agora.subtract(Duration(days: i * 2)), {
          'ruim': [false, false, false],
          'bom': [true, true, true],
        }),
    ];
    final a = AprendizadoWorkFit.construir(sessoes: sessoes, agora: agora);
    expect(a.evitar('ruim'), isTrue);
    expect(a.bonus('ruim'), lessThan(0));
    expect(a.bonus('bom'), greaterThan(0));
    expect(a.evitar('bom'), isFalse);
  });

  test('insights de frequência, esforço e exercício incompleto', () {
    final sessoes = [
      for (var i = 0; i < 4; i++)
        sessao(agora.subtract(Duration(days: i * 7)), {
          'ruim': [false, false],
        }, rpe: 9),
    ];
    final a = AprendizadoWorkFit.construir(sessoes: sessoes, agora: agora);
    final titulos = a
        .insights(diasPlanejadosPorSemana: 5)
        .map((i) => i.titulo)
        .join('|');
    expect(titulos, contains('Frequência abaixo do plano'));
    expect(titulos, contains('Esforço alto'));
    expect(titulos, contains('incompleto'));
  });
}
