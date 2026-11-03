import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../dados/workholy_banco.dart';

/// Fala textos curtos em português do Brasil usando o motor de voz do
/// aparelho (offline). Falhas nunca interrompem o treino: apenas ficam
/// sem voz, e [disponivel] indica o motivo para a tela avisar o usuário.
class VozTreinador {
  VozTreinador._();

  static final VozTreinador instancia = VozTreinador._();

  static const String _chaveAtiva = 'workholy_voz_treinador_v1';

  /// Permite trocar o motor nos testes.
  @visibleForTesting
  static Future<void> Function(String texto)? falarSubstituto;

  FlutterTts? _tts;
  bool _ativa = true;
  bool _preferenciaCarregada = false;
  bool _iniciada = false;
  String? _motivoIndisponivel;
  String? _ultimaFrase;
  DateTime? _ultimaEm;

  bool get ativa => _ativa;
  String? get motivoIndisponivel => _motivoIndisponivel;
  bool get disponivel => _motivoIndisponivel == null;

  Future<void> carregarPreferencia() async {
    if (_preferenciaCarregada) return;
    try {
      _ativa = await WorkHolyBanco.instancia.lerBooleano(_chaveAtiva) ?? true;
    } catch (erro) {
      debugPrint('Não foi possível ler a preferência de voz: $erro');
    }
    _preferenciaCarregada = true;
  }

  Future<void> definirAtiva(bool valor) async {
    _ativa = valor;
    _preferenciaCarregada = true;
    if (!valor) await parar();
    try {
      await WorkHolyBanco.instancia.salvarBooleano(_chaveAtiva, valor);
    } catch (erro) {
      debugPrint('Não foi possível salvar a preferência de voz: $erro');
    }
  }

  Future<void> _iniciar() async {
    if (_iniciada) return;
    _iniciada = true;
    try {
      final tts = FlutterTts();
      final idiomas = await tts.getLanguages;
      final lista = idiomas is List ? idiomas.map((e) => '$e').toList() : [];
      final idioma = lista.firstWhere(
        (e) => e.toLowerCase().replaceAll('_', '-') == 'pt-br',
        orElse: () => '',
      );
      if (idioma.isEmpty) {
        _motivoIndisponivel =
            'O aparelho não tem voz em português do Brasil instalada. '
            'Instale em Configurações > Idioma > Saída de texto para voz.';
        return;
      }
      await tts.setLanguage('pt-BR');
      await tts.setSpeechRate(0.5);
      await tts.setVolume(1.0);
      await tts.awaitSpeakCompletion(false);
      _tts = tts;
    } catch (erro) {
      _motivoIndisponivel = 'A voz não está disponível neste aparelho.';
      debugPrint('Falha ao iniciar a voz: $erro');
    }
  }

  /// Fala [texto]. Frases idênticas em menos de 3 segundos são ignoradas
  /// para evitar repetição quando o estado é reenviado.
  Future<void> falar(String texto, {bool interromper = true}) async {
    await carregarPreferencia();
    if (!_ativa || texto.trim().isEmpty) return;
    final agora = DateTime.now();
    if (_ultimaFrase == texto &&
        _ultimaEm != null &&
        agora.difference(_ultimaEm!) < const Duration(seconds: 3)) {
      return;
    }
    _ultimaFrase = texto;
    _ultimaEm = agora;
    final substituto = falarSubstituto;
    if (substituto != null) {
      await substituto(texto);
      return;
    }
    try {
      await _iniciar();
      final tts = _tts;
      if (tts == null) return;
      if (interromper) await tts.stop();
      await tts.speak(texto);
    } catch (erro) {
      debugPrint('Falha ao falar: $erro');
    }
  }

  Future<void> parar() async {
    try {
      await _tts?.stop();
    } catch (erro) {
      debugPrint('Falha ao parar a voz: $erro');
    }
  }

  /// Testa a voz e devolve uma mensagem de erro se ela não puder falar.
  Future<String?> testar() async {
    await carregarPreferencia();
    final substituto = falarSubstituto;
    if (substituto == null) await _iniciar();
    if (_motivoIndisponivel != null) return _motivoIndisponivel;
    final estava = _ativa;
    _ativa = true;
    _ultimaFrase = null;
    await falar('Olá! Eu sou o seu treinador WorkFit.');
    _ativa = estava;
    return null;
  }
}
