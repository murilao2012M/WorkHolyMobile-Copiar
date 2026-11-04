import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/alunos/aluno.dart';
import 'package:workholy_mobile/main.dart';

void main() {
  test('aluno preserva dados ao serializar', () {
    final aluno = Aluno(nome: 'Maria', telefone: '1199', objetivo: 'Emagrecer');
    final volta = Aluno.fromJson(aluno.toJson());
    expect(volta.id, aluno.id);
    expect(volta.nome, 'Maria');
    expect(volta.objetivo, 'Emagrecer');
    expect(volta.criadoEm, aluno.criadoEm);
  });

  test('treino guarda o aluno e treinos antigos continuam sem aluno', () {
    final treino = Treino(nome: 'A', objetivo: '', alunoId: 'aluno_1');
    expect(Treino.fromJson(treino.toJson()).alunoId, 'aluno_1');
    expect(Treino.fromJson({'id': 't', 'nome': 'B'}).alunoId, isNull);
    expect(Treino(nome: 'C', objetivo: '').toJson().containsKey('alunoId'),
        isFalse);
  });
}
