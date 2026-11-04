import 'package:flutter/services.dart';

/// Edição do app definida pelo flavor do build (`--flavor workfit|personal`).
/// Sem flavor (testes, `flutter run` simples) vale a edição WorkFit completa.
class EdicaoApp {
  const EdicaoApp._();

  static const String nome = appFlavor ?? 'workfit';

  static const bool personal = nome == 'personal';

  /// A versão para personal trainers não tem o módulo de corrida.
  static const bool corridaHabilitada = !personal;

  /// Plano inteligente WorkFit (onboarding, ciclos, aprendizado e treino do dia).
  static const bool workfitHabilitado = !personal;

  /// Fotos, vídeos e links anexados pelo personal aos exercícios.
  static const bool midiaHabilitada = personal;
}
