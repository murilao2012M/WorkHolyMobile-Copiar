class ResultadoSerieWorkFit {
  const ResultadoSerieWorkFit({
    required this.concluida,
    required this.repeticoesPlanejadas,
    required this.repeticoesRealizadas,
    required this.cargaKg,
  });

  final bool concluida;
  final int repeticoesPlanejadas;
  final int repeticoesRealizadas;
  final double cargaKg;
}

class DesempenhoWorkFit {
  const DesempenhoWorkFit({
    required this.series,
    required this.rpe,
    required this.rir,
  });

  final List<ResultadoSerieWorkFit> series;
  final int? rpe;
  final int? rir;

  bool get esforcoInformado => rpe != null || rir != null;
  bool get esforcoAlto =>
      (rpe != null && rpe! >= 9) || (rir != null && rir! <= 1);
  bool get permiteProgressao =>
      (rpe == null || rpe! <= 7) && (rir == null || rir! >= 3);
}

enum TipoAjusteWorkFit { repeticoes, carga, recuperacao }

class AjusteWorkFit {
  const AjusteWorkFit({
    required this.tipo,
    required this.series,
    required this.repeticoes,
    required this.cargaKg,
  });

  final TipoAjusteWorkFit tipo;
  final int series;
  final int repeticoes;
  final double cargaKg;
}

/// Heurísticas de sugestão; não avaliam técnica nem alteram o treino.
AjusteWorkFit? sugerirAjusteWorkFit({
  required int seriesPlanejadas,
  required int repeticoesPlanejadas,
  required double cargaPlanejadaKg,
  required DesempenhoWorkFit ultima,
  DesempenhoWorkFit? anterior,
  bool cicloEncerrado = false,
  bool exigirEsforco = true,
  bool permitirProgressao = true,
}) {
  if (seriesPlanejadas < 1 ||
      repeticoesPlanejadas < 1 ||
      !cargaPlanejadaKg.isFinite ||
      cargaPlanejadaKg < 0 ||
      ultima.series.length != seriesPlanejadas ||
      ultima.series.any(
        (serie) =>
            serie.repeticoesPlanejadas != repeticoesPlanejadas ||
            serie.cargaKg != cargaPlanejadaKg,
      )) {
    return null;
  }
  if (cicloEncerrado || ultima.esforcoAlto) {
    if (seriesPlanejadas == 1) return null;
    return AjusteWorkFit(
      tipo: TipoAjusteWorkFit.recuperacao,
      series: seriesPlanejadas - 1,
      repeticoes: repeticoesPlanejadas,
      cargaKg: cargaPlanejadaKg,
    );
  }
  if (!permitirProgressao ||
      (exigirEsforco && !ultima.esforcoInformado) ||
      !ultima.permiteProgressao) {
    return null;
  }
  final repeticoes = sugerirProximasRepeticoes(
    seriesPlanejadas: seriesPlanejadas,
    repeticoesPlanejadas: repeticoesPlanejadas,
    cargaPlanejadaKg: cargaPlanejadaKg,
    seriesRegistradas: ultima.series,
  );
  final concluiuMeta = ultima.series.every(
    (serie) =>
        serie.concluida &&
        serie.repeticoesRealizadas >= repeticoesPlanejadas &&
        serie.cargaKg.isFinite,
  );
  if (!concluiuMeta) return null;
  if (anterior != null &&
      anterior.esforcoInformado &&
      anterior.permiteProgressao &&
      cargaPlanejadaKg > 0 &&
      anterior.series.length == seriesPlanejadas &&
      anterior.series.every(
        (serie) =>
            serie.concluida &&
            serie.repeticoesPlanejadas == repeticoesPlanejadas &&
            serie.repeticoesRealizadas >= repeticoesPlanejadas &&
            serie.cargaKg == cargaPlanejadaKg,
      )) {
    final carga = (cargaPlanejadaKg * 1.025 * 2).ceilToDouble() / 2;
    if (carga.isFinite && carga > cargaPlanejadaKg) {
      return AjusteWorkFit(
        tipo: TipoAjusteWorkFit.carga,
        series: seriesPlanejadas,
        repeticoes: repeticoesPlanejadas,
        cargaKg: carga,
      );
    }
  }
  if (repeticoes == null) return null;
  return AjusteWorkFit(
    tipo: TipoAjusteWorkFit.repeticoes,
    series: seriesPlanejadas,
    repeticoes: repeticoes,
    cargaKg: cargaPlanejadaKg,
  );
}

/// Sugere uma repetição adicional, sem alterar carga ou dados do usuário.
int? sugerirProximasRepeticoes({
  required int seriesPlanejadas,
  required int repeticoesPlanejadas,
  required double cargaPlanejadaKg,
  required List<ResultadoSerieWorkFit> seriesRegistradas,
}) {
  if (seriesPlanejadas < 1 ||
      repeticoesPlanejadas < 1 ||
      repeticoesPlanejadas >= 15 ||
      !cargaPlanejadaKg.isFinite ||
      cargaPlanejadaKg < 0 ||
      seriesRegistradas.length != seriesPlanejadas) {
    return null;
  }
  if (seriesRegistradas.any(
    (serie) =>
        !serie.concluida ||
        serie.repeticoesPlanejadas != repeticoesPlanejadas ||
        serie.repeticoesRealizadas < repeticoesPlanejadas ||
        !serie.cargaKg.isFinite ||
        serie.cargaKg != cargaPlanejadaKg,
  )) {
    return null;
  }
  return repeticoesPlanejadas + 1;
}
