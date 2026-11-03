import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../corrida/corrida_banco.dart';
import '../dados/workholy_banco.dart';
import 'backup_nuvem_firestore.dart';
import 'coordenador_backup.dart';

class TrocaDeContaBloqueada implements Exception {
  const TrocaDeContaBloqueada();
}

void verificarProprietarioLocal(String? donoLocal, String usuarioAtual) {
  if (donoLocal != null && donoLocal != usuarioAtual) {
    throw const TrocaDeContaBloqueada();
  }
}

enum SituacaoBackup {
  desativado,
  pendente,
  enviando,
  concluido,
  conflito,
  legado,
  falhou,
}

class EstadoBackup {
  const EstadoBackup(this.situacao, {this.versaoRemota});

  final SituacaoBackup situacao;
  final String? versaoRemota;
}

class SincronizacaoUsuario {
  SincronizacaoUsuario._();

  static final instancia = SincronizacaoUsuario._();
  static const habilitado = bool.fromEnvironment(
    'WORKHOLY_BACKUP_EXPERIMENTAL',
    defaultValue: false,
  );
  static const chaveAtivado = '_workholy_backup_ativado_v1';
  final ValueNotifier<EstadoBackup> estado = ValueNotifier(
    const EstadoBackup(SituacaoBackup.desativado),
  );
  Timer? _timer;
  Timer? _repeticao;
  String? _uid;
  bool _ativado = false;
  bool _executando = false;
  bool _novoEnvioSolicitado = false;
  BackupNuvemFirestore? _nuvem;
  CoordenadorBackup? _coordenador;

  Future<void> prepararConta(User usuario) async {
    final banco = WorkHolyBanco.instancia;
    final donoLocal = await banco.lerTexto(
      WorkHolyBanco.chaveUsuarioSincronizado,
    );
    verificarProprietarioLocal(donoLocal, usuario.uid);
    if (donoLocal == null) {
      await banco.salvarTexto(
        WorkHolyBanco.chaveUsuarioSincronizado,
        usuario.uid,
      );
    }
    if (_uid != usuario.uid) parar();
    _uid = usuario.uid;
    _nuvem = BackupNuvemFirestore(
      firestore: FirebaseFirestore.instance,
      uid: usuario.uid,
    );
    _coordenador = CoordenadorBackup(
      uid: usuario.uid,
      principal: banco,
      corridas: CorridaBanco.instancia,
      nuvem: _nuvem!,
      verificarConta: _verificarConta,
    );
    _ativado = habilitado && (await banco.lerBooleano(chaveAtivado) ?? false);
    estado.value = EstadoBackup(
      _ativado ? SituacaoBackup.pendente : SituacaoBackup.desativado,
    );
    if (_ativado) _iniciarTentativas();
  }

  void _verificarConta() {
    if (_uid == null || FirebaseAuth.instance.currentUser?.uid != _uid) {
      throw StateError('A conta autenticada mudou durante o backup.');
    }
  }

  Future<void> ativar() async {
    if (!habilitado) {
      throw StateError('O backup ainda não está liberado nesta versão.');
    }
    _verificarConta();
    await WorkHolyBanco.instancia.salvarBooleano(chaveAtivado, true);
    _ativado = true;
    _iniciarTentativas();
    await sincronizarAgora();
  }

  void _iniciarTentativas() {
    _repeticao?.cancel();
    _repeticao = Timer.periodic(
      const Duration(minutes: 1),
      (_) => agendarEnvio(),
    );
    agendarEnvio();
  }

  void agendarEnvio() {
    if (!_ativado || _coordenador == null) return;
    if (estado.value.situacao == SituacaoBackup.conflito ||
        estado.value.situacao == SituacaoBackup.legado) {
      return;
    }
    if (_executando) {
      _novoEnvioSolicitado = true;
      return;
    }
    estado.value = const EstadoBackup(SituacaoBackup.pendente);
    _timer?.cancel();
    _timer = Timer(
      const Duration(seconds: 5),
      () => unawaited(_tentarAutomatico()),
    );
  }

  Future<void> _tentarAutomatico() async {
    try {
      await sincronizarAgora();
    } catch (erro, stackTrace) {
      debugPrint('Tentativa automática de backup não concluída: $erro');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> sincronizarAgora() async {
    if (!_ativado || _coordenador == null) {
      throw StateError('O backup na nuvem não está ativado.');
    }
    await _executar(() => _coordenador!.sincronizar());
  }

  Future<void> escolherDadosLocais(String? versaoRemota) async {
    final coordenador = _coordenador;
    if (!_ativado || coordenador == null) {
      throw StateError('Backup não ativado.');
    }
    await _executar(() => coordenador.escolherDadosLocais(versaoRemota));
  }

  Future<List<({String id, DateTime criadaEm})>> listarVersoes() async {
    _verificarConta();
    final nuvem = _nuvem;
    if (!_ativado || nuvem == null) throw StateError('Backup não ativado.');
    return nuvem.listarVersoes();
  }

  Future<String?> versaoAtual() async {
    _verificarConta();
    final nuvem = _nuvem;
    if (!_ativado || nuvem == null) throw StateError('Backup não ativado.');
    return nuvem.versaoAtual();
  }

  Future<void> restaurarVersao(String versao, String? remotaConfirmada) async {
    final coordenador = _coordenador;
    if (!_ativado || coordenador == null) {
      throw StateError('Backup não ativado.');
    }
    await _executar(
      () => coordenador.restaurarVersao(versao, remotaConfirmada),
    );
  }

  Future<void> _executar(Future<void> Function() operacao) async {
    _verificarConta();
    if (_executando) {
      throw StateError('Outra operação de backup está em andamento.');
    }
    _timer?.cancel();
    _executando = true;
    estado.value = const EstadoBackup(SituacaoBackup.enviando);
    try {
      await operacao();
      _verificarConta();
      estado.value = const EstadoBackup(SituacaoBackup.concluido);
    } on ConflitoBackup catch (erro) {
      estado.value = EstadoBackup(
        SituacaoBackup.conflito,
        versaoRemota: erro.versaoRemota,
      );
      rethrow;
    } on BackupLegadoEncontrado {
      estado.value = const EstadoBackup(SituacaoBackup.legado);
      rethrow;
    } catch (erro, stackTrace) {
      debugPrint('Erro no backup: $erro');
      debugPrintStack(stackTrace: stackTrace);
      estado.value = const EstadoBackup(SituacaoBackup.falhou);
      rethrow;
    } finally {
      _executando = false;
      if (_novoEnvioSolicitado) {
        _novoEnvioSolicitado = false;
        agendarEnvio();
      }
    }
  }

  void parar() {
    _timer?.cancel();
    _repeticao?.cancel();
    _uid = null;
    _ativado = false;
    _nuvem = null;
    _coordenador = null;
    _novoEnvioSolicitado = false;
    estado.value = const EstadoBackup(SituacaoBackup.desativado);
  }
}
