import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import '../dados/workholy_banco.dart';

/// Estado salvo para transformar o contador do sensor (passos desde que o
/// aparelho ligou) em passos do dia.
class ReferenciaPassos {
  const ReferenciaPassos({required this.dia, required this.base});

  final String dia;
  final int base;

  Map<String, Object?> toJson() => {'dia': dia, 'base': base};

  static ReferenciaPassos? fromJson(Object? json) {
    if (json is! Map) return null;
    final dia = json['dia'];
    final base = json['base'];
    if (dia is! String || base is! int) return null;
    return ReferenciaPassos(dia: dia, base: base);
  }
}

class PassosCalculados {
  const PassosCalculados(this.passos, this.referencia);

  final int passos;
  final ReferenciaPassos referencia;
}

String chaveDia(DateTime data) =>
    '${data.year.toString().padLeft(4, '0')}-'
    '${data.month.toString().padLeft(2, '0')}-'
    '${data.day.toString().padLeft(2, '0')}';

/// Os passos do dia contam a partir da primeira leitura do dia: o que foi
/// andado antes disso não é conhecido pelo app. Se o aparelho reiniciou
/// (contador menor que a base), a contagem recomeça do zero do sensor.
PassosCalculados calcularPassosDoDia({
  required int leituraSensor,
  required DateTime agora,
  required ReferenciaPassos? referencia,
}) {
  final hoje = chaveDia(agora);
  var ref = referencia;
  if (ref == null || ref.dia != hoje) {
    ref = ReferenciaPassos(dia: hoje, base: leituraSensor);
  } else if (leituraSensor < ref.base) {
    ref = ReferenciaPassos(dia: hoje, base: 0);
  }
  return PassosCalculados(leituraSensor - ref.base, ref);
}

class PassosDoDia {
  PassosDoDia._();

  static final PassosDoDia instancia = PassosDoDia._();

  static const String _chave = 'workholy_passos_referencia_v1';
  static const String _chaveAtivo = 'workholy_passos_ativo_v1';

  /// null = ainda sem leitura; veja [indisponivel] para o motivo.
  final ValueNotifier<int?> hoje = ValueNotifier<int?>(null);
  final ValueNotifier<String?> indisponivel = ValueNotifier<String?>(null);

  StreamSubscription<StepCount>? _assinatura;
  ReferenciaPassos? _referencia;
  bool _referenciaLida = false;

  bool get ativo => _assinatura != null;

  Future<bool> preferenciaAtiva() async {
    try {
      return await WorkHolyBanco.instancia.lerBooleano(_chaveAtivo) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Liga ou desliga o contador e guarda a escolha.
  Future<void> definirAtivo(bool valor) async {
    try {
      await WorkHolyBanco.instancia.salvarBooleano(_chaveAtivo, valor);
    } catch (erro) {
      debugPrint('Não foi possível salvar a preferência de passos: $erro');
    }
    if (valor) {
      await iniciar();
    } else {
      await parar();
      hoje.value = null;
    }
  }

  Future<void> iniciar() async {
    if (_assinatura != null) return;
    try {
      final status = await Permission.activityRecognition.request();
      if (!status.isGranted) {
        indisponivel.value =
            'Permita o reconhecimento de atividade para contar passos.';
        return;
      }
      if (!_referenciaLida) {
        final texto = await WorkHolyBanco.instancia.lerTexto(_chave);
        _referencia = texto == null
            ? null
            : ReferenciaPassos.fromJson(jsonDecode(texto));
        _referenciaLida = true;
      }
      indisponivel.value = null;
      _assinatura = Pedometer.stepCountStream.listen(
        _aoLer,
        onError: (Object erro) {
          debugPrint('Sensor de passos indisponível: $erro');
          indisponivel.value = 'Este aparelho não tem sensor de passos.';
          unawaited(parar());
        },
      );
    } catch (erro) {
      debugPrint('Falha ao iniciar o contador de passos: $erro');
      indisponivel.value = 'Não foi possível ler o sensor de passos.';
    }
  }

  void _aoLer(StepCount leitura) {
    final r = calcularPassosDoDia(
      leituraSensor: leitura.steps,
      agora: DateTime.now(),
      referencia: _referencia,
    );
    final mudouReferencia =
        _referencia?.dia != r.referencia.dia ||
        _referencia?.base != r.referencia.base;
    _referencia = r.referencia;
    hoje.value = r.passos;
    if (mudouReferencia) {
      unawaited(
        WorkHolyBanco.instancia
            .salvarTexto(_chave, jsonEncode(r.referencia.toJson()))
            .catchError((Object e) => debugPrint('Erro ao salvar passos: $e')),
      );
    }
  }

  Future<void> parar() async {
    await _assinatura?.cancel();
    _assinatura = null;
  }
}
