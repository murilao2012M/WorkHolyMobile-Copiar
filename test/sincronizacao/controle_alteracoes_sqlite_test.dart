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

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    diretorio = await Directory.systemTemp.createTemp('workholy_sync_test_');
  });

  tearDown(() async {
    await diretorio.delete(recursive: true);
  });

  test('alterações locais são persistentes e transacionais', () async {
    final caminho = p.join(diretorio.path, 'dados.db');
    final banco = WorkHolyBanco.paraTestes(caminho: caminho);
    final antes = await banco.versaoAlteracoes();
    await banco.salvarDadosTreino(
      treinos: [
        {'id': 'a', 'nome': 'Treino'},
      ],
      exercicios: [],
      itensTreino: [],
      sessoesTreino: [],
    );
    final depois = await banco.versaoAlteracoes();
    expect(depois, greaterThan(antes));
    final db = await banco.database;
    await expectLater(
      db.transaction<void>((txn) async {
        await txn.insert('configuracoes', {
          'chave': 'teste',
          'tipo': 'texto',
          'valor': 'valor',
        });
        throw StateError('cancelar transação');
      }),
      throwsStateError,
    );
    expect(await banco.versaoAlteracoes(), depois);
    await db.close();
    final reaberto = WorkHolyBanco.paraTestes(caminho: caminho);
    expect(await reaberto.versaoAlteracoes(), depois);
    expect((await reaberto.carregarDadosTreino()).treinos.single['id'], 'a');
    await (await reaberto.database).close();
  });

  test('gravações de outra conexão de corrida incrementam a versão', () async {
    final caminho = p.join(diretorio.path, 'corridas.db');
    final banco = CorridaBanco.paraTestes(caminho: caminho);
    final antes = await banco.versaoAlteracoes();
    await banco.criar('corrida-1', 1234);
    final criada = await banco.versaoAlteracoes();
    expect(criada, greaterThan(antes));

    final outraConexao = await openDatabase(caminho, singleInstance: false);
    await outraConexao.update(
      'corridas',
      {'duracao_segundos': 10},
      where: 'id = ?',
      whereArgs: ['corrida-1'],
    );
    final atualizada = await banco.versaoAlteracoes();
    expect(atualizada, greaterThan(criada));
    await outraConexao.close();
    await banco.fechar();

    final reaberto = CorridaBanco.paraTestes(caminho: caminho);
    expect(await reaberto.versaoAlteracoes(), atualizada);
    expect((await reaberto.buscar('corrida-1'))!['duracao_segundos'], 10);
    await reaberto.fechar();
  });

  test('inserção, atualização e exclusão são contabilizadas', () async {
    final caminho = p.join(diretorio.path, 'corridas.db');
    final banco = CorridaBanco.paraTestes(caminho: caminho);
    final inicial = await banco.versaoAlteracoes();
    await banco.criar('corrida-1', 1234);
    expect(await banco.versaoAlteracoes(), inicial + 1);
    final db = await banco.database;
    await db.update(
      'corridas',
      {'duracao_segundos': 10},
      where: 'id = ?',
      whereArgs: ['corrida-1'],
    );
    expect(await banco.versaoAlteracoes(), inicial + 2);
    await banco.excluir('corrida-1');
    expect(await banco.versaoAlteracoes(), inicial + 3);
    await banco.fechar();
  });

  test('capturas preservam os dados e versões de cada banco', () async {
    final principal = WorkHolyBanco.paraTestes(
      caminho: p.join(diretorio.path, 'dados.db'),
    );
    final corridas = CorridaBanco.paraTestes(
      caminho: p.join(diretorio.path, 'corridas.db'),
    );
    addTearDown(() async {
      await (await principal.database).close();
      await corridas.fechar();
    });
    await principal.salvarTexto('preferencia', 'primeira');
    await corridas.criar('corrida-1', 1234);

    final snapshotPrincipal = await principal.exportarDadosDoUsuarioComVersao();
    final snapshotCorridas = await corridas.exportarDadosDoUsuarioComVersao();
    expect(snapshotPrincipal.versao, await principal.versaoAlteracoes());
    expect(snapshotCorridas.versao, await corridas.versaoAlteracoes());
    expect(
      snapshotPrincipal.dados['configuracoes'],
      contains(
        predicate<Map<String, dynamic>>(
          (item) =>
              item['chave'] == 'preferencia' && item['valor'] == 'primeira',
        ),
      ),
    );
    expect(snapshotCorridas.dados.single['duracao_segundos'], 0);

    await principal.salvarTexto('preferencia', 'segunda');
    final outraConexao = await openDatabase(
      p.join(diretorio.path, 'corridas.db'),
      singleInstance: false,
    );
    addTearDown(outraConexao.close);
    await outraConexao.update('corridas', {'duracao_segundos': 10});
    expect(
      await principal.versaoAlteracoes(),
      greaterThan(snapshotPrincipal.versao),
    );
    expect(
      await corridas.versaoAlteracoes(),
      greaterThan(snapshotCorridas.versao),
    );
    expect(
      snapshotPrincipal.dados['configuracoes'],
      contains(
        predicate<Map<String, dynamic>>(
          (item) =>
              item['chave'] == 'preferencia' && item['valor'] == 'primeira',
        ),
      ),
    );
    expect(snapshotCorridas.dados.single['duracao_segundos'], 0);
  });

  test(
    'migração do banco principal preserva dados e ativa o contador',
    () async {
      final caminho = p.join(diretorio.path, 'dados_v3.db');
      final original = WorkHolyBanco.paraTestes(caminho: caminho);
      await original.salvarTexto('configuracao_usuario', 'valor preservado');
      await original.salvarDadosTreino(
        treinos: [
          {'id': 'treino-1', 'nome': 'Treino preservado'},
        ],
        exercicios: [],
        itensTreino: [],
        sessoesTreino: [],
      );
      final db = await original.database;
      final triggers = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'trigger' "
        "AND name LIKE 'sync_%'",
      );
      for (final trigger in triggers) {
        await db.execute('DROP TRIGGER "${trigger['name']}"');
      }
      await db.execute('DROP TABLE workholy_controle_alteracoes');
      await db.execute('PRAGMA user_version = 3');
      await db.close();

      final migrado = WorkHolyBanco.paraTestes(caminho: caminho);
      expect(
        await migrado.lerTexto('configuracao_usuario'),
        'valor preservado',
      );
      expect(
        (await migrado.carregarDadosTreino()).treinos.single['nome'],
        'Treino preservado',
      );
      final inicial = await migrado.versaoAlteracoes();
      expect(inicial, 1);
      await migrado.salvarTexto('configuracao_usuario', 'alterado');
      expect(await migrado.versaoAlteracoes(), greaterThan(inicial));
      await (await migrado.database).close();
    },
  );

  for (final versaoAntiga in [1, 2]) {
    test('migração de corridas v$versaoAntiga preserva registros', () async {
      final caminho = p.join(diretorio.path, 'corridas_v$versaoAntiga.db');
      final antigo = await openDatabase(
        caminho,
        version: versaoAntiga,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE corridas (
              id TEXT PRIMARY KEY,
              inicio_ms INTEGER NOT NULL,
              fim_ms INTEGER,
              duracao_segundos INTEGER NOT NULL DEFAULT 0,
              distancia_metros REAL NOT NULL DEFAULT 0,
              estado TEXT NOT NULL,
              rota_json TEXT NOT NULL DEFAULT '[]'
              ${version >= 2 ? ', calorias_estimadas REAL NOT NULL DEFAULT 0, peso_kg REAL' : ''}
            )
          ''');
          await db.insert('corridas', {
            'id': 'corrida-preservada',
            'inicio_ms': 1234,
            'estado': 'pausada',
            'rota_json': '[{"lat":-23.1,"lon":-45.1}]',
          });
        },
      );
      await antigo.close();

      final migrado = CorridaBanco.paraTestes(caminho: caminho);
      final corrida = (await migrado.buscar('corrida-preservada'))!;
      expect(corrida['inicio_ms'], 1234);
      expect(corrida['estado'], 'pausada');
      expect(corrida['rota_json'], '[{"lat":-23.1,"lon":-45.1}]');
      expect(corrida['calorias_estimadas'], 0);
      expect(corrida['peso_kg'], isNull);
      expect(await migrado.versaoAlteracoes(), 1);
      await migrado.excluir('corrida-preservada');
      expect(await migrado.versaoAlteracoes(), 2);
      await migrado.fechar();
    });
  }
}
