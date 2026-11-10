import 'dart:convert';
import 'dart:developer' as developer;

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../alunos/alunos_modelos.dart';
import '../sincronizacao/controle_alteracoes_sqlite.dart';

/// Banco SQLite central do WorkHoly.
///
/// Os dados que já existiam em [SharedPreferences] são importados uma única
/// vez, em uma transação. As chaves antigas são preservadas no dispositivo
/// como uma cópia de contingência; depois da migração o aplicativo lê e grava
/// exclusivamente neste banco.
class WorkHolyBanco {
  WorkHolyBanco._() : _caminhoBanco = null;

  WorkHolyBanco.paraTestes({required String caminho}) : _caminhoBanco = caminho;

  static final WorkHolyBanco instancia = WorkHolyBanco._();

  static const _versao = 4;
  static const _chaveMigracaoLegada = '_migracao_shared_preferences_v1';

  /// Identifica a conta que possui os dados atualmente armazenados neste
  /// aparelho. Nunca é enviado para a nuvem.
  static const chaveUsuarioSincronizado = '_workholy_usuario_sincronizado_v1';

  static const _tabelaConfiguracoes = 'configuracoes';
  static const _tabelaTreinos = 'treinos';
  static const _tabelaExercicios = 'exercicios';
  static const _tabelaItensTreino = 'itens_treino';
  static const _tabelaSessoesTreino = 'sessoes_treino';
  static const _tabelaMetasPessoais = 'metas_pessoais';
  static const _tabelaAvaliacoesFisicas = 'avaliacoes_fisicas';
  static const _tabelaAlunos = 'alunos';
  static const _tabelaAnotacoesAlunos = 'anotacoes_alunos';
  static const _tabelaRecordesPessoais = 'recordes_pessoais';

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
  final String? _caminhoBanco;

  Future<Database> get database {
    final db = _db;
    if (db != null) return Future.value(db);

    return _aberturaEmAndamento ??= _abrirBanco();
  }

  Future<void> preparar() async {
    await database;
  }

  Future<void> fechar() async {
    final db = _db;
    _db = null;
    _aberturaEmAndamento = null;
    if (db != null) await db.close();
  }

  Future<Database> _abrirBanco() async {
    final caminho =
        _caminhoBanco ?? p.join(await getDatabasesPath(), 'workholy.db');
    final db = await openDatabase(
      caminho,
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
        await _criarTabelasDeAlunos(db);
        await _criarTabelaRecordesPessoais(db);
        await _criarControleAlteracoes(db);
      },
      onUpgrade: (db, versaoAntiga, versaoNova) async {
        if (versaoAntiga < 2) {
          await _criarTabelasDePerfil(db);
        }
        if (versaoAntiga < 3) {
          await _criarTabelasDeAlunos(db);
        }
        if (versaoAntiga < 4) {
          await _criarTabelaRecordesPessoais(db);
          await _criarControleAlteracoes(db);
        }
      },
    );

    await _migrarSharedPreferences(db);
    _db = db;
    return db;
  }

  Future<void> _criarControleAlteracoes(DatabaseExecutor db) =>
      ControleAlteracoesSqlite.criar(db, [
        _tabelaConfiguracoes,
        _tabelaTreinos,
        _tabelaExercicios,
        _tabelaItensTreino,
        _tabelaSessoesTreino,
        _tabelaMetasPessoais,
        _tabelaAvaliacoesFisicas,
        _tabelaRecordesPessoais,
      ]);

  Future<int> versaoAlteracoes() async =>
      ControleAlteracoesSqlite.ler(await database);

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

  Future<void> _criarTabelasDeAlunos(DatabaseExecutor executor) async {
    await executor.execute('''
      CREATE TABLE IF NOT EXISTS $_tabelaAlunos (
        id TEXT PRIMARY KEY NOT NULL,
        nome TEXT NOT NULL,
        status TEXT NOT NULL,
        inicio_ms INTEGER NOT NULL,
        dados_json TEXT NOT NULL
      )
    ''');
    await executor.execute(
      'CREATE INDEX IF NOT EXISTS idx_alunos_nome ON $_tabelaAlunos(nome COLLATE NOCASE)',
    );
    await executor.execute('''
      CREATE TABLE IF NOT EXISTS $_tabelaAnotacoesAlunos (
        id TEXT PRIMARY KEY NOT NULL,
        aluno_id TEXT NOT NULL,
        texto TEXT NOT NULL,
        criada_ms INTEGER NOT NULL,
        FOREIGN KEY(aluno_id) REFERENCES $_tabelaAlunos(id) ON DELETE CASCADE
      )
    ''');
    await executor.execute(
      'CREATE INDEX IF NOT EXISTS idx_anotacoes_aluno_data '
      'ON $_tabelaAnotacoesAlunos(aluno_id, criada_ms DESC)',
    );
  }

  Future<void> _criarTabelaRecordesPessoais(DatabaseExecutor executor) async {
    await executor.execute('''
      CREATE TABLE IF NOT EXISTS $_tabelaRecordesPessoais (
        id TEXT PRIMARY KEY NOT NULL,
        exercicio_id TEXT NOT NULL,
        nome_exercicio TEXT NOT NULL,
        tipo TEXT NOT NULL,
        valor REAL NOT NULL,
        unidade TEXT NOT NULL,
        data_ms INTEGER NOT NULL,
        origem TEXT NOT NULL,
        sessao_id TEXT,
        observacao TEXT NOT NULL DEFAULT ''
      )
    ''');
    await executor.execute('''
      CREATE INDEX IF NOT EXISTS idx_recordes_exercicio_data
      ON $_tabelaRecordesPessoais (exercicio_id, data_ms DESC)
    ''');
    await executor.execute('''
      CREATE INDEX IF NOT EXISTS idx_recordes_sessao
      ON $_tabelaRecordesPessoais (sessao_id)
    ''');
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
    return _carregarDadosTreino(db);
  }

  Future<DadosTreinoBanco> _carregarDadosTreino(DatabaseExecutor db) async {
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
    final registros = <Map<String, dynamic>>[];
    for (final row in rows) {
      try {
        final valor = jsonDecode(row['dados_json']! as String);
        if (valor is! Map) {
          throw const FormatException('O registro não contém um objeto JSON.');
        }
        registros.add(Map<String, dynamic>.from(valor));
      } on FormatException catch (erro, stackTrace) {
        developer.log(
          'Registro inválido ignorado durante a leitura do banco.',
          name: 'workholy.database',
          error: erro,
          stackTrace: stackTrace,
        );
      } on TypeError catch (erro, stackTrace) {
        developer.log(
          'Registro inválido ignorado durante a leitura do banco.',
          name: 'workholy.database',
          error: erro,
          stackTrace: stackTrace,
        );
      }
    }
    return registros;
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

  /// Adiciona exercícios do catálogo sem substituir os registros existentes.
  Future<List<Map<String, dynamic>>> adicionarExerciciosDoCatalogo(
    List<Map<String, dynamic>> candidatos,
  ) async {
    final db = await database;
    return db.transaction((txn) async {
      final registros = await txn.query(
        _tabelaExercicios,
        columns: ['dados_json'],
      );
      final existentes = _decodificarRegistros(registros);
      final idsCatalogo = <String>{};
      for (final exercicio in existentes) {
        final id = exercicio['catalogoId'];
        if (id == null) continue;
        if (id is! String || id.trim().isEmpty) {
          throw const FormatException('Identificador de catálogo inválido.');
        }
        idsCatalogo.add(id);
      }
      final ordemResult = await txn.rawQuery(
        'SELECT MAX(ordem) AS maior FROM $_tabelaExercicios',
      );
      var ordem = ((ordemResult.single['maior'] as int?) ?? -1) + 1;
      final adicionados = <Map<String, dynamic>>[];
      final lote = txn.batch();
      for (final candidato in candidatos) {
        final catalogoId = candidato['catalogoId'];
        if (catalogoId is! String || catalogoId.trim().isEmpty) {
          throw const FormatException(
            'Exercício do catálogo sem identificador.',
          );
        }
        if (!idsCatalogo.add(catalogoId)) continue;
        lote.insert(_tabelaExercicios, {
          'id': _idObrigatorio(candidato, _tabelaExercicios),
          'nome': candidato['nome']?.toString() ?? 'Exercício sem nome',
          'grupo': candidato['grupo']?.toString() ?? 'Outros',
          'ordem': ordem++,
          'dados_json': jsonEncode(candidato),
        });
        adicionados.add(candidato);
      }
      await lote.commit(noResult: true);
      return adicionados;
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

  Future<List<Aluno>> listarAlunos() async {
    final db = await database;
    final rows = await db.query(
      _tabelaAlunos,
      orderBy: 'nome COLLATE NOCASE ASC',
    );
    return rows.map((row) {
      final dados = jsonDecode(row['dados_json']! as String);
      if (dados is! Map) {
        throw const FormatException('Registro de aluno inválido no banco.');
      }
      return Aluno.fromJson(Map<String, dynamic>.from(dados));
    }).toList();
  }

  Future<void> salvarAluno(Aluno aluno) async {
    if (aluno.nome.trim().isEmpty) {
      throw ArgumentError.value(aluno.nome, 'aluno.nome', 'Nome obrigatório.');
    }
    final db = await database;
    await db.insert(_tabelaAlunos, {
      'id': aluno.id,
      'nome': aluno.nome.trim(),
      'status': aluno.status,
      'inicio_ms': aluno.inicio.millisecondsSinceEpoch,
      'dados_json': jsonEncode(aluno.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> excluirAluno(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        _tabelaAnotacoesAlunos,
        where: 'aluno_id = ?',
        whereArgs: [id],
      );
      final sessoes = await txn.query(_tabelaSessoesTreino);
      for (final sessao in sessoes) {
        try {
          final json = jsonDecode(sessao['dados_json']! as String);
          if (json is Map && json['alunoId'] == id) {
            final dados = Map<String, dynamic>.from(json)..['alunoId'] = null;
            await txn.update(
              _tabelaSessoesTreino,
              {'dados_json': jsonEncode(dados)},
              where: 'id = ?',
              whereArgs: [sessao['id']],
            );
          }
        } on FormatException catch (erro, stackTrace) {
          developer.log(
            'Sessão inválida mantida sem alterar durante a exclusão do aluno.',
            name: 'workholy.database',
            error: erro,
            stackTrace: stackTrace,
          );
        } on TypeError catch (erro, stackTrace) {
          developer.log(
            'Sessão inválida mantida sem alterar durante a exclusão do aluno.',
            name: 'workholy.database',
            error: erro,
            stackTrace: stackTrace,
          );
        }
      }
      await txn.delete(_tabelaAlunos, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<AnotacaoAluno>> listarAnotacoesAluno(String alunoId) async {
    final db = await database;
    final rows = await db.query(
      _tabelaAnotacoesAlunos,
      where: 'aluno_id = ?',
      whereArgs: [alunoId],
      orderBy: 'criada_ms DESC',
    );
    return rows.map(AnotacaoAluno.fromRegistro).toList();
  }

  Future<void> salvarAnotacaoAluno(AnotacaoAluno anotacao) async {
    if (anotacao.texto.trim().isEmpty) {
      throw ArgumentError.value(
        anotacao.texto,
        'anotacao.texto',
        'A anotação não pode ficar vazia.',
      );
    }
    final db = await database;
    await db.insert(
      _tabelaAnotacoesAlunos,
      anotacao.paraRegistro(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> excluirAnotacaoAluno(String id) async {
    final db = await database;
    await db.delete(_tabelaAnotacoesAlunos, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Aluno>> listarAlunosParaBackup() async => listarAlunos();

  Future<List<AnotacaoAluno>> listarAnotacoesParaBackup() async {
    final db = await database;
    final rows = await db.query(
      _tabelaAnotacoesAlunos,
      orderBy: 'criada_ms DESC',
    );
    return rows.map(AnotacaoAluno.fromRegistro).toList();
  }

  Future<void> substituirAlunosEAnotacoes({
    required List<Aluno> alunos,
    required List<AnotacaoAluno> anotacoes,
  }) async {
    final idsAlunos = alunos.map((aluno) => aluno.id).toSet();
    if (idsAlunos.length != alunos.length ||
        anotacoes.any((anotacao) => !idsAlunos.contains(anotacao.alunoId))) {
      throw const FormatException(
        'Backup contém aluno duplicado ou anotação sem aluno.',
      );
    }

    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(_tabelaAnotacoesAlunos);
      await txn.delete(_tabelaAlunos);
      for (final aluno in alunos) {
        await txn.insert(_tabelaAlunos, {
          'id': aluno.id,
          'nome': aluno.nome,
          'status': aluno.status,
          'inicio_ms': aluno.inicio.millisecondsSinceEpoch,
          'dados_json': jsonEncode(aluno.toJson()),
        });
      }
      for (final anotacao in anotacoes) {
        await txn.insert(_tabelaAnotacoesAlunos, anotacao.paraRegistro());
      }
    });
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

  /// Gera uma cópia dos dados pessoais do usuário para o backup sincronizado.
  /// A biblioteca pública de exercícios não é colocada aqui; somente exercícios
  /// cadastrados pela própria pessoa fazem parte desta coleção.
  Future<Map<String, dynamic>> exportarDadosDoUsuario() async {
    return (await exportarDadosDoUsuarioComVersao()).dados;
  }

  /// A versão e os dados são lidos na mesma transação deste banco.
  Future<SnapshotLocal<Map<String, dynamic>>>
  exportarDadosDoUsuarioComVersao() async {
    final db = await database;
    return db.transaction((txn) async {
      final versao = await ControleAlteracoesSqlite.ler(txn);
      final dadosTreino = await _carregarDadosTreino(txn);
      final configuracoesSalvas = await txn.query(_tabelaConfiguracoes);
      final metas = await txn.query(
        _tabelaMetasPessoais,
        orderBy: 'prazo_ms ASC, criada_ms DESC',
      );
      final avaliacoes = await txn.query(
        _tabelaAvaliacoesFisicas,
        orderBy: 'data_ms DESC',
      );
      final recordes = await txn.query(
        _tabelaRecordesPessoais,
        orderBy: 'data_ms DESC',
      );

      final configuracoes = <Map<String, dynamic>>[];
      for (final registro in configuracoesSalvas) {
        final chave = registro['chave']?.toString() ?? '';
        if (!_configuracaoSincronizavel(chave)) continue;
        configuracoes.add(Map<String, dynamic>.from(registro));
      }

      return SnapshotLocal(
        versao: versao,
        dados: {
          'configuracoes': configuracoes,
          'treinos': dadosTreino.treinos,
          'exercicios': dadosTreino.exercicios,
          'itensTreino': dadosTreino.itensTreino,
          'sessoesTreino': dadosTreino.sessoesTreino,
          'metas': metas
              .map(
                (item) => Map<String, dynamic>.from(
                  MetaPessoal.fromRegistro(item).paraRegistro(),
                ),
              )
              .toList(),
          'avaliacoes': avaliacoes
              .map(
                (item) => Map<String, dynamic>.from(
                  AvaliacaoFisica.fromRegistro(item).paraRegistro(),
                ),
              )
              .toList(),
          'recordesPessoais': recordes
              .map((item) => Map<String, dynamic>.from(item))
              .toList(),
        },
      );
    });
  }

  /// Substitui o cache local por uma cópia já validada recebida da conta.
  Future<void> importarDadosDoUsuario(Map<String, dynamic> dados) async {
    final treinos = _listaDeMapas(dados['treinos']);
    final exercicios = _listaDeMapas(dados['exercicios']);
    final itensTreino = _listaDeMapas(dados['itensTreino']);
    final sessoesTreino = _listaDeMapas(dados['sessoesTreino']);
    final metas = _listaDeMapas(dados['metas']);
    final avaliacoes = _listaDeMapas(dados['avaliacoes']);
    final recordes = _listaDeMapas(dados['recordesPessoais']);
    final configuracoes = _listaDeMapas(dados['configuracoes']);
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete(_tabelaTreinos);
      await txn.delete(_tabelaExercicios);
      await txn.delete(_tabelaItensTreino);
      await txn.delete(_tabelaSessoesTreino);
      await txn.delete(_tabelaMetasPessoais);
      await txn.delete(_tabelaAvaliacoesFisicas);
      await txn.delete(_tabelaRecordesPessoais);
      await txn.delete(
        _tabelaConfiguracoes,
        where: 'chave NOT IN (?, ?)',
        whereArgs: [_chaveMigracaoLegada, chaveUsuarioSincronizado],
      );

      await _substituirTreinos(txn, treinos);
      await _substituirExercicios(txn, exercicios);
      await _substituirItensTreino(txn, itensTreino);
      await _substituirSessoesTreino(txn, sessoesTreino);

      for (final meta in metas) {
        await txn.insert(
          _tabelaMetasPessoais,
          Map<String, Object?>.from(meta),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final avaliacao in avaliacoes) {
        await txn.insert(
          _tabelaAvaliacoesFisicas,
          Map<String, Object?>.from(avaliacao),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final recorde in recordes) {
        await txn.insert(
          _tabelaRecordesPessoais,
          Map<String, Object?>.from(recorde),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final configuracao in configuracoes) {
        final chave = configuracao['chave']?.toString() ?? '';
        final tipo = configuracao['tipo']?.toString() ?? '';
        final valor = configuracao['valor']?.toString() ?? '';
        if (!_configuracaoSincronizavel(chave)) continue;
        final valorTipado = switch (tipo) {
          'texto' => valor,
          'inteiro' => int.tryParse(valor),
          'booleano' => valor == 'true',
          _ => null,
        };
        if (valorTipado != null) {
          await _salvarConfiguracao(txn, chave, valorTipado);
        }
      }
    });
  }

  /// Restaura os dois bancos somente se ambos ainda têm as versões informadas.
  ///
  /// Quem chama deve preservar a versão local antes de solicitar a substituição.
  Future<({int principal, int corridas})> restaurarDadosComCorridas({
    required Map<String, dynamic> dados,
    required List<Map<String, dynamic>> corridas,
    required String caminhoBancoCorridas,
    required int versaoPrincipalEsperada,
    required int versaoCorridasEsperada,
  }) async {
    final treinos = _listaDeMapasObrigatoria(dados, 'treinos');
    final exercicios = _listaDeMapasObrigatoria(dados, 'exercicios');
    final itensTreino = _listaDeMapasObrigatoria(dados, 'itensTreino');
    final sessoesTreino = _listaDeMapasObrigatoria(dados, 'sessoesTreino');
    final metas = _listaDeMapasObrigatoria(dados, 'metas');
    final avaliacoes = _listaDeMapasObrigatoria(dados, 'avaliacoes');
    final recordes = _listaDeMapasObrigatoria(dados, 'recordesPessoais');
    final configuracoes = _listaDeMapasObrigatoria(dados, 'configuracoes');
    final valoresConfiguracoes = <String, Object>{};
    for (final configuracao in configuracoes) {
      final chave = configuracao['chave'];
      final tipo = configuracao['tipo'];
      final valor = configuracao['valor'];
      if (chave is! String ||
          !_configuracaoSincronizavel(chave) ||
          valor is! String ||
          valoresConfiguracoes.containsKey(chave)) {
        throw const FormatException('Configuração inválida no backup.');
      }
      final Object? tipado;
      if (tipo == 'texto') {
        tipado = valor;
      } else if (tipo == 'inteiro') {
        tipado = int.tryParse(valor);
      } else if (tipo == 'booleano' && (valor == 'true' || valor == 'false')) {
        tipado = valor == 'true';
      } else {
        tipado = null;
      }
      if (tipado == null) {
        throw const FormatException(
          'Valor de configuração inválido no backup.',
        );
      }
      valoresConfiguracoes[chave] = tipado;
    }
    const colunasCorrida = {
      'id',
      'inicio_ms',
      'fim_ms',
      'duracao_segundos',
      'distancia_metros',
      'estado',
      'rota_json',
      'calorias_estimadas',
      'peso_kg',
      'workfit_plano_id',
      'rpe',
    };
    for (final corrida in corridas) {
      if (corrida.keys.toSet().difference(colunasCorrida).isNotEmpty ||
          corrida['id'] is! String ||
          (corrida['id'] as String).trim().isEmpty ||
          corrida['inicio_ms'] is! int ||
          corrida['duracao_segundos'] is! int ||
          corrida['distancia_metros'] is! num ||
          corrida['estado'] is! String ||
          !{
            'em_andamento',
            'pausada',
            'finalizada',
          }.contains(corrida['estado']) ||
          corrida['rota_json'] is! String ||
          corrida['calorias_estimadas'] is! num ||
          (corrida['fim_ms'] != null && corrida['fim_ms'] is! int) ||
          (corrida['peso_kg'] != null && corrida['peso_kg'] is! num) ||
          (corrida['workfit_plano_id'] != null &&
              corrida['workfit_plano_id'] is! String) ||
          (corrida['rpe'] != null && corrida['rpe'] is! int)) {
        throw const FormatException('Corrida inválida no backup.');
      }
      final rota = jsonDecode(corrida['rota_json'] as String);
      if (rota is! List ||
          rota.any(
            (ponto) =>
                ponto is! Map || ponto['lat'] is! num || ponto['lon'] is! num,
          )) {
        throw const FormatException('Rota inválida no backup.');
      }
    }

    final db = await database;
    if (p.normalize(db.path) == p.normalize(caminhoBancoCorridas)) {
      throw ArgumentError(
        'Os bancos principal e de corridas devem ser distintos.',
      );
    }
    if (p.normalize(p.dirname(db.path)) !=
        p.normalize(p.dirname(caminhoBancoCorridas))) {
      throw ArgumentError('Os bancos devem estar no mesmo diretório.');
    }
    await db.execute('ATTACH DATABASE ? AS backup_corridas', [
      caminhoBancoCorridas,
    ]);
    try {
      for (final nome in ['main', 'backup_corridas']) {
        final modo = await db.rawQuery('PRAGMA $nome.journal_mode');
        final sincronia = await db.rawQuery('PRAGMA $nome.synchronous');
        final journal = modo.single.values.single.toString().toLowerCase();
        final sync = sincronia.single.values.single;
        if (!{'delete', 'truncate', 'persist'}.contains(journal) ||
            sync is! int ||
            sync < 2) {
          throw StateError(
            'Restauração indisponível: o banco não oferece transação segura entre arquivos.',
          );
        }
      }
      return await db.transaction((txn) async {
        final principal = await ControleAlteracoesSqlite.ler(txn);
        final linhas = await txn.rawQuery(
          'SELECT versao FROM backup_corridas.workholy_controle_alteracoes WHERE id = 1',
        );
        if (linhas.length != 1 || linhas.single['versao'] is! int) {
          throw StateError('Controle de alterações das corridas inválido.');
        }
        if (principal != versaoPrincipalEsperada ||
            linhas.single['versao'] != versaoCorridasEsperada) {
          throw StateError(
            'Os dados locais mudaram; tente a restauração novamente.',
          );
        }
        final abertas = await txn.rawQuery(
          "SELECT id FROM backup_corridas.corridas "
          "WHERE estado IN ('em_andamento', 'pausada') LIMIT 1",
        );
        if (abertas.isNotEmpty) {
          throw StateError(
            'Finalize a corrida aberta antes de restaurar o backup.',
          );
        }

        await _substituirTreinos(txn, treinos);
        await _substituirExercicios(txn, exercicios);
        await _substituirItensTreino(txn, itensTreino);
        await _substituirSessoesTreino(txn, sessoesTreino);
        for (final entrada in [
          (_tabelaMetasPessoais, metas),
          (_tabelaAvaliacoesFisicas, avaliacoes),
          (_tabelaRecordesPessoais, recordes),
        ]) {
          await txn.delete(entrada.$1);
          for (final registro in entrada.$2) {
            await txn.insert(entrada.$1, Map<String, Object?>.from(registro));
          }
        }
        final antigas = await txn.query(
          _tabelaConfiguracoes,
          columns: ['chave'],
        );
        for (final registro in antigas) {
          final chave = registro['chave'];
          if (chave is String && _configuracaoSincronizavel(chave)) {
            await txn.delete(
              _tabelaConfiguracoes,
              where: 'chave = ?',
              whereArgs: [chave],
            );
          }
        }
        for (final entrada in valoresConfiguracoes.entries) {
          await _salvarConfiguracao(txn, entrada.key, entrada.value);
        }
        await txn.delete('backup_corridas.corridas');
        for (final corrida in corridas) {
          await txn.insert(
            'backup_corridas.corridas',
            Map<String, Object?>.from(corrida),
          );
        }
        final versaoPrincipal = await ControleAlteracoesSqlite.ler(txn);
        final versaoCorridas = await txn.rawQuery(
          'SELECT versao FROM backup_corridas.workholy_controle_alteracoes WHERE id = 1',
        );
        return (
          principal: versaoPrincipal,
          corridas: versaoCorridas.single['versao']! as int,
        );
      });
    } finally {
      await db.execute('DETACH DATABASE backup_corridas');
    }
  }

  List<Map<String, dynamic>> _listaDeMapasObrigatoria(
    Map<String, dynamic> dados,
    String chave,
  ) {
    final valor = dados[chave];
    if (valor is! List || valor.any((item) => item is! Map)) {
      throw FormatException('Lista inválida no backup: $chave.');
    }
    return valor.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  /// Remove o cache da conta anterior antes que outro usuário entre no mesmo
  /// aparelho. O backup da conta anterior permanece na nuvem.
  Future<void> limparDadosDoUsuario() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(_tabelaTreinos);
      await txn.delete(_tabelaExercicios);
      await txn.delete(_tabelaItensTreino);
      await txn.delete(_tabelaSessoesTreino);
      await txn.delete(_tabelaMetasPessoais);
      await txn.delete(_tabelaAvaliacoesFisicas);
      await txn.delete(_tabelaRecordesPessoais);
      await txn.delete(
        _tabelaConfiguracoes,
        where: 'chave != ?',
        whereArgs: [_chaveMigracaoLegada],
      );
    });
  }

  bool _configuracaoSincronizavel(String chave) {
    return chave.isNotEmpty &&
        chave != _chaveMigracaoLegada &&
        chave != chaveUsuarioSincronizado &&
        chave != '_workholy_backup_ativado_v1' &&
        !chave.startsWith('workholy_assinatura_');
  }

  List<Map<String, dynamic>> _listaDeMapas(Object? valor) {
    if (valor is! List) return const [];
    return valor
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
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
