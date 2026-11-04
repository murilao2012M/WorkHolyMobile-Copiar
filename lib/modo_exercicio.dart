/// Como o exercício é prescrito dentro de um treino.
enum ModoExercicio {
  /// Séries, repetições e carga (musculação).
  carga('Repetições com carga'),

  /// Séries e repetições sem carga (ex.: 10 burpees).
  repeticoes('Repetições sem carga'),

  /// Séries de duração fixa (ex.: corrida de 1 minuto).
  tempo('Por tempo');

  final String rotulo;
  const ModoExercicio(this.rotulo);

  static ModoExercicio deNome(Object? nome) {
    for (final m in values) {
      if (m.name == nome) return m;
    }
    return ModoExercicio.carga;
  }
}

String formatarDuracaoCurta(int segundos) {
  if (segundos < 60) return '$segundos s';
  final min = segundos ~/ 60;
  final resto = segundos % 60;
  return resto == 0 ? '$min min' : '$min min $resto s';
}
