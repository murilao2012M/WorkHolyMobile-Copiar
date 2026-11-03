import 'package:sqflite/sqflite.dart';

import '../corrida/corrida_banco.dart';
import '../dados/workholy_banco.dart';
import 'backup_nuvem_firestore.dart';
import 'captura_dados_locais.dart';

class ConflitoBackup implements Exception {
  const ConflitoBackup(this.versaoRemota);

  final String? versaoRemota;
}

class BackupLegadoEncontrado implements Exception {
  const BackupLegadoEncontrado();
}

class _Confirmacao {
  const _Confirmacao(this.versao, this.principal, this.corridas);

  final String versao;
  final int principal;
  final int corridas;
}

/// Mantém confirmações fora das tabelas monitoradas pelo contador de alterações.
class CoordenadorBackup {
  CoordenadorBackup({
    required this.uid,
    required this.principal,
    required this.corridas,
    required this.nuvem,
    required this.verificarConta,
  });

  final String uid;
  final WorkHolyBanco principal;
  final CorridaBanco corridas;
  final RepositorioBackupNuvem nuvem;
  final void Function() verificarConta;

  Future<Database> _bancoEstado() async {
    final db = await principal.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workholy_backup_estado (
        uid TEXT PRIMARY KEY NOT NULL,
        versao_remota TEXT NOT NULL,
        versao_principal INTEGER NOT NULL,
        versao_corridas INTEGER NOT NULL
      )
    ''');
    return db;
  }

  Future<_Confirmacao?> _lerConfirmacao() async {
    final db = await _bancoEstado();
    final rows = await db.query(
      'workholy_backup_estado',
      where: 'uid = ?',
      whereArgs: [uid],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    final versao = row['versao_remota'];
    final principal = row['versao_principal'];
    final corridas = row['versao_corridas'];
    if (versao is! String ||
        versao.isEmpty ||
        principal is! int ||
        corridas is! int) {
      throw StateError('Confirmação local de backup inválida.');
    }
    return _Confirmacao(versao, principal, corridas);
  }

  Future<void> _confirmar(String versao, int principal, int corridas) async {
    verificarConta();
    final db = await _bancoEstado();
    await db.insert('workholy_backup_estado', {
      'uid': uid,
      'versao_remota': versao,
      'versao_principal': principal,
      'versao_corridas': corridas,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<DadosLocaisCapturados> _capturar() =>
      CapturaDadosLocais.dosBancos(principal, corridas).capturar();

  Future<void> _verificarLegado() async {
    if (await nuvem.existeBackupLegado()) throw const BackupLegadoEncontrado();
  }

  /// Nunca publica sobre uma versão remota que este aparelho não reconhece.
  Future<void> sincronizar() async {
    verificarConta();
    await _verificarLegado();
    final confirmacao = await _lerConfirmacao();
    final remota = await nuvem.versaoAtual();
    if (remota != confirmacao?.versao) throw ConflitoBackup(remota);
    final snapshot = await _capturar();
    if (confirmacao != null &&
        snapshot.principal.versao == confirmacao.principal &&
        snapshot.corridas.versao == confirmacao.corridas) {
      return;
    }
    await _publicar(snapshot, remota);
  }

  /// Chamado somente após a pessoa escolher os dados deste aparelho.
  Future<void> escolherDadosLocais(String? versaoRemotaConfirmada) async {
    verificarConta();
    await _verificarLegado();
    if (await nuvem.versaoAtual() != versaoRemotaConfirmada) {
      throw ConflitoBackup(await nuvem.versaoAtual());
    }
    final snapshot = await _capturar();
    await _publicar(snapshot, versaoRemotaConfirmada);
  }

  Future<void> _publicar(
    DadosLocaisCapturados snapshot,
    String? versaoRemotaEsperada,
  ) async {
    final novaVersao = await nuvem.guardarVersao(snapshot);
    verificarConta();
    final publicada = await nuvem.publicarVersao(
      novaVersao,
      versaoEsperada: versaoRemotaEsperada,
    );
    if (!publicada) throw ConflitoBackup(await nuvem.versaoAtual());
    await _confirmar(
      novaVersao,
      snapshot.principal.versao,
      snapshot.corridas.versao,
    );
  }

  /// Preserva uma cópia local na nuvem antes de substituir os bancos.
  Future<void> restaurarVersao(String versao, String? remotaConfirmada) async {
    verificarConta();
    await _verificarLegado();
    if (await nuvem.versaoAtual() != remotaConfirmada) {
      throw ConflitoBackup(await nuvem.versaoAtual());
    }
    final local = await _capturar();
    await nuvem.guardarVersao(local);
    final dados = await nuvem.carregarVersao(versao);
    verificarConta();
    if (await nuvem.versaoAtual() != remotaConfirmada) {
      throw ConflitoBackup(await nuvem.versaoAtual());
    }
    final restaurado = await principal.restaurarDadosComCorridas(
      dados: dados.principal,
      corridas: dados.corridas,
      caminhoBancoCorridas: (await corridas.database).path,
      versaoPrincipalEsperada: local.principal.versao,
      versaoCorridasEsperada: local.corridas.versao,
    );
    await _confirmar(versao, restaurado.principal, restaurado.corridas);
    if (versao != remotaConfirmada) {
      final publicada = await nuvem.publicarVersao(
        versao,
        versaoEsperada: remotaConfirmada,
      );
      if (!publicada) throw ConflitoBackup(await nuvem.versaoAtual());
    }
  }
}
