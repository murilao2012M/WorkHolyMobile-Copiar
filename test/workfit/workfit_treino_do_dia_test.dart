import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/workfit/workfit_ciclo.dart';
import 'package:workholy_mobile/workfit/workfit_treino_do_dia.dart';

void main() {
  final agora = DateTime(2026, 3, 10, 9);
  final ciclo = WorkFitCiclo(
    id: 'c1',
    inicio: DateTime(2026, 3, 9),
    diasPorSemana: 2,
    modalidade: 'musculacao',
  );
  CandidatoTreinoDia treino(String id, {WorkFitCiclo? c, int n = 3}) =>
      CandidatoTreinoDia(
        id: id,
        nome: 'Treino $id',
        quantidadeExercicios: n,
        ciclo: c,
      );
  SessaoTreinoDia sessao(
    String id,
    String treinoId,
    DateTime fim, {
    bool aberta = false,
    String? plano,
  }) => SessaoTreinoDia(
    id: id,
    treinoId: treinoId,
    inicio: fim.subtract(const Duration(hours: 1)),
    fim: aberta ? null : fim,
    planoId: plano,
  );

  test('sem treinos elegíveis', () {
    final r = escolherTreinoDoDia(
      treinos: [treino('a', n: 0)],
      sessoes: const [],
      agora: agora,
    );
    expect(r.situacao, SituacaoTreinoDia.semTreino);
    expect(r.podeAbrirExecucao, isFalse);
  });

  test('treino de corrida não entra na escolha de musculação', () {
    final corrida = WorkFitCiclo(
      id: 'r',
      inicio: agora,
      diasPorSemana: 3,
      modalidade: 'corrida',
    );
    final r = escolherTreinoDoDia(
      treinos: [treino('a', c: corrida)],
      sessoes: const [],
      agora: agora,
    );
    expect(r.situacao, SituacaoTreinoDia.semTreino);
  });

  test('rodízio: nunca feito primeiro, depois o mais antigo', () {
    final r1 = escolherTreinoDoDia(
      treinos: [treino('a'), treino('b')],
      sessoes: [sessao('s1', 'a', DateTime(2026, 3, 5))],
      agora: agora,
    );
    expect(r1.treino!.id, 'b');
    final r2 = escolherTreinoDoDia(
      treinos: [treino('a'), treino('b')],
      sessoes: [
        sessao('s1', 'a', DateTime(2026, 3, 5)),
        sessao('s2', 'b', DateTime(2026, 3, 7)),
      ],
      agora: agora,
    );
    expect(r2.treino!.id, 'a');
    expect(r2.situacao, SituacaoTreinoDia.iniciar);
  });

  test('sessão aberta é retomada', () {
    final r = escolherTreinoDoDia(
      treinos: [treino('a'), treino('b')],
      sessoes: [sessao('s1', 'b', agora, aberta: true)],
      agora: agora,
    );
    expect(r.situacao, SituacaoTreinoDia.retomar);
    expect(r.treino!.id, 'b');
    expect(r.podeAbrirExecucao, isTrue);
  });

  test('treino concluído hoje não manda treinar de novo', () {
    final r = escolherTreinoDoDia(
      treinos: [treino('a'), treino('b')],
      sessoes: [sessao('s1', 'a', DateTime(2026, 3, 10, 7))],
      agora: agora,
    );
    expect(r.situacao, SituacaoTreinoDia.concluidoHoje);
    expect(r.podeAbrirExecucao, isFalse);
  });

  test('meta semanal cumprida vira descanso e só conta o mesmo plano', () {
    final cumprida = escolherTreinoDoDia(
      treinos: [
        treino('a', c: ciclo),
        treino('b', c: ciclo),
      ],
      sessoes: [
        sessao('s1', 'a', DateTime(2026, 3, 9, 8), plano: 'c1'),
        sessao('s2', 'b', DateTime(2026, 3, 10, 18), plano: 'c1'),
      ],
      agora: DateTime(2026, 3, 11, 9),
    );
    expect(cumprida.situacao, SituacaoTreinoDia.descanso);
    expect(cumprida.podeAbrirExecucao, isFalse);

    final outroPlano = escolherTreinoDoDia(
      treinos: [
        treino('a', c: ciclo),
        treino('b', c: ciclo),
      ],
      sessoes: [
        sessao('s1', 'a', DateTime(2026, 3, 9, 8), plano: 'outro'),
        sessao('s2', 'b', DateTime(2026, 3, 10, 18), plano: 'outro'),
      ],
      agora: DateTime(2026, 3, 11, 9),
    );
    expect(outroPlano.situacao, SituacaoTreinoDia.iniciar);
  });

  test('frase da fase explica o que muda', () {
    final r = escolherTreinoDoDia(
      treinos: [treino('a', c: ciclo)],
      sessoes: const [],
      agora: agora,
    );
    expect(r.fraseFase, contains('Semana 1 de 4'));
    expect(r.fraseFase, contains('Ainda não há progressão'));
  });
}
