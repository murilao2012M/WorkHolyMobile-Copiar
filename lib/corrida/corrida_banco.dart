import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Registro imutável de uma corrida que foi concluída.
///
/// É usado pelo painel para somar corridas às demais atividades, sem criar
/// uma sessão de musculação artificial no histórico de treinos.
class CorridaConcluida {
  const CorridaConcluida({
    required this.id,
    required this.inicio,
    required this.fim,
    required this.duracaoSegundos,
    required this.distanciaMetros,
  });

  final String id;
  final DateTime inicio;
  final DateTime fim;
  final int duracaoSegundos;
  final double distanciaMetros;

  factory CorridaConcluida.fromRegistro(Map<String, Object?> registro) {
    final inicioMs = (registro['inicio_ms'] as num?)?.toInt();
    if (inicioMs == null) {
      throw FormatException('A corrida não possui data de início válida.');
    }

    final fimMs = (registro['fim_ms'] as num?)?.toInt();

    return CorridaConcluida(
      id: registro['id']?.toString() ?? '',
      inicio: DateTime.fromMillisecondsSinceEpoch(inicioMs),
      fim: DateTime.fromMillisecondsSinceEpoch(fimMs ?? inicioMs),
      duracaoSegundos: (registro['duracao_segundos'] as num?)?.toInt() ?? 0,
      distanciaMetros: (registro['distancia_metros'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CorridaBanco {
  CorridaBanco._() : _caminhoBanco = null;

  /// Construtor exclusivo para testes com banco separado.
  CorridaBanco.paraTestes({required String caminho}) : _caminhoBanco = caminho;

  static final CorridaBanco instancia = CorridaBanco._();

  final String? _caminhoBanco;

  Database? _db;
  Future<Database> get database async {
    if (_db != null) return _db!;

    final caminho =
        _caminhoBanco ??
        p.join(await getDatabasesPath(), 'workholy_corridas.db');

    _db = await openDatabase(
      caminho,
      version: 1,
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
          )
        ''');
      },
    );

    return _db!;
  }

  Future<void> criar(String id, int inicioMs) async {
    final db = await database;

    await db.insert('corridas', {
      'id': id,
      'inicio_ms': inicioMs,
      'fim_ms': null,
      'duracao_segundos': 0,
      'distancia_metros': 0.0,
      'estado': 'em_andamento',
      'rota_json': '[]',
    });
  }

  /// Remove somente uma sessão que não chegou a ser entregue ao serviço.
  ///
  /// Assim uma falha ao iniciar o serviço em primeiro plano não deixa uma
  /// corrida vazia marcada como em andamento no próximo acesso ao aplicativo.
  Future<void> excluir(String id) async {
    final db = await database;
    await db.delete('corridas', where: 'id = ?', whereArgs: [id]);
  }

  /// Exclui somente uma corrida já concluída.
  ///
  /// Corridas em andamento ou pausadas permanecem protegidas para que uma
  /// ação no histórico não interrompa um registro ativo no GPS.
  Future<bool> excluirFinalizada(String id) async {
    final db = await database;
    final removidas = await db.delete(
      'corridas',
      where: 'id = ? AND estado = ?',
      whereArgs: [id, 'finalizada'],
    );
    return removidas > 0;
  }

  /// Remove somente o histórico de corridas concluídas.
  Future<int> limparFinalizadas() async {
    final db = await database;
    return db.delete(
      'corridas',
      where: 'estado = ?',
      whereArgs: ['finalizada'],
    );
  }

  Future<Map<String, Object?>?> buscar(String id) async {
    final db = await database;

    final rows = await db.query(
      'corridas',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> buscarSessaoAberta() async {
    final db = await database;

    final rows = await db.query(
      'corridas',
      where: 'estado IN (?, ?)',
      whereArgs: ['em_andamento', 'pausada'],
      orderBy: 'inicio_ms DESC',
      limit: 1,
    );

    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> listar() async {
    final db = await database;
    return db.query('corridas', orderBy: 'inicio_ms DESC');
  }

  Future<List<CorridaConcluida>> listarFinalizadas() async {
    final db = await database;
    final registros = await db.query(
      'corridas',
      where: 'estado = ?',
      whereArgs: const ['finalizada'],
      orderBy: 'inicio_ms DESC',
    );

    return registros.map(CorridaConcluida.fromRegistro).toList();
  }

  Future<void> atualizar({
    required String id,
    required int duracaoSegundos,
    required double distanciaMetros,
    required String estado,
    required List<Map<String, double>> rota,
    int? fimMs,
  }) async {
    final db = await database;

    final valores = <String, Object?>{
      'duracao_segundos': duracaoSegundos,
      'distancia_metros': distanciaMetros,
      'estado': estado,
      'rota_json': jsonEncode(rota),
    };

    // Só grava a data de finalização quando ela foi informada.
    if (fimMs != null) {
      valores['fim_ms'] = fimMs;
    }

    await db.update('corridas', valores, where: 'id = ?', whereArgs: [id]);
  }

  List<Map<String, double>> decodificarRota(Object? valor) {
    if (valor is! String || valor.isEmpty) return [];

    try {
      final dados = jsonDecode(valor) as List<dynamic>;

      return dados.whereType<Map<String, dynamic>>().map((ponto) {
        return <String, double>{
          'lat': (ponto['lat'] as num).toDouble(),
          'lon': (ponto['lon'] as num).toDouble(),
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fecha a conexão aberta, principalmente para limpeza dos testes.
  Future<void> fechar() async {
    final db = _db;
    _db = null;

    if (db != null) {
      await db.close();
    }
  }
}
