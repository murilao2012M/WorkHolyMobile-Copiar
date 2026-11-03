import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'comandos_voz.dart';

/// Escuta um comando por vez, sob demanda (toque no microfone).
/// O reconhecimento é feito pelo serviço de fala do Android, que pode
/// depender de internet e ter dificuldade com barulho.
class EscutaVoz {
  EscutaVoz._();

  static final EscutaVoz instancia = EscutaVoz._();

  final SpeechToText _stt = SpeechToText();
  bool _inicializada = false;

  bool get escutando => _stt.isListening;

  /// Devolve uma mensagem de erro, ou null se estiver pronto.
  Future<String?> preparar() async {
    if (_inicializada) return null;
    try {
      final ok = await _stt.initialize(
        onError: (e) => debugPrint('Erro no reconhecimento: ${e.errorMsg}'),
      );
      if (!ok) {
        return 'Reconhecimento de voz indisponível ou microfone sem permissão.';
      }
      _inicializada = true;
      return null;
    } catch (erro) {
      debugPrint('Falha ao iniciar o reconhecimento: $erro');
      return 'Reconhecimento de voz indisponível neste aparelho.';
    }
  }

  /// Escuta uma frase e chama [aoReconhecer] com o comando, ou com null
  /// se nada foi entendido. Devolve erro de preparo, se houver.
  Future<String?> escutar(
    void Function(ComandoVoz? comando, String texto) aoReconhecer,
  ) async {
    final erro = await preparar();
    if (erro != null) return erro;
    var entregue = false;
    await _stt.listen(
      localeId: 'pt_BR',
      listenFor: const Duration(seconds: 6),
      pauseFor: const Duration(seconds: 2),
      listenOptions: SpeechListenOptions(partialResults: false),
      onResult: (r) {
        if (!r.finalResult || entregue) return;
        entregue = true;
        aoReconhecer(
          interpretarComandoVoz(r.recognizedWords),
          r.recognizedWords,
        );
      },
    );
    return null;
  }

  Future<void> parar() async {
    try {
      await _stt.stop();
    } catch (erro) {
      debugPrint('Falha ao parar a escuta: $erro');
    }
  }
}
