import 'package:flutter/services.dart';

class LembreteTreino {
  const LembreteTreino._();

  static const MethodChannel _canal = MethodChannel(
    'br.com.workholyia.workholy_mobile/lembretes',
  );

  static Future<void> agendar({
    required int diaSemana,
    required int hora,
    required int minuto,
  }) async {
    await _canal.invokeMethod<void>('agendar', {
      'diaSemana': diaSemana,
      'hora': hora,
      'minuto': minuto,
    });
  }

  static Future<void> cancelar() => _canal.invokeMethod<void>('cancelar');
}
