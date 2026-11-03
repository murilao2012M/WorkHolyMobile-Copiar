import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workholy_mobile/corrida/corrida_banco.dart';
import 'package:workholy_mobile/dados/workholy_banco.dart';
import 'package:workholy_mobile/sincronizacao/captura_dados_locais.dart';
import 'package:workholy_mobile/sincronizacao/controle_alteracoes_sqlite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('captura os dois bancos com as versões correspondentes', () async {
    SharedPreferences.setMockInitialValues({});
    final diretorio = await Directory.systemTemp.createTemp(
      'workholy_captura_',
    );
    final principal = WorkHolyBanco.paraTestes(
      caminho: p.join(diretorio.path, 'principal.db'),
    );
    final corridas = CorridaBanco.paraTestes(
      caminho: p.join(diretorio.path, 'corridas.db'),
    );
    addTearDown(() async {
      await (await principal.database).close();
      await corridas.fechar();
      await diretorio.delete(recursive: true);
    });

    await principal.salvarTexto('preferencia', 'valor');
    await corridas.criar('corrida', 1234);
    final captura = await CapturaDadosLocais.dosBancos(
      principal,
      corridas,
    ).capturar();

    expect(captura.principal.versao, await principal.versaoAlteracoes());
    expect(captura.corridas.versao, await corridas.versaoAlteracoes());
    expect(
      captura.principal.dados['configuracoes'],
      contains(
        predicate<Map<String, dynamic>>(
          (item) => item['chave'] == 'preferencia' && item['valor'] == 'valor',
        ),
      ),
    );
    expect(captura.corridas.dados.single['id'], 'corrida');
  });

  test(
    'repete captura quando outra conexão altera o banco principal',
    () async {
      SharedPreferences.setMockInitialValues({});
      final diretorio = await Directory.systemTemp.createTemp(
        'workholy_captura_',
      );
      final caminho = p.join(diretorio.path, 'principal.db');
      final principal = WorkHolyBanco.paraTestes(caminho: caminho);
      final corridas = CorridaBanco.paraTestes(
        caminho: p.join(diretorio.path, 'corridas.db'),
      );
      addTearDown(() async {
        await (await principal.database).close();
        await corridas.fechar();
        await diretorio.delete(recursive: true);
      });
      await principal.salvarTexto('preferencia', 'antes');
      final outraConexao = await openDatabase(caminho, singleInstance: false);
      addTearDown(outraConexao.close);
      var capturasCorrida = 0;
      final captura = CapturaDadosLocais(
        capturarPrincipal: principal.exportarDadosDoUsuarioComVersao,
        capturarCorridas: () async {
          final snapshot = await corridas.exportarDadosDoUsuarioComVersao();
          if (++capturasCorrida == 1) {
            await outraConexao.update(
              'configuracoes',
              {'valor': 'depois'},
              where: 'chave = ?',
              whereArgs: ['preferencia'],
            );
          }
          return snapshot;
        },
        lerVersaoPrincipal: principal.versaoAlteracoes,
        lerVersaoCorridas: corridas.versaoAlteracoes,
      );
      final resultado = await captura.capturar();
      expect(capturasCorrida, 2);
      expect(
        resultado.principal.dados['configuracoes'],
        contains(
          predicate<Map<String, dynamic>>(
            (item) =>
                item['chave'] == 'preferencia' && item['valor'] == 'depois',
          ),
        ),
      );
    },
  );

  for (final bancoAlterado in ['principal', 'corridas']) {
    test('repete a captura após alteração em $bancoAlterado', () async {
      var versaoPrincipal = 1;
      var versaoCorridas = 1;
      var capturas = 0;
      final captura = CapturaDadosLocais(
        capturarPrincipal: () async {
          capturas++;
          return SnapshotLocal(versao: versaoPrincipal, dados: {});
        },
        capturarCorridas: () async {
          final versao = versaoCorridas;
          if (capturas == 1) {
            if (bancoAlterado == 'principal') {
              versaoPrincipal++;
            } else {
              versaoCorridas++;
            }
          }
          return SnapshotLocal(versao: versao, dados: []);
        },
        lerVersaoPrincipal: () async => versaoPrincipal,
        lerVersaoCorridas: () async => versaoCorridas,
      );
      final resultado = await captura.capturar();
      expect(capturas, 2);
      expect(resultado.principal.versao, versaoPrincipal);
      expect(resultado.corridas.versao, versaoCorridas);
    });
  }

  test('informa falha quando não consegue capturar versões estáveis', () async {
    var versao = 0;
    final captura = CapturaDadosLocais(
      capturarPrincipal: () async => SnapshotLocal(versao: versao, dados: {}),
      capturarCorridas: () async {
        versao++;
        return const SnapshotLocal(versao: 1, dados: []);
      },
      lerVersaoPrincipal: () async => versao,
      lerVersaoCorridas: () async => 1,
    );
    await expectLater(
      captura.capturar(),
      throwsA(isA<DadosLocaisEmAlteracao>()),
    );
    expect(versao, 3);
  });

  test('propaga falhas de leitura em vez de retornar uma captura', () async {
    final captura = CapturaDadosLocais(
      capturarPrincipal: () async => throw StateError('erro no banco'),
      capturarCorridas: () async => const SnapshotLocal(versao: 1, dados: []),
      lerVersaoPrincipal: () async => 1,
      lerVersaoCorridas: () async => 1,
    );
    await expectLater(captura.capturar(), throwsStateError);
  });
}
