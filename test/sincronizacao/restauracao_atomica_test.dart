import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workholy_mobile/corrida/corrida_banco.dart';
import 'package:workholy_mobile/dados/workholy_banco.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory diretorio;
  late WorkHolyBanco banco;
  late CorridaBanco corridas;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    diretorio = await Directory.systemTemp.createTemp('workholy_restore_');
    banco = WorkHolyBanco.paraTestes(
      caminho: p.join(diretorio.path, 'dados.db'),
    );
    corridas = CorridaBanco.paraTestes(
      caminho: p.join(diretorio.path, 'corridas.db'),
    );
    await banco.salvarDadosTreino(
      treinos: [
        {'id': 'treino-antigo', 'nome': 'Antigo'},
      ],
      exercicios: [
        {'id': 'ex-antigo', 'nome': 'Antigo', 'grupo': 'Pernas'},
      ],
      itensTreino: [],
      sessoesTreino: [],
    );
    await banco.salvarTexto('workholy_assinatura_teste', 'preservar');
    await corridas.criar('corrida-antiga', 1234);
    await corridas.atualizar(
      id: 'corrida-antiga',
      duracaoSegundos: 10,
      distanciaMetros: 10,
      estado: 'finalizada',
      rota: [],
    );
  });

  tearDown(() async {
    await (await banco.database).close();
    await corridas.fechar();
    await diretorio.delete(recursive: true);
  });

  Future<void> restaurar(
    Map<String, dynamic> dados,
    List<Map<String, dynamic>> registros, {
    int? versaoPrincipal,
    int? versaoCorridas,
  }) async {
    await banco.restaurarDadosComCorridas(
      dados: dados,
      corridas: registros,
      caminhoBancoCorridas: (await corridas.database).path,
      versaoPrincipalEsperada:
          versaoPrincipal ?? await banco.versaoAlteracoes(),
      versaoCorridasEsperada:
          versaoCorridas ?? await corridas.versaoAlteracoes(),
    );
  }

  test(
    'restaura ambos os bancos e preserva configurações locais protegidas',
    () async {
      final dados = await banco.exportarDadosDoUsuario();
      dados['treinos'] = [
        {'id': 'treino-novo', 'nome': 'Novo'},
      ];
      final registros = await corridas.exportarDadosDoUsuario();
      registros.single['id'] = 'corrida-nova';
      await restaurar(dados, registros);
      expect(
        (await banco.carregarDadosTreino()).treinos.single['id'],
        'treino-novo',
      );
      expect((await corridas.listar()).single['id'], 'corrida-nova');
      expect(await banco.lerTexto('workholy_assinatura_teste'), 'preservar');
    },
  );

  test(
    'backup omite mídia local e mantém arquivo disponível neste aparelho',
    () async {
      final arquivo = File(p.join(diretorio.path, 'foto.jpg'));
      await arquivo.writeAsBytes([1, 2, 3]);
      await banco.salvarDadosTreino(
        treinos: [],
        exercicios: [
          {
            'id': 'ex-local',
            'nome': 'Agachamento',
            'grupo': 'Pernas',
            'series': 3,
            'repeticoes': 10,
            'midias': [
              {'id': 'foto-local', 'tipo': 'foto', 'destino': arquivo.path},
              {
                'id': 'video-link',
                'tipo': 'link',
                'destino': 'https://example.com/video',
              },
            ],
          },
        ],
        itensTreino: [],
        sessoesTreino: [],
      );

      final backup = await banco.exportarDadosDoUsuario();
      final midiasDoBackup =
          (backup['exercicios'] as List).single['midias'] as List;
      expect(midiasDoBackup.map((midia) => midia['tipo']), ['link']);

      await restaurar(backup, await corridas.exportarDadosDoUsuario());
      final midiasLocais =
          (await banco.carregarDadosTreino()).exercicios.single['midias']
              as List;
      expect(midiasLocais.map((midia) => midia['tipo']), ['link', 'foto']);

      await arquivo.delete();
      await restaurar(backup, await corridas.exportarDadosDoUsuario());
      final midiasSemArquivo =
          (await banco.carregarDadosTreino()).exercicios.single['midias']
              as List;
      expect(midiasSemArquivo.map((midia) => midia['tipo']), ['link']);
    },
  );

  test('versão local alterada impede substituir qualquer banco', () async {
    final dados = await banco.exportarDadosDoUsuario();
    dados['treinos'] = [
      {'id': 'novo'},
    ];
    final registros = await corridas.exportarDadosDoUsuario();
    final versao = await corridas.versaoAlteracoes();
    await corridas.criar('corrida-concorrente', 2345);
    await expectLater(
      restaurar(dados, registros, versaoCorridas: versao),
      throwsStateError,
    );
    expect(
      (await banco.carregarDadosTreino()).treinos.single['id'],
      'treino-antigo',
    );
    expect(await corridas.listar(), hasLength(2));
  });

  test('falha no banco de corridas reverte também o banco principal', () async {
    final dados = await banco.exportarDadosDoUsuario();
    dados['treinos'] = [
      {'id': 'novo'},
    ];
    final registros = await corridas.exportarDadosDoUsuario();
    registros.add(Map<String, dynamic>.from(registros.single));
    await expectLater(
      restaurar(dados, registros),
      throwsA(isA<DatabaseException>()),
    );
    expect(
      (await banco.carregarDadosTreino()).treinos.single['id'],
      'treino-antigo',
    );
    expect((await corridas.listar()).single['id'], 'corrida-antiga');
  });

  test('não restaura durante uma corrida aberta', () async {
    final dados = await banco.exportarDadosDoUsuario();
    final registros = await corridas.exportarDadosDoUsuario();
    await corridas.criar('ativa', 2345);
    await expectLater(restaurar(dados, registros), throwsStateError);
    expect(await corridas.listar(), hasLength(2));
    expect(
      (await banco.carregarDadosTreino()).treinos.single['id'],
      'treino-antigo',
    );
  });

  test('rejeita dados incompletos sem apagar registros', () async {
    final dados = await banco.exportarDadosDoUsuario();
    dados.remove('exercicios');
    await expectLater(
      restaurar(dados, await corridas.exportarDadosDoUsuario()),
      throwsFormatException,
    );
    expect(
      (await banco.carregarDadosTreino()).exercicios.single['id'],
      'ex-antigo',
    );
    expect((await corridas.listar()).single['id'], 'corrida-antiga');
  });

  test(
    'recusa restauração em WAL por não garantir atomicidade entre bancos',
    () async {
      final dados = await banco.exportarDadosDoUsuario();
      final registros = await corridas.exportarDadosDoUsuario();
      await (await banco.database).rawQuery('PRAGMA journal_mode = WAL');
      await expectLater(restaurar(dados, registros), throwsStateError);
      expect(
        (await banco.carregarDadosTreino()).treinos.single['id'],
        'treino-antigo',
      );
      expect((await corridas.listar()).single['id'], 'corrida-antiga');
    },
  );
}
