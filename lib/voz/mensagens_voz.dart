import '../corrida/plano_corrida.dart';

/// Frases faladas pelo treinador. Funções puras: sem estado e sem plugin,
/// para poderem ser testadas. Só falam o que o app realmente sabe.
class MensagensVoz {
  static String _minutosESegundos(int segundos) {
    final min = segundos ~/ 60;
    final seg = segundos % 60;
    final partes = <String>[];
    if (min > 0) partes.add('$min ${min == 1 ? 'minuto' : 'minutos'}');
    if (seg > 0) partes.add('$seg ${seg == 1 ? 'segundo' : 'segundos'}');
    return partes.isEmpty ? '0 segundo' : partes.join(' e ');
  }

  static String inicioDeBloco(BlocoCorrida bloco) => switch (bloco.tipo) {
    TipoBlocoCorrida.aquecimento =>
      'Aquecimento. Caminhe por ${_minutosESegundos(bloco.segundos)}.',
    TipoBlocoCorrida.corrida =>
      'Corra por ${_minutosESegundos(bloco.segundos)}, em ritmo confortável.',
    TipoBlocoCorrida.caminhada =>
      'Caminhe por ${_minutosESegundos(bloco.segundos)} e recupere o fôlego.',
    TipoBlocoCorrida.desaquecimento =>
      'Desaquecimento. Caminhe devagar por '
          '${_minutosESegundos(bloco.segundos)}.',
  };

  static String planoConcluido() =>
      'Plano concluído. Bom trabalho! Finalize a corrida quando quiser.';

  static String avisoProximoBloco(BlocoCorrida proximo) =>
      'Em dez segundos: ${proximo.tipo.rotulo.toLowerCase()}.';

  /// Ritmo em segundos por km; ignorado se não for plausível.
  static String quilometro(int km, {int? ritmoSegundosPorKm}) {
    final base = km == 1 ? '1 quilômetro' : '$km quilômetros';
    if (ritmoSegundosPorKm == null ||
        ritmoSegundosPorKm < 120 ||
        ritmoSegundosPorKm > 1800) {
      return '$base.';
    }
    final min = ritmoSegundosPorKm ~/ 60;
    final seg = ritmoSegundosPorKm % 60;
    final minTexto = '$min ${min == 1 ? 'minuto' : 'minutos'}';
    final ritmo = seg == 0 ? minTexto : '$minTexto e $seg segundos';
    return '$base. Ritmo médio: $ritmo por quilômetro.';
  }

  static String corridaPausada() => 'Corrida pausada.';
  static String corridaRetomada() => 'Corrida retomada.';
  static String corridaFinalizada() => 'Corrida finalizada.';

  static String exercicioAtual({
    required String nome,
    required int serie,
    required int totalSeries,
    required int repeticoes,
    double? cargaKg,
  }) {
    final carga = cargaKg != null && cargaKg > 0
        ? ', com ${_numero(cargaKg)} quilos'
        : '';
    return '$nome. Série $serie de $totalSeries: $repeticoes '
        'repetições$carga.';
  }

  static String _numero(double v) => v == v.roundToDouble()
      ? v.round().toString()
      : v.toString().replaceAll('.', ',');

  static String descansoIniciado(int segundos) =>
      'Descanse por ${_minutosESegundos(segundos)}.';

  static String descansoTerminando() => 'Faltam 5 segundos de descanso.';

  static String descansoTerminou(String? proximo) => proximo == null
      ? 'Descanso terminado.'
      : 'Descanso terminado. Próximo: $proximo.';

  static String treinoFinalizado() =>
      'Treino finalizado. Parabéns pela dedicação!';
}
