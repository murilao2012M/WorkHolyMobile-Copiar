import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// Banco SQLite central do WorkHoly.
///
/// Os dados que já existiam em [SharedPreferences] são importados uma única
/// vez, em uma transação. As chaves antigas são preservadas no dispositivo
/// como uma cópia de contingência; depois da migração o aplicativo lê e grava
/// exclusivamente neste banco.
class WorkHolyBanco {
  WorkHolyBanco._();

  static final WorkHolyBanco instancia = WorkHolyBanco._();

  static const _versao = 2;
  static const _chaveMigracaoLegada = '_migracao_shared_preferences_v1';

  static const _tabelaConfiguracoes = 'configuracoes';
  static const _tabelaTreinos = 'treinos';
  static const _tabelaExercicios = 'exercicios';
  static const _tabelaItensTreino = 'itens_treino';
  static const _tabelaSessoesTreino = 'sessoes_treino';
  static const _tabelaMetasPessoais = 'metas_pessoais';
  static const _tabelaAvaliacoesFisicas = 'avaliacoes_fisicas';

  static const _chaveTreinos = 'workholy_treinos_v1';
  static const _chaveExercicios = 'workholy_exercicios_v1';
  static const _chaveItensTreino = 'workholy_itens_treino_v1';
  static const _chaveSessoesTreino = 'workholy_sessoes_treino_v1';

  static const _chavesTextoLegadas = [
    'workholy_aparencia_modo_v1',
    'workholy_perfil_praticante_v1',
    'workholy_pref_treino_objetivo_v1',
    'workholy_pref_treino_nivel_v1',
  ];

  static const _chavesInteiroLegadas = [
    'workholy_aparencia_cor_v1',
    'workholy_pref_treino_dias_v1',
    'workholy_pref_treino_duracao_v1',
    'workholy_pref_treino_descanso_v1',
  ];

  static const _chavesBooleanasLegadas = [
    'workholy_boas_vindas_concluida_v1',
    'workholy_tutorial_primeiro_acesso_v1',
  ];

  Database? _db;
  Future<Database>? _aberturaEmAndamento;

  Future<Database> get database {
    final db = _db;
    if (db != null) return Future.value(db);

    return _aberturaEmAndamento ??= _abrirBanco();
  }

  Future<void> preparar() async {
    await database;
  }

  Future<Database> _abrirBanco() async {
    final diretorio = await getDatabasesPath();
    final db = await openDatabase(
      p.join(diretorio, 'workholy.db'),
      version: _versao,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tabelaConfiguracoes (
            chave TEXT PRIMARY KEY NOT NULL,
            tipo TEXT NOT NULL,
            valor TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE $_tabelaTreinos (
            id TEXT PRIMARY KEY NOT NULL,
            nome TEXT NOT NULL,
            objetivo TEXT NOT NULL,
            ordem INTEGER NOT NULL,
            dados_json TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE $_tabelaExercicios (
            id TEXT PRIMARY KEY NOT NULL,
            nome TEXT NOT NULL,
            grupo TEXT NOT NULL,
            ordem INTEGER NOT NULL,
            dados_json TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE $_tabelaItensTreino (
            id TEXT PRIMARY KEY NOT NULL,
            treino_id TEXT NOT NULL,
            exercicio_id TEXT NOT NULL,
            ordem INTEGER NOT NULL,
            dados_json TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE $_tabelaSessoesTreino (
            id TEXT PRIMARY KEY NOT NULL,
            treino_id TEXT NOT NULL,
            nome_treino TEXT NOT NULL,
            inicio_ms INTEGER NOT NULL,
            fim_ms INTEGER,
            ordem INTEGER NOT NULL,
            dados_json TEXT NOT NULL
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_itens_treino_treino ON $_tabelaItensTreino(treino_id)',
        );
        await db.execute(
          'CREATE INDEX idx_sessoes_treino_inicio ON $_tabelaSessoesTreino(inicio_ms DESC)',
        );
        await _criarTabelasDePerfil(db);
      },
      onUpgrade: (db, versaoAntiga, versaoNova) async {
        if (versaoAntiga < 2) {
          await _criarTabelasDePerfil(db);
        }
      },
    );

    await _migrarSharedPreferences(db);
    _db = db;
    return db;
  }

  Future<void> _criarTabelasDePerfil(DatabaseExecutor executor) async {
    await executor.execute('''
      CREATE TABLE IF NOT EXISTS $_tabelaMetasPessoais (
        id TEXT PRIMARY KEY NOT NULL,
        tipo TEXT NOT NULL,
        campo TEXT NOT NULL,
        valor_inicial REAL NOT NULL,
        valor_alvo REAL NOT NULL,
        unidade TEXT NOT NULL,
        prazo_ms INTEGER NOT NULL,
        criada_ms INTEGER NOT NULL
      )
    ''');
    await executor.execute('''
      CREATE TABLE IF NOT EXISTS $_tabelaAvaliacoesFisicas (
        id TEXT PRIMARY KEY NOT NULL,
        data_ms INTEGER NOT NULL,
        peso_kg REAL,
        medidas_json TEXT NOT NULL
      )
    ''');
    await executor.execute(
      'CREATE INDEX IF NOT EXISTS idx_avaliacoes_fisicas_data '
      'ON $_tabelaAvaliacoesFisicas(data_ms DESC)',
    );
  }

  Future<void> _migrarSharedPreferences(Database db) async {
    final migracaoConcluida = await db.query(
      _tabelaConfiguracoes,
      columns: const ['valor'],
      where: 'chave = ?',
      whereArgs: const [_chaveMigracaoLegada],
      limit: 1,
    );

    if (migracaoConcluida.isNotEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final treinos = _lerColecaoLegada(prefs, _chaveTreinos);
    final exercicios = _lerColecaoLegada(prefs, _chaveExercicios);
    final itensTreino = _lerColecaoLegada(prefs, _chaveItensTreino);
    final sessoesTreino = _lerColecaoLegada(prefs, _chaveSessoesTreino);

    await db.transaction((txn) async {
      if (treinos != null) {
        await _substituirTreinos(txn, treinos);
      }
      if (exercicios != null) {
        await _substituirExercicios(txn, exercicios);
      }
      if (itensTreino != null) {
        await _substituirItensTreino(txn, itensTreino);
      }
      if (sessoesTreino != null) {
        await _substituirSessoesTreino(txn, sessoesTreino);
      }

      for (final chave in _chavesTextoLegadas) {
        final valor = prefs.getString(chave);
        if (valor != null) await _salvarConfiguracao(txn, chave, valor);
      }

      for (final chave in _chavesInteiroLegadas) {
        final valor = prefs.getInt(chave);
        if (valor != null) await _salvarConfiguracao(txn, chave, valor);
      }

      for (final chave in _chavesBooleanasLegadas) {
        final valor = prefs.getBool(chave);
        if (valor != null) await _salvarConfiguracao(txn, chave, valor);
      }

      await _salvarConfiguracao(txn, _chaveMigracaoLegada, true);
    });
  }

  List<Map<String, dynamic>>? _lerColecaoLegada(
    SharedPreferences prefs,
    String chave,
  ) {
    final texto = prefs.getString(chave);
    if (texto == null) return null;

    final valor = jsonDecode(texto);
    if (valor is! List) {
      throw FormatException('O valor legado de $chave não é uma lista.');
    }

    return valor.map((item) {
      if (item is! Map) {
        throw FormatException('Um item legado de $chave não é um objeto.');
      }
      return Map<String, dynamic>.from(item);
    }).toList();
  }

  Future<String?> lerTexto(String chave) async {
    final row = await _lerConfiguracao(chave);
    return row?['tipo'] == 'texto' ? (row?['valor'] as String?) : null;
  }

  Future<int?> lerInteiro(String chave) async {
    final row = await _lerConfiguracao(chave);
    if (row?['tipo'] != 'inteiro') return null;
    return int.tryParse(row?['valor']?.toString() ?? '');
  }

  Future<bool?> lerBooleano(String chave) async {
    final row = await _lerConfiguracao(chave);
    if (row?['tipo'] != 'booleano') return null;
    return row?['valor'] == 'true';
  }

  Future<Map<String, Object?>?> _lerConfiguracao(String chave) async {
    final db = await database;
    final rows = await db.query(
      _tabelaConfiguracoes,
      where: 'chave = ?',
      whereArgs: [chave],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> salvarTexto(String chave, String valor) =>
      salvarConfiguracoes({chave: valor});

  Future<void> salvarInteiro(String chave, int valor) =>
      salvarConfiguracoes({chave: valor});

  Future<void> salvarBooleano(String chave, bool valor) =>
      salvarConfiguracoes({chave: valor});

  Future<void> salvarConfiguracoes(Map<String, Object> valores) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final entrada in valores.entries) {
        await _salvarConfiguracao(txn, entrada.key, entrada.value);
      }
    });
  }

  Future<void> _salvarConfiguracao(
    DatabaseExecutor executor,
    String chave,
    Object valor,
  ) async {
    final tipo = switch (valor) {
      String() => 'texto',
      int() => 'inteiro',
      bool() => 'booleano',
      _ => throw ArgumentError.value(valor, 'valor', 'Tipo não suportado.'),
    };

    await executor.insert(_tabelaConfiguracoes, {
      'chave': chave,
      'tipo': tipo,
      'valor': valor.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<DadosTreinoBanco> carregarDadosTreino() async {
    final db = await database;
    final resultados = await Future.wait([
      db.query(_tabelaTreinos, orderBy: 'ordem ASC'),
      db.query(_tabelaExercicios, orderBy: 'ordem ASC'),
      db.query(_tabelaItensTreino, orderBy: 'ordem ASC'),
      db.query(_tabelaSessoesTreino, orderBy: 'ordem ASC'),
    ]);

    return DadosTreinoBanco(
      treinos: _decodificarRegistros(resultados[0]),
      exercicios: _decodificarRegistros(resultados[1]),
      itensTreino: _decodificarRegistros(resultados[2]),
      sessoesTreino: _decodificarRegistros(resultados[3]),
    );
  }

  List<Map<String, dynamic>> _decodificarRegistros(
    List<Map<String, Object?>> rows,
  ) {
    return rows.map((row) {
      final valor = jsonDecode(row['dados_json']! as String);
      if (valor is! Map) {
        throw FormatException('Um registro do banco tem JSON inválido.');
      }
      return Map<String, dynamic>.from(valor);
    }).toList();
  }

  Future<void> salvarDadosTreino({
    required List<Map<String, dynamic>> treinos,
    required List<Map<String, dynamic>> exercicios,
    required List<Map<String, dynamic>> itensTreino,
    required List<Map<String, dynamic>> sessoesTreino,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await _substituirTreinos(txn, treinos);
      await _substituirExercicios(txn, exercicios);
      await _substituirItensTreino(txn, itensTreino);
      await _substituirSessoesTreino(txn, sessoesTreino);
    });
  }

  Future<void> _substituirTreinos(
    DatabaseExecutor executor,
    List<Map<String, dynamic>> dados,
  ) async {
    await executor.delete(_tabelaTreinos);
    for (var ordem = 0; ordem < dados.length; ordem++) {
      final dado = dados[ordem];
      await executor.insert(_tabelaTreinos, {
        'id': _idObrigatorio(dado, _tabelaTreinos),
        'nome': dado['nome']?.toString() ?? 'Treino sem nome',
        'objetivo': dado['objetivo']?.toString() ?? '',
        'ordem': ordem,
        'dados_json': jsonEncode(dado),
      });
    }
  }

  Future<void> _substituirExercicios(
    DatabaseExecutor executor,
    List<Map<String, dynamic>> dados,
  ) async {
    await executor.delete(_tabelaExercicios);
    for (var ordem = 0; ordem < dados.length; ordem++) {
      final dado = dados[ordem];
      await executor.insert(_tabelaExercicios, {
        'id': _idObrigatorio(dado, _tabelaExercicios),
        'nome': dado['nome']?.toString() ?? 'Exercício sem nome',
        'grupo': dado['grupo']?.toString() ?? 'Outros',
        'ordem': ordem,
        'dados_json': jsonEncode(dado),
      });
    }
  }

  Future<void> _substituirItensTreino(
    DatabaseExecutor executor,
    List<Map<String, dynamic>> dados,
  ) async {
    await executor.delete(_tabelaItensTreino);
    for (var ordem = 0; ordem < dados.length; ordem++) {
      final dado = dados[ordem];
      await executor.insert(_tabelaItensTreino, {
        'id': _idObrigatorio(dado, _tabelaItensTreino),
        'treino_id': dado['treinoId']?.toString() ?? '',
        'exercicio_id': dado['exercicioId']?.toString() ?? '',
        'ordem': ordem,
        'dados_json': jsonEncode(dado),
      });
    }
  }

  Future<void> _substituirSessoesTreino(
    DatabaseExecutor executor,
    List<Map<String, dynamic>> dados,
  ) async {
    await executor.delete(_tabelaSessoesTreino);
    for (var ordem = 0; ordem < dados.length; ordem++) {
      final dado = dados[ordem];
      final inicio = DateTime.tryParse(dado['inicio']?.toString() ?? '');
      final fim = DateTime.tryParse(dado['fim']?.toString() ?? '');
      await executor.insert(_tabelaSessoesTreino, {
        'id': _idObrigatorio(dado, _tabelaSessoesTreino),
        'treino_id': dado['treinoId']?.toString() ?? '',
        'nome_treino': dado['nomeTreino']?.toString() ?? 'Treino',
        'inicio_ms': inicio?.millisecondsSinceEpoch ?? 0,
        'fim_ms': fim?.millisecondsSinceEpoch,
        'ordem': ordem,
        'dados_json': jsonEncode(dado),
      });
    }
  }

  String _idObrigatorio(Map<String, dynamic> dado, String tabela) {
    final id = dado['id']?.toString().trim();
    if (id == null || id.isEmpty) {
      throw FormatException('Um registro de $tabela não possui id.');
    }
    return id;
  }

  Future<List<MetaPessoal>> listarMetasPessoais() async {
    final db = await database;
    final rows = await db.query(
      _tabelaMetasPessoais,
      orderBy: 'prazo_ms ASC, criada_ms DESC',
    );
    return rows.map(MetaPessoal.fromRegistro).toList();
  }

  Future<void> salvarMetaPessoal(MetaPessoal meta) async {
    final db = await database;
    await db.insert(
      _tabelaMetasPessoais,
      meta.paraRegistro(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> excluirMetaPessoal(String id) async {
    final db = await database;
    await db.delete(_tabelaMetasPessoais, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<AvaliacaoFisica>> listarAvaliacoesFisicas() async {
    final db = await database;
    final rows = await db.query(
      _tabelaAvaliacoesFisicas,
      orderBy: 'data_ms DESC',
    );
    return rows.map(AvaliacaoFisica.fromRegistro).toList();
  }

  Future<void> salvarAvaliacaoFisica(AvaliacaoFisica avaliacao) async {
    final db = await database;
    await db.insert(
      _tabelaAvaliacoesFisicas,
      avaliacao.paraRegistro(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> excluirAvaliacaoFisica(String id) async {
    final db = await database;
    await db.delete(_tabelaAvaliacoesFisicas, where: 'id = ?', whereArgs: [id]);
  }

  /// Conta sessões encerradas no intervalo [inicio, fim), usando a data de
  /// finalização gravada junto ao histórico real de treinos.
  Future<int> contarSessoesConcluidasNoPeriodo(
    DateTime inicio,
    DateTime fim,
  ) async {
    final db = await database;
    final resultado = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM $_tabelaSessoesTreino '
      'WHERE fim_ms IS NOT NULL AND fim_ms >= ? AND fim_ms < ?',
      [inicio.millisecondsSinceEpoch, fim.millisecondsSinceEpoch],
    );
    return (resultado.first['total'] as num?)?.toInt() ?? 0;
  }
}

class MetaPessoal {
  const MetaPessoal({
    required this.id,
    required this.tipo,
    required this.campo,
    required this.valorInicial,
    required this.valorAlvo,
    required this.unidade,
    required this.prazo,
    required this.criadaEm,
  });

  final String id;
  final String tipo;
  final String campo;
  final double valorInicial;
  final double valorAlvo;
  final String unidade;
  final DateTime prazo;
  final DateTime criadaEm;

  factory MetaPessoal.fromRegistro(Map<String, Object?> registro) {
    return MetaPessoal(
      id: registro['id']?.toString() ?? '',
      tipo: registro['tipo']?.toString() ?? '',
      campo: registro['campo']?.toString() ?? '',
      valorInicial: (registro['valor_inicial'] as num?)?.toDouble() ?? 0,
      valorAlvo: (registro['valor_alvo'] as num?)?.toDouble() ?? 0,
      unidade: registro['unidade']?.toString() ?? '',
      prazo: DateTime.fromMillisecondsSinceEpoch(
        (registro['prazo_ms'] as num?)?.toInt() ?? 0,
      ),
      criadaEm: DateTime.fromMillisecondsSinceEpoch(
        (registro['criada_ms'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  Map<String, Object> paraRegistro() => {
    'id': id,
    'tipo': tipo,
    'campo': campo,
    'valor_inicial': valorInicial,
    'valor_alvo': valorAlvo,
    'unidade': unidade,
    'prazo_ms': prazo.millisecondsSinceEpoch,
    'criada_ms': criadaEm.millisecondsSinceEpoch,
  };
}

class AvaliacaoFisica {
  const AvaliacaoFisica({
    required this.id,
    required this.data,
    required this.medidas,
    this.pesoKg,
  });

  final String id;
  final DateTime data;
  final double? pesoKg;
  final Map<String, double> medidas;

  factory AvaliacaoFisica.fromRegistro(Map<String, Object?> registro) {
    final medidasJson = registro['medidas_json']?.toString() ?? '{}';
    Map<String, double> medidas = const {};
    try {
      final dados = jsonDecode(medidasJson);
      if (dados is Map) {
        medidas = Map.unmodifiable({
          for (final entrada in dados.entries)
            if (entrada.value is num)
              entrada.key.toString(): (entrada.value as num).toDouble(),
        });
      }
    } catch (_) {
      // Uma avaliação inválida não deve impedir o restante do histórico.
    }

    return AvaliacaoFisica(
      id: registro['id']?.toString() ?? '',
      data: DateTime.fromMillisecondsSinceEpoch(
        (registro['data_ms'] as num?)?.toInt() ?? 0,
      ),
      pesoKg: (registro['peso_kg'] as num?)?.toDouble(),
      medidas: medidas,
    );
  }

  Map<String, Object?> paraRegistro() => {
    'id': id,
    'data_ms': data.millisecondsSinceEpoch,
    'peso_kg': pesoKg,
    'medidas_json': jsonEncode(medidas),
  };
}

class DadosTreinoBanco {
  const DadosTreinoBanco({
    required this.treinos,
    required this.exercicios,
    required this.itensTreino,
    required this.sessoesTreino,
  });

  final List<Map<String, dynamic>> treinos;
  final List<Map<String, dynamic>> exercicios;
  final List<Map<String, dynamic>> itensTreino;
  final List<Map<String, dynamic>> sessoesTreino;
}
