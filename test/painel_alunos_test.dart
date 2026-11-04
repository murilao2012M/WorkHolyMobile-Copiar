import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/alunos/painel_alunos.dart';

SessaoPainelAluno sessao(String? aluno, DateTime inicio) => SessaoPainelAluno(
  alunoId: aluno,
  nomeTreino: 'Treino A',
  inicio: inicio,
  seriesConcluidas: 3,
);

void main() {
  // Quarta-feira.
  final agora = DateTime(2026, 11, 4, 12);

  test('separa por aluno, na ordem dos alunos', () {
    final r = resumirPainelPorAluno(
      ['a', 'b'],
      [
        sessao('b', DateTime(2026, 11, 4, 8)),
        sessao('a', DateTime(2026, 11, 2, 8)),
        sessao('a', DateTime(2026, 10, 20, 8)),
      ],
      agora,
    );
    expect(r.map((e) => e.alunoId), ['a', 'b']);
    expect(r[0].concluidos, 2);
    expect(r[0].naSemana, 1);
    expect(r[0].hoje, isEmpty);
    expect(r[1].hoje.length, 1);
  });

  test('sessão de aluno removido ou sem aluno vai para o grupo sem aluno', () {
    final r = resumirPainelPorAluno(
      ['a'],
      [sessao(null, agora), sessao('x', agora)],
      agora,
    );
    expect(r.last.alunoId, isNull);
    expect(r.last.concluidos, 2);
  });

  test('aluno sem treinos aparece zerado', () {
    final r = resumirPainelPorAluno(['a'], [], agora);
    expect(r.single.concluidos, 0);
    expect(r.single.ultima, isNull);
  });
}
