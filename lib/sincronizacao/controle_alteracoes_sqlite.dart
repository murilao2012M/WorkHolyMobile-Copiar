import 'package:sqflite/sqflite.dart';

class SnapshotLocal<T> {
  const SnapshotLocal({required this.versao, required this.dados});

  final int versao;
  final T dados;
}

/// Contador transacional local. Não indica, por si só, que o backup foi feito.
class ControleAlteracoesSqlite {
  static const _tabela = 'workholy_controle_alteracoes';

  static Future<void> criar(DatabaseExecutor db, List<String> tabelas) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tabela (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        versao INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'INSERT OR IGNORE INTO $_tabela (id, versao) VALUES (1, 1)',
    );
    for (final tabela in tabelas) {
      for (final operacao in ['INSERT', 'UPDATE', 'DELETE']) {
        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS sync_${tabela}_${operacao.toLowerCase()}
          AFTER $operacao ON $tabela
          BEGIN
            UPDATE $_tabela SET versao = versao + 1 WHERE id = 1;
          END
        ''');
      }
    }
  }

  static Future<int> ler(DatabaseExecutor db) async {
    final linhas = await db.query(
      _tabela,
      columns: ['versao'],
      where: 'id = ?',
      whereArgs: [1],
    );
    if (linhas.length != 1 || linhas.single['versao'] is! int) {
      throw StateError('Controle local de alterações inválido.');
    }
    return linhas.single['versao']! as int;
  }
}
