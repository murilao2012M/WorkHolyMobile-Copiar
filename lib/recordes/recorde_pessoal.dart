import 'package:sqflite/sqflite.dart';

import '../dados/workholy_banco.dart';

enum TipoRecordePessoal { cargaMaxima, repeticoesMaximas }

enum OrigemRecordePessoal { manual, automatico }

class RecordePessoal {
  final String id;
  final String exercicioId;
  final String nomeExercicio;
  final TipoRecordePessoal tipo;
  final double valor;
  final String unidade;
  final DateTime data;
  final OrigemRecordePessoal origem;
  final String? sessaoId;
  final String observacao;

  const RecordePessoal({
    required this.id,
    required this.exercicioId,
    required this.nomeExercicio,
    required this.tipo,
    required this.valor,
    required this.unidade,
    required this.data,
    required this.origem,
    this.sessaoId,
    this.observacao = '',
  });

  String get descricaoTipo => switch (tipo) {
    TipoRecordePessoal.cargaMaxima => 'Maior carga',
    TipoRecordePessoal.repeticoesMaximas => 'Mais repetições',
  };

  Map<String, Object?> toMap() => {
    'id': id,
    'exercicio_id': exercicioId,
    'nome_exercicio': nomeExercicio,
    'tipo': tipo.name,
    'valor': valor,
    'unidade': unidade,
    'data_ms': data.millisecondsSinceEpoch,
    'origem': origem.name,
    'sessao_id': sessaoId,
    'observacao': observacao,
  };

  factory RecordePessoal.fromMap(Map<String, Object?> map) {
    return RecordePessoal(
      id: map['id'] as String,
      exercicioId: map['exercicio_id'] as String,
      nomeExercicio: map['nome_exercicio'] as String,
      tipo: TipoRecordePessoal.values.firstWhere(
        (item) => item.name == map['tipo'],
      ),
      valor: (map['valor'] as num).toDouble(),
      unidade: map['unidade'] as String,
      data: DateTime.fromMillisecondsSinceEpoch(map['data_ms'] as int),
      origem: OrigemRecordePessoal.values.firstWhere(
        (item) => item.name == map['origem'],
      ),
      sessaoId: map['sessao_id'] as String?,
      observacao: map['observacao'] as String? ?? '',
    );
  }
}

class RecordesPessoaisBanco {
  RecordesPessoaisBanco._();

  static final RecordesPessoaisBanco instancia = RecordesPessoaisBanco._();

  static const String _tabela = 'recordes_pessoais';

  Future<Database> get _db async {
    final db = await WorkHolyBanco.instancia.database;

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tabela (
        id TEXT PRIMARY KEY,
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

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_recordes_exercicio_data
      ON $_tabela (exercicio_id, data_ms DESC)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_recordes_sessao
      ON $_tabela (sessao_id)
    ''');

    return db;
  }

  String _novoId() =>
      'rp_${DateTime.now().microsecondsSinceEpoch}_'
      '${DateTime.now().millisecondsSinceEpoch % 100000}';

  Future<List<RecordePessoal>> listar({String? exercicioId}) async {
    final db = await _db;

    final registros = await db.query(
      _tabela,
      where: exercicioId == null ? null : 'exercicio_id = ?',
      whereArgs: exercicioId == null ? null : [exercicioId],
      orderBy: 'data_ms DESC',
    );

    return registros.map(RecordePessoal.fromMap).toList();
  }

  Future<void> salvarManual({
    required String exercicioId,
    required String nomeExercicio,
    required TipoRecordePessoal tipo,
    required double valor,
    required DateTime data,
    String? observacao,
  }) async {
    final nome = nomeExercicio.trim();

    if (exercicioId.trim().isEmpty || nome.isEmpty) {
      throw ArgumentError('Informe o exercício.');
    }

    if (!valor.isFinite || valor <= 0) {
      throw ArgumentError('O valor do recorde deve ser maior que zero.');
    }

    final unidade = switch (tipo) {
      TipoRecordePessoal.cargaMaxima => 'kg',
      TipoRecordePessoal.repeticoesMaximas => 'repetições',
    };

    final recorde = RecordePessoal(
      id: _novoId(),
      exercicioId: exercicioId,
      nomeExercicio: nome,
      tipo: tipo,
      valor: valor,
      unidade: unidade,
      data: data,
      origem: OrigemRecordePessoal.manual,
      observacao: observacao?.trim() ?? '',
    );

    final db = await _db;
    await db.insert(_tabela, recorde.toMap());
  }

  Future<void> excluir(String id) async {
    final db = await _db;

    await db.delete(
      _tabela,
      where: 'id = ? AND origem = ?',
      whereArgs: [id, OrigemRecordePessoal.manual.name],
    );
  }

  /// Analisa séries concluídas de uma sessão finalizada.
  /// Repetir a operação para a mesma sessão não duplica recordes.
  Future<void> registrarRecordesAutomaticos({
    required String sessaoId,
    required DateTime data,
    required List<Map<String, dynamic>> series,
  }) async {
    if (sessaoId.trim().isEmpty) return;

    final db = await _db;

    await db.transaction((txn) async {
      for (final serie in series) {
        if (serie['concluida'] != true) continue;

        final exercicioId = serie['exercicioId']?.toString().trim() ?? '';
        final nomeExercicio = serie['nomeExercicio']?.toString().trim() ?? '';

        if (exercicioId.isEmpty || nomeExercicio.isEmpty) continue;

        final carga = _numero(serie['cargaKg']);
        final repeticoes = _numero(serie['repeticoesRealizadas']);

        if (carga > 0) {
          await _registrarSeForRecorde(
            txn,
            sessaoId: sessaoId,
            exercicioId: exercicioId,
            nomeExercicio: nomeExercicio,
            tipo: TipoRecordePessoal.cargaMaxima,
            valor: carga,
            unidade: 'kg',
            data: data,
          );
        }

        if (repeticoes > 0) {
          await _registrarSeForRecorde(
            txn,
            sessaoId: sessaoId,
            exercicioId: exercicioId,
            nomeExercicio: nomeExercicio,
            tipo: TipoRecordePessoal.repeticoesMaximas,
            valor: repeticoes,
            unidade: 'repetições',
            data: data,
          );
        }
      }
    });
  }

  Future<void> _registrarSeForRecorde(
    Transaction txn, {
    required String sessaoId,
    required String exercicioId,
    required String nomeExercicio,
    required TipoRecordePessoal tipo,
    required double valor,
    required String unidade,
    required DateTime data,
  }) async {
    final duplicado = await txn.query(
      _tabela,
      columns: ['id'],
      where: '''
        sessao_id = ? AND exercicio_id = ? AND tipo = ?
        AND valor = ? AND origem = ?
      ''',
      whereArgs: [
        sessaoId,
        exercicioId,
        tipo.name,
        valor,
        OrigemRecordePessoal.automatico.name,
      ],
      limit: 1,
    );

    if (duplicado.isNotEmpty) return;

    final anteriores = await txn.rawQuery(
      '''
      SELECT MAX(valor) AS melhor
      FROM $_tabela
      WHERE exercicio_id = ? AND tipo = ?
      ''',
      [exercicioId, tipo.name],
    );

    final melhorAnterior = anteriores.first['melhor'] as num?;

    if (melhorAnterior != null && valor <= melhorAnterior.toDouble()) {
      return;
    }

    final recorde = RecordePessoal(
      id: _novoId(),
      exercicioId: exercicioId,
      nomeExercicio: nomeExercicio,
      tipo: tipo,
      valor: valor,
      unidade: unidade,
      data: data,
      origem: OrigemRecordePessoal.automatico,
      sessaoId: sessaoId,
    );

    await txn.insert(_tabela, recorde.toMap());
  }

  double _numero(dynamic valor) {
    if (valor is num) return valor.toDouble();
    return double.tryParse(valor?.toString() ?? '') ?? 0;
  }
}
