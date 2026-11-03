import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workholy_mobile/corrida/corrida_banco.dart';
import 'package:workholy_mobile/sincronizacao/controle_alteracoes_sqlite.dart';

void main() {
  late Directory diretorioTemporario;
  late CorridaBanco banco;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    diretorioTemporario = await Directory.systemTemp.createTemp(
      'workholy_corrida_test_',
    );

    banco = CorridaBanco.paraTestes(
      caminho: p.join(diretorioTemporario.path, 'teste.db'),
    );
  });

  tearDown(() async {
    await banco.fechar();

    if (await diretorioTemporario.exists()) {
      await diretorioTemporario.delete(recursive: true);
    }
  });

  test('cria e consulta uma corrida', () async {
    final inicioMs = DateTime.now().millisecondsSinceEpoch;

    await banco.criar('corrida-1', inicioMs);

    final registro = await banco.buscar('corrida-1');

    expect(registro, isNotNull);
    expect(registro!['id'], 'corrida-1');
    expect(registro['inicio_ms'], inicioMs);
    expect(registro['estado'], 'em_andamento');
    expect(registro['fim_ms'], isNull);
  });

  test(
    'migração v3 preserva corrida e contador ao adicionar vínculo',
    () async {
      final caminho = p.join(diretorioTemporario.path, 'antigo.db');
      final antigo = await openDatabase(
        caminho,
        version: 3,
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE corridas (
            id TEXT PRIMARY KEY, inicio_ms INTEGER NOT NULL, fim_ms INTEGER,
            duracao_segundos INTEGER NOT NULL DEFAULT 0,
            distancia_metros REAL NOT NULL DEFAULT 0, estado TEXT NOT NULL,
            rota_json TEXT NOT NULL DEFAULT '[]',
            calorias_estimadas REAL NOT NULL DEFAULT 0, peso_kg REAL
          )
        ''');
          await ControleAlteracoesSqlite.criar(db, ['corridas']);
          await db.insert('corridas', {
            'id': 'antiga',
            'inicio_ms': 1000,
            'estado': 'finalizada',
            'fim_ms': 2000,
          });
        },
      );
      final versaoAntes = await ControleAlteracoesSqlite.ler(antigo);
      await antigo.close();
      final migrado = CorridaBanco.paraTestes(caminho: caminho);
      addTearDown(migrado.fechar);
      expect((await migrado.buscar('antiga'))!['workfit_plano_id'], isNull);
      expect(await migrado.versaoAlteracoes(), versaoAntes);
      await migrado.criar('nova', 3000, workfitPlanoId: 'plano');
      expect(await migrado.versaoAlteracoes(), greaterThan(versaoAntes));
      await migrado.atualizar(
        id: 'nova',
        duracaoSegundos: 10,
        distanciaMetros: 50,
        estado: 'finalizada',
        rota: const [],
        fimMs: 4000,
      );
      await migrado.registrarRpe('nova', 8);
      expect((await migrado.buscar('nova'))!['workfit_plano_id'], 'plano');
      expect((await migrado.buscar('nova'))!['rpe'], 8);
      expect((await migrado.listarFinalizadas()).first.workfitPlanoId, 'plano');
      final exportado = await migrado.exportarDadosDoUsuario();
      expect(
        exportado.singleWhere(
          (corrida) => corrida['id'] == 'nova',
        )['workfit_plano_id'],
        'plano',
      );
      expect(
        exportado.singleWhere((corrida) => corrida['id'] == 'nova')['rpe'],
        8,
      );
      await expectLater(migrado.registrarRpe('nova', 11), throwsArgumentError);
      await expectLater(
        migrado.registrarRpe('inexistente', 7),
        throwsStateError,
      );
    },
  );

  test('atualiza duraÃ§Ã£o, distÃ¢ncia, estado e rota', () async {
    await banco.criar('corrida-2', 1000);

    final rota = <Map<String, double>>[
      {'lat': -23.18, 'lon': -45.88},
      {'lat': -23.19, 'lon': -45.89},
    ];

    await banco.atualizar(
      id: 'corrida-2',
      duracaoSegundos: 120,
      distanciaMetros: 850.5,
      estado: 'pausada',
      rota: rota,
    );

    final registro = (await banco.buscar('corrida-2'))!;

    expect(registro['duracao_segundos'], 120);
    expect((registro['distancia_metros'] as num).toDouble(), 850.5);
    expect(registro['estado'], 'pausada');

    final rotaSalva = banco.decodificarRota(registro['rota_json']);

    expect(rotaSalva, hasLength(2));
    expect(rotaSalva.first['lat'], -23.18);
    expect(rotaSalva.first['lon'], -45.88);
  });

  test('finalizaÃ§Ã£o registra fim_ms', () async {
    await banco.criar('corrida-3', 1000);

    const fimMs = 5000;

    await banco.atualizar(
      id: 'corrida-3',
      duracaoSegundos: 4,
      distanciaMetros: 25,
      estado: 'finalizada',
      rota: const [],
      fimMs: fimMs,
    );

    final registro = (await banco.buscar('corrida-3'))!;

    expect(registro['estado'], 'finalizada');
    expect(registro['fim_ms'], fimMs);
  });

  test('atualizaÃ§Ã£o sem fimMs preserva a data de finalizaÃ§Ã£o', () async {
    await banco.criar('corrida-4', 1000);

    await banco.atualizar(
      id: 'corrida-4',
      duracaoSegundos: 60,
      distanciaMetros: 500,
      estado: 'finalizada',
      rota: const [],
      fimMs: 9000,
    );

    await banco.atualizar(
      id: 'corrida-4',
      duracaoSegundos: 61,
      distanciaMetros: 510,
      estado: 'finalizada',
      rota: const [],
    );

    final registro = (await banco.buscar('corrida-4'))!;

    expect(registro['fim_ms'], 9000);
    expect(registro['duracao_segundos'], 61);
    expect((registro['distancia_metros'] as num).toDouble(), 510);
  });

  test('lista somente corridas finalizadas no histÃ³rico concluÃ­do', () async {
    await banco.criar('corrida-aberta', 1000);
    await banco.criar('corrida-finalizada', 2000);

    await banco.atualizar(
      id: 'corrida-finalizada',
      duracaoSegundos: 180,
      distanciaMetros: 1000,
      estado: 'finalizada',
      rota: const [],
      fimMs: 3000,
    );

    final finalizadas = await banco.listarFinalizadas();

    expect(finalizadas, hasLength(1));
    expect(finalizadas.single.id, 'corrida-finalizada');
    expect(finalizadas.single.fim.millisecondsSinceEpoch, 3000);
  });
}
