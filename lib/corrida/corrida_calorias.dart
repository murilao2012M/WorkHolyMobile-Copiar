/// Gasto energético a partir da velocidade medida pelo GPS e do peso,
/// usando as equações metabólicas do ACSM para terreno plano.
class CaloriasCorrida {
  const CaloriasCorrida._();

  static const double _caminhadaMaxMetrosPorMinuto = 100;
  static const double _corridaMinMetrosPorMinuto = 134;

  /// Consumo de oxigênio (ml/kg/min) para a velocidade informada.
  /// Até 100 m/min usa a equação de caminhada, a partir de 134 m/min a de
  /// corrida, e entre os dois valores faz a transição linear.
  static double vo2(double velocidadeMetrosPorMinuto) {
    final v = velocidadeMetrosPorMinuto;
    final caminhada = 3.5 + 0.1 * v;
    final corrida = 3.5 + 0.2 * v;

    if (v <= _caminhadaMaxMetrosPorMinuto) return caminhada;
    if (v >= _corridaMinMetrosPorMinuto) return corrida;

    final fracao =
        (v - _caminhadaMaxMetrosPorMinuto) /
        (_corridaMinMetrosPorMinuto - _caminhadaMaxMetrosPorMinuto);
    return caminhada + (corrida - caminhada) * fracao;
  }

  /// Quilocalorias gastas em um intervalo com velocidade média constante.
  static double trecho({
    required double velocidadeMetrosPorSegundo,
    required double intervaloSegundos,
    required double pesoKg,
  }) {
    if (!velocidadeMetrosPorSegundo.isFinite ||
        velocidadeMetrosPorSegundo <= 0 ||
        !intervaloSegundos.isFinite ||
        intervaloSegundos <= 0 ||
        !pesoKg.isFinite ||
        pesoKg <= 0) {
      return 0;
    }

    final kcalPorMinuto = vo2(velocidadeMetrosPorSegundo * 60) * pesoKg / 200;
    return kcalPorMinuto * (intervaloSegundos / 60);
  }
}
