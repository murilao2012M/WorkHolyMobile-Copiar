import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workholy_mobile/alunos/alunos_modelos.dart';
import 'package:workholy_mobile/dados/workholy_banco.dart';

void main() {
  late Directory diretorioTemporario;
  late WorkHolyBanco banco;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    diretorioTemporario = await Directory.systemTemp.createTemp(
      'workholy_alunos_test_',
    );
    banco = WorkHolyBanco.paraTestes(
      caminho: p.join(diretorioTemporario.path, 'alunos.db'),
    );
  });

  tearDown(() async {
    await banco.fechar();
    if (await diretorioTemporario.exists()) {
      await diretorioTemporario.delete(recursive: true);
    }
  });

  test('salva, atualiza e lista aluno e anotação privada', () async {
    final aluno = Aluno(
      id: 'aluno-1',
      nome: 'Ana Silva',
      telefone: '11999990000',
      email: 'ana@example.com',
      inicio: DateTime(2026, 1, 10),
      status: 'ativo',
      objetivo: 'Força',
      nivel: 'Iniciante',
      disponibilidade: 'Segunda e quarta',
      preferencias: 'Halteres',
      observacoes: '',
      treinoIds: const ['treino-a'],
    );
    await banco.salvarAluno(aluno);
    await banco.salvarAnotacaoAluno(
      AnotacaoAluno(
        id: 'nota-1',
        alunoId: aluno.id,
        texto: 'Revisar técnica do agachamento.',
        criadaEm: DateTime(2026, 1, 11),
      ),
    );

    final alunos = await banco.listarAlunos();
    expect(alunos.single.nome, 'Ana Silva');
    expect(alunos.single.treinoIds, ['treino-a']);
    expect(
      (await banco.listarAnotacoesAluno(aluno.id)).single.texto,
      'Revisar técnica do agachamento.',
    );

    await banco.salvarAluno(aluno.copiar(status: 'pausado'));
    expect((await banco.listarAlunos()).single.status, 'pausado');
  });

  test(
    'excluir aluno remove notas e desvincula histórico preservado',
    () async {
      final inicio = DateTime(2026, 1, 10);
      await banco.salvarAluno(
        Aluno(
          id: 'aluno-2',
          nome: 'Bruno',
          telefone: '',
          email: '',
          inicio: inicio,
          status: 'ativo',
          objetivo: '',
          nivel: 'Iniciante',
          disponibilidade: '',
          preferencias: '',
          observacoes: '',
          treinoIds: const [],
        ),
      );
      await banco.salvarAnotacaoAluno(
        AnotacaoAluno(
          id: 'nota-2',
          alunoId: 'aluno-2',
          texto: 'Acompanhamento',
          criadaEm: inicio,
        ),
      );
      await banco.salvarDadosTreino(
        treinos: const [],
        exercicios: const [],
        itensTreino: const [],
        sessoesTreino: [
          {
            'id': 'sessao-aluno',
            'treinoId': 'treino-a',
            'nomeTreino': 'Treino A',
            'inicio': inicio.toIso8601String(),
            'fim': inicio.add(const Duration(hours: 1)).toIso8601String(),
            'series': const [],
            'anotacoes': '',
            'alunoId': 'aluno-2',
          },
        ],
      );

      await banco.excluirAluno('aluno-2');

      expect(await banco.listarAlunos(), isEmpty);
      expect(await banco.listarAnotacoesAluno('aluno-2'), isEmpty);
      final dados = await banco.carregarDadosTreino();
      expect(dados.sessoesTreino.single['alunoId'], isNull);
    },
  );
}
