import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workholy_mobile/corrida/corrida_banco.dart';
import 'package:workholy_mobile/dados/workholy_banco.dart';
import 'package:workholy_mobile/sincronizacao/backup_nuvem_firestore.dart';
import 'package:workholy_mobile/sincronizacao/captura_dados_locais.dart';
import 'package:workholy_mobile/sincronizacao/coordenador_backup.dart';

class NuvemSimulada implements RepositorioBackupNuvem {
  final Map<String, BackupCodificado> versoes = {};
  String? atual;
  bool offline = false;
  bool legado = false;
  bool falhaDepoisDePublicar = false;
  Future<void> Function()? duranteEnvio;

  void _verificar() {
    if (offline) throw StateError('Sem conexão.');
  }

  @override
  Future<String?> versaoAtual() async {
    _verificar();
    return atual;
  }

  @override
  Future<bool> existeBackupLegado() async {
    _verificar();
    return legado;
  }

  @override
  Future<String> guardarVersao(DadosLocaisCapturados snapshot) async {
    _verificar();
    final id = 'v${versoes.length + 1}';
    versoes[id] = CodecBackup.codificar(snapshot);
    await duranteEnvio?.call();
    return id;
  }

  @override
  Future<bool> publicarVersao(
    String id, {
    required String? versaoEsperada,
  }) async {
    _verificar();
    if (atual != versaoEsperada) return false;
    atual = id;
    if (falhaDepoisDePublicar) {
      falhaDepoisDePublicar = false;
      throw StateError('Confirmação perdida.');
    }
    return true;
  }

  @override
  Future<
    ({Map<String, dynamic> principal, List<Map<String, dynamic>> corridas})
  >
  carregarVersao(String id) async {
    _verificar();
    final v = versoes[id]!;
    return CodecBackup.decodificar(
      partes: v.partes,
      tamanho: v.tamanho,
      sha256Hex: v.sha256Hex,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory diretorio;
  late WorkHolyBanco banco;
  late CorridaBanco corridas;
  late NuvemSimulada nuvem;
  late CoordenadorBackup coordenador;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    diretorio = await Directory.systemTemp.createTemp('workholy_coordenador_');
    banco = WorkHolyBanco.paraTestes(
      caminho: p.join(diretorio.path, 'dados.db'),
    );
    corridas = CorridaBanco.paraTestes(
      caminho: p.join(diretorio.path, 'corridas.db'),
    );
    nuvem = NuvemSimulada();
    coordenador = CoordenadorBackup(
      uid: 'conta-a',
      principal: banco,
      corridas: corridas,
      nuvem: nuvem,
      verificarConta: () {},
    );
    await banco.salvarDadosTreino(
      treinos: [
        {'id': 'treino-local', 'nome': 'Local'},
      ],
      exercicios: [],
      itensTreino: [],
      sessoesTreino: [],
    );
  });
  tearDown(() async {
    await (await banco.database).close();
    await corridas.fechar();
    await diretorio.delete(recursive: true);
  });

  test(
    'offline mantém alterações pendentes e reconecta sem duplicar',
    () async {
      nuvem.offline = true;
      await expectLater(coordenador.sincronizar(), throwsStateError);
      expect(nuvem.versoes, isEmpty);
      nuvem.offline = false;
      await coordenador.sincronizar();
      expect(nuvem.atual, 'v1');
      await coordenador.sincronizar();
      expect(nuvem.versoes, hasLength(1));
    },
  );

  test('não publica nem restaura enquanto houver backup legado', () async {
    nuvem.legado = true;
    await expectLater(
      coordenador.sincronizar(),
      throwsA(isA<BackupLegadoEncontrado>()),
    );
    await expectLater(
      coordenador.escolherDadosLocais(null),
      throwsA(isA<BackupLegadoEncontrado>()),
    );
    expect(nuvem.versoes, isEmpty);
    expect(
      (await banco.carregarDadosTreino()).treinos.single['id'],
      'treino-local',
    );
  });

  test('mudança durante envio permanece pendente após confirmação', () async {
    nuvem.duranteEnvio = () async {
      nuvem.duranteEnvio = null;
      await banco.salvarTexto('mudanca', 'nova');
    };
    await coordenador.sincronizar();
    await coordenador.sincronizar();
    expect(nuvem.versoes, hasLength(2));
    final copia = await nuvem.carregarVersao(nuvem.atual!);
    expect(
      copia.principal['configuracoes'],
      contains(
        predicate<Map<String, dynamic>>(
          (row) => row['chave'] == 'mudanca' && row['valor'] == 'nova',
        ),
      ),
    );
  });

  test(
    'confirmação perdida não permite sobrescrever versão publicada',
    () async {
      nuvem.falhaDepoisDePublicar = true;
      await expectLater(coordenador.sincronizar(), throwsStateError);
      expect(nuvem.atual, 'v1');
      await expectLater(
        coordenador.sincronizar(),
        throwsA(isA<ConflitoBackup>()),
      );
      expect(nuvem.versoes, hasLength(1));
      expect(
        (await banco.carregarDadosTreino()).treinos.single['id'],
        'treino-local',
      );
    },
  );

  test('restaurar versão antiga preserva a atual e a cópia local', () async {
    await coordenador.sincronizar();
    final antiga = nuvem.atual!;
    await banco.salvarTexto('segunda', 'versão dois');
    await coordenador.sincronizar();
    final atual = nuvem.atual!;
    await banco.salvarTexto('local', 'pendente');
    await coordenador.restaurarVersao(antiga, atual);
    expect(nuvem.atual, antiga);
    expect(nuvem.versoes, hasLength(3));
    expect(await banco.lerTexto('segunda'), isNull);
    final copiaLocal = await nuvem.carregarVersao('v3');
    expect(
      copiaLocal.principal['configuracoes'],
      contains(
        predicate<Map<String, dynamic>>(
          (row) => row['chave'] == 'local' && row['valor'] == 'pendente',
        ),
      ),
    );
    await coordenador.sincronizar();
    expect(nuvem.versoes, hasLength(3));
  });

  test('duas versões concorrentes geram conflito e preservam cópias', () async {
    await coordenador.sincronizar();
    await banco.salvarTexto('local', 'pendente');
    nuvem.duranteEnvio = () async {
      nuvem.duranteEnvio = null;
      nuvem.atual = 'outro-aparelho';
    };
    await expectLater(
      coordenador.sincronizar(),
      throwsA(isA<ConflitoBackup>()),
    );
    expect(nuvem.atual, 'outro-aparelho');
    expect(nuvem.versoes, hasLength(2));
    expect(await banco.lerTexto('local'), 'pendente');
  });

  test('restaurar preserva cópia da versão local e dados remotos', () async {
    await coordenador.sincronizar();
    final original = nuvem.atual!;
    await banco.salvarTexto('local', 'preservado na nuvem');
    await coordenador.restaurarVersao(original, original);
    expect(await banco.lerTexto('local'), isNull);
    expect(nuvem.versoes, hasLength(2));
    final preservada = await nuvem.carregarVersao('v2');
    expect(
      preservada.principal['configuracoes'],
      contains(
        predicate<Map<String, dynamic>>(
          (row) =>
              row['chave'] == 'local' && row['valor'] == 'preservado na nuvem',
        ),
      ),
    );
    await coordenador.sincronizar();
    expect(nuvem.versoes, hasLength(2));
  });

  test(
    'alteração durante salvamento da cópia local impede restauração',
    () async {
      await coordenador.sincronizar();
      final original = nuvem.atual!;
      nuvem.duranteEnvio = () async {
        nuvem.duranteEnvio = null;
        await banco.salvarTexto('alteracao-concorrente', 'valor');
      };
      await expectLater(
        coordenador.restaurarVersao(original, original),
        throwsStateError,
      );
      expect(await banco.lerTexto('alteracao-concorrente'), 'valor');
      expect(nuvem.versoes, hasLength(2));
    },
  );

  test('outro aparelho detecta conflito e pode restaurar', () async {
    await coordenador.sincronizar();
    final remoto = nuvem.atual!;
    final segundoBanco = WorkHolyBanco.paraTestes(
      caminho: p.join(diretorio.path, 'segundo.db'),
    );
    final segundasCorridas = CorridaBanco.paraTestes(
      caminho: p.join(diretorio.path, 'segundas-corridas.db'),
    );
    try {
      final segundo = CoordenadorBackup(
        uid: 'conta-a',
        principal: segundoBanco,
        corridas: segundasCorridas,
        nuvem: nuvem,
        verificarConta: () {},
      );
      await expectLater(segundo.sincronizar(), throwsA(isA<ConflitoBackup>()));
      await segundo.restaurarVersao(remoto, remoto);
      expect(
        (await segundoBanco.carregarDadosTreino()).treinos.single['id'],
        'treino-local',
      );
      expect(nuvem.versoes, hasLength(2));
      await segundo.sincronizar();
      expect(nuvem.versoes, hasLength(2));
    } finally {
      await (await segundoBanco.database).close();
      await segundasCorridas.fechar();
    }
  });
}
