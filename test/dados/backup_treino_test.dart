import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workholy_mobile/alunos/alunos_modelos.dart';
import 'package:workholy_mobile/corrida/corrida_banco.dart';
import 'package:workholy_mobile/dados/backup_treino.dart';
import 'package:workholy_mobile/dados/workholy_banco.dart';

void main() {
  late Directory diretorioTemporario;
  late WorkHolyBanco bancoTreinoOrigem;
  late WorkHolyBanco bancoTreinoDestino;
  late CorridaBanco bancoCorridaOrigem;
  late CorridaBanco bancoCorridaDestino;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    diretorioTemporario = await Directory.systemTemp.createTemp(
      'workholy_backup_test_',
    );
    bancoTreinoOrigem = WorkHolyBanco.paraTestes(
      caminho: p.join(diretorioTemporario.path, 'origem_treino.db'),
    );
    bancoTreinoDestino = WorkHolyBanco.paraTestes(
      caminho: p.join(diretorioTemporario.path, 'destino_treino.db'),
    );
    bancoCorridaOrigem = CorridaBanco.paraTestes(
      caminho: p.join(diretorioTemporario.path, 'origem_corrida.db'),
    );
    bancoCorridaDestino = CorridaBanco.paraTestes(
      caminho: p.join(diretorioTemporario.path, 'destino_corrida.db'),
    );
  });

  tearDown(() async {
    await bancoTreinoOrigem.fechar();
    await bancoTreinoDestino.fechar();
    await bancoCorridaOrigem.fechar();
    await bancoCorridaDestino.fechar();
    if (await diretorioTemporario.exists()) {
      await diretorioTemporario.delete(recursive: true);
    }
  });

  test('recusa JSON que não seja um backup Moveria', () async {
    await expectLater(
      BackupTreino.importar('{"formato":"outro","versao":1}'),
      throwsFormatException,
    );
  });

  test('recusa coleções ausentes sem gravar dados', () async {
    await expectLater(
      BackupTreino.importar(
        '{"formato":"workholy_training_backup","versao":2,"dados":{}}',
      ),
      throwsFormatException,
    );
  });

  test('backup v2 preserva cadastros de alunos existentes', () async {
    final inicio = DateTime(2026, 11, 7, 9);
    await bancoTreinoDestino.salvarAluno(
      Aluno(
        id: 'aluna-atual',
        nome: 'Ana',
        telefone: '',
        email: '',
        inicio: inicio,
        status: 'ativo',
        objetivo: '',
        nivel: '',
        disponibilidade: '',
        preferencias: '',
        observacoes: '',
        treinoIds: const [],
      ),
    );
    await bancoTreinoDestino.salvarAnotacaoAluno(
      AnotacaoAluno(
        id: 'nota-atual',
        alunoId: 'aluna-atual',
        texto: 'Manter após restaurar backup antigo.',
        criadaEm: inicio,
      ),
    );

    final backupV2 = jsonEncode({
      'formato': 'workholy_training_backup',
      'versao': 2,
      'dados': {
        'treinos': [],
        'exercicios': [],
        'itensTreino': [],
        'sessoesTreino': [],
        'corridas': [],
      },
    });
    await BackupTreino.importar(
      backupV2,
      bancoTreino: bancoTreinoDestino,
      bancoCorrida: bancoCorridaDestino,
    );

    expect((await bancoTreinoDestino.listarAlunos()).single.nome, 'Ana');
    expect(
      (await bancoTreinoDestino.listarAnotacoesAluno('aluna-atual'))
          .single
          .texto,
      'Manter após restaurar backup antigo.',
    );
  });

  test('exporta e restaura dados mantendo corridas em andamento', () async {
    await bancoTreinoOrigem.salvarDadosTreino(
      treinos: [
        {
          'id': 'treino-origem',
          'nome': 'Treino A',
          'objetivo': 'Força',
          'grupo': 'A',
          'favorito': true,
          'diasSemana': [1, 3],
          'anotacoes': 'Controlar o ritmo.',
        },
      ],
      exercicios: [
        {'id': 'exercicio-origem', 'nome': 'Agachamento', 'grupo': 'Pernas'},
      ],
      itensTreino: [
        {
          'id': 'item-origem',
          'treinoId': 'treino-origem',
          'exercicioId': 'exercicio-origem',
          'series': 3,
          'repeticoes': 8,
          'cargaKg': 40.0,
          'descansoSegundos': 90,
          'pesoCorporal': false,
          'instrucoes': 'Controlar a descida.',
          'metaCargaKg': 45.0,
          'metaRepeticoes': 10,
        },
      ],
      sessoesTreino: [
        {
          'id': 'sessao-origem',
          'treinoId': 'treino-origem',
          'nomeTreino': 'Treino A',
          'inicio': '2026-11-07T09:00:00.000',
          'fim': '2026-11-07T10:00:00.000',
          'series': [],
          'anotacoes': 'Retomar com cuidado',
        },
      ],
    );
    await bancoCorridaOrigem.criar('corrida-origem', 1000);
    await bancoCorridaOrigem.atualizar(
      id: 'corrida-origem',
      duracaoSegundos: 120,
      distanciaMetros: 900,
      estado: 'finalizada',
      rota: const [],
      fimMs: 121000,
    );

    await bancoTreinoDestino.salvarDadosTreino(
      treinos: [
        {'id': 'treino-antigo', 'nome': 'Antigo', 'objetivo': ''},
      ],
      exercicios: const [],
      itensTreino: const [],
      sessoesTreino: const [],
    );
    await bancoCorridaDestino.criar('corrida-ativa', 2000);
    await bancoCorridaDestino.criar('corrida-antiga', 3000);
    await bancoCorridaDestino.atualizar(
      id: 'corrida-antiga',
      duracaoSegundos: 60,
      distanciaMetros: 300,
      estado: 'finalizada',
      rota: const [],
      fimMs: 63000,
    );

    final backup = await BackupTreino.exportar(
      bancoTreino: bancoTreinoOrigem,
      bancoCorrida: bancoCorridaOrigem,
    );
    await BackupTreino.importar(
      backup,
      bancoTreino: bancoTreinoDestino,
      bancoCorrida: bancoCorridaDestino,
    );

    final dadosRestaurados = await bancoTreinoDestino.carregarDadosTreino();
    expect(dadosRestaurados.treinos.single['id'], 'treino-origem');
    expect(dadosRestaurados.exercicios.single['id'], 'exercicio-origem');
    expect(dadosRestaurados.itensTreino.single['pesoCorporal'], false);
    expect(dadosRestaurados.treinos.single['grupo'], 'A');
    expect(dadosRestaurados.treinos.single['favorito'], true);
    expect(dadosRestaurados.treinos.single['diasSemana'], [1, 3]);
    expect(dadosRestaurados.treinos.single['anotacoes'], 'Controlar o ritmo.');
    expect(
      dadosRestaurados.itensTreino.single['instrucoes'],
      'Controlar a descida.',
    );
    expect(dadosRestaurados.itensTreino.single['metaCargaKg'], 45.0);
    expect(dadosRestaurados.itensTreino.single['metaRepeticoes'], 10);
    expect(
      dadosRestaurados.sessoesTreino.single['anotacoes'],
      'Retomar com cuidado',
    );

    final corridas = await bancoCorridaDestino.listar();
    expect(
      corridas.map((corrida) => corrida['id']),
      containsAll(['corrida-ativa', 'corrida-origem']),
    );
    expect(
      corridas.map((corrida) => corrida['id']),
      isNot(contains('corrida-antiga')),
    );

    final dadosBackup = jsonDecode(backup) as Map<String, dynamic>;
    expect(dadosBackup['versao'], 3);
  });

  test('exporta e restaura cadastro e anotações de alunos', () async {
    final inicio = DateTime(2026, 11, 7, 9);
    await bancoTreinoOrigem.salvarAluno(
      Aluno(
        id: 'aluna-1',
        nome: 'Ana',
        telefone: '11999990000',
        email: 'ana@example.com',
        inicio: inicio,
        status: 'ativo',
        objetivo: 'Força',
        nivel: 'Intermediário',
        disponibilidade: 'Segunda e quarta',
        preferencias: 'Halteres',
        observacoes: 'Cadastro',
        treinoIds: const [],
      ),
    );
    await bancoTreinoOrigem.salvarAnotacaoAluno(
      AnotacaoAluno(
        id: 'nota-1',
        alunoId: 'aluna-1',
        texto: 'Anotação privada.',
        criadaEm: inicio,
      ),
    );

    final backup = await BackupTreino.exportar(
      bancoTreino: bancoTreinoOrigem,
      bancoCorrida: bancoCorridaOrigem,
    );
    await BackupTreino.importar(
      backup,
      bancoTreino: bancoTreinoDestino,
      bancoCorrida: bancoCorridaDestino,
    );

    expect((await bancoTreinoDestino.listarAlunos()).single.nome, 'Ana');
    expect(
      (await bancoTreinoDestino.listarAnotacoesAluno('aluna-1')).single.texto,
      'Anotação privada.',
    );
  });
}
