import 'workfit_progressao.dart';

enum EstadoLeituraWorkFit { progredir, manter, reduzir, semDados }

/// Leitura de um exercício: o que os dados mostram, por quê, e o ajuste
/// sugerido (se houver). Nunca avalia técnica.
class LeituraWorkFit {
  const LeituraWorkFit({
    required this.estado,
    required this.motivo,
    this.ajuste,
  });

  final EstadoLeituraWorkFit estado;
  final String motivo;
  final AjusteWorkFit? ajuste;
}

double _arredondarMeio(double v) => (v * 2).roundToDouble() / 2;

double _taxaRepeticoes(DesempenhoWorkFit d, int planejadas) {
  if (d.series.isEmpty) return 0;
  var soma = 0;
  for (final s in d.series) {
    if (s.concluida) {
      soma += s.repeticoesRealizadas < planejadas
          ? s.repeticoesRealizadas
          : planejadas;
    }
  }
  return soma / (planejadas * d.series.length);
}

LeituraWorkFit lerExercicioWorkFit({
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
      ultima.series.length != seriesPlanejadas) {
    return const LeituraWorkFit(
      estado: EstadoLeituraWorkFit.semDados,
      motivo: 'As séries registradas não correspondem ao plano do exercício.',
    );
  }

  // Esforço alto ou fim de ciclo têm prioridade: recuperar antes de progredir.
  if (cicloEncerrado || ultima.esforcoAlto) {
    if (seriesPlanejadas == 1) {
      return const LeituraWorkFit(
        estado: EstadoLeituraWorkFit.manter,
        motivo:
            'Esforço alto ou ciclo encerrado, mas só há uma série. Mantido.',
      );
    }
    return LeituraWorkFit(
      estado: EstadoLeituraWorkFit.reduzir,
      motivo: cicloEncerrado
          ? 'O ciclo terminou: uma série a menos ajuda na recuperação.'
          : 'Esforço informado alto: reduzir o volume antes de progredir.',
      ajuste: AjusteWorkFit(
        tipo: TipoAjusteWorkFit.recuperacao,
        series: seriesPlanejadas - 1,
        repeticoes: repeticoesPlanejadas,
        cargaKg: cargaPlanejadaKg,
      ),
    );
  }

  final concluidas = ultima.series.where((s) => s.concluida).toList();
  final todasConcluidas = concluidas.length == seriesPlanejadas;
  final taxa = _taxaRepeticoes(ultima, repeticoesPlanejadas);

  // Desempenho abaixo do plano em duas sessões seguidas: aliviar a carga.
  if (anterior != null &&
      anterior.series.length == seriesPlanejadas &&
      cargaPlanejadaKg > 0 &&
      taxa < 0.7 &&
      _taxaRepeticoes(anterior, repeticoesPlanejadas) < 0.7) {
    final carga = _arredondarMeio(cargaPlanejadaKg * 0.95);
    if (carga < cargaPlanejadaKg && carga > 0) {
      return LeituraWorkFit(
        estado: EstadoLeituraWorkFit.reduzir,
        motivo:
            'Você ficou abaixo das repetições do plano nas duas últimas '
            'sessões. Uma carga um pouco menor ajuda a completar as séries.',
        ajuste: AjusteWorkFit(
          tipo: TipoAjusteWorkFit.carga,
          series: seriesPlanejadas,
          repeticoes: repeticoesPlanejadas,
          cargaKg: carga,
        ),
      );
    }
  }

  if (!todasConcluidas ||
      concluidas.any((s) => s.repeticoesRealizadas < repeticoesPlanejadas)) {
    return const LeituraWorkFit(
      estado: EstadoLeituraWorkFit.manter,
      motivo: 'Nem todas as séries atingiram as repetições do plano. Mantido.',
    );
  }
  if (!permitirProgressao) {
    return const LeituraWorkFit(
      estado: EstadoLeituraWorkFit.manter,
      motivo: 'A fase atual do ciclo ou a configuração não libera progressão.',
    );
  }
  if (exigirEsforco && !ultima.esforcoInformado) {
    return const LeituraWorkFit(
      estado: EstadoLeituraWorkFit.manter,
      motivo:
          'Informe o esforço ao finalizar o treino para liberar progressão.',
    );
  }
  if (!ultima.permiteProgressao) {
    return const LeituraWorkFit(
      estado: EstadoLeituraWorkFit.manter,
      motivo: 'O esforço informado foi moderado a alto. Mantido por segurança.',
    );
  }

  // A carga realmente usada é a menor entre as séries concluídas.
  final cargaReal = concluidas
      .map((s) => s.cargaKg)
      .where((c) => c.isFinite)
      .fold<double?>(null, (m, c) => m == null || c < m ? c : m);
  if (cargaReal == null) {
    return const LeituraWorkFit(
      estado: EstadoLeituraWorkFit.semDados,
      motivo: 'Não há carga válida registrada nas séries.',
    );
  }

  // O plano ficou para trás: você já treina com mais carga que a planejada.
  if (cargaReal > cargaPlanejadaKg) {
    if (cargaPlanejadaKg > 0 && cargaReal > cargaPlanejadaKg * 1.2) {
      return const LeituraWorkFit(
        estado: EstadoLeituraWorkFit.manter,
        motivo:
            'A carga usada ficou muito acima do plano. Confira o registro '
            'antes de ajustar.',
      );
    }
    return LeituraWorkFit(
      estado: EstadoLeituraWorkFit.progredir,
      motivo:
          'Você completou todas as séries com $cargaReal kg, acima do plano. '
          'O plano será atualizado para a carga que você realmente usa.',
      ajuste: AjusteWorkFit(
        tipo: TipoAjusteWorkFit.carga,
        series: seriesPlanejadas,
        repeticoes: repeticoesPlanejadas,
        cargaKg: cargaReal,
      ),
    );
  }

  final ajuste = sugerirAjusteWorkFit(
    seriesPlanejadas: seriesPlanejadas,
    repeticoesPlanejadas: repeticoesPlanejadas,
    cargaPlanejadaKg: cargaPlanejadaKg,
    ultima: ultima,
    anterior: anterior,
    exigirEsforco: exigirEsforco,
    permitirProgressao: permitirProgressao,
  );
  if (ajuste == null) {
    return const LeituraWorkFit(
      estado: EstadoLeituraWorkFit.manter,
      motivo: 'Sem dados suficientes para progredir com segurança.',
    );
  }
  if (ajuste.tipo == TipoAjusteWorkFit.carga) {
    return LeituraWorkFit(
      estado: EstadoLeituraWorkFit.progredir,
      motivo:
          'Duas sessões consistentes com esforço controlado: subir a carga.',
      ajuste: ajuste,
    );
  }
  // Repetições muito acima do plano justificam um passo maior.
  final minimo = concluidas
      .map((s) => s.repeticoesRealizadas)
      .reduce((a, b) => a < b ? a : b);
  final passo = minimo >= repeticoesPlanejadas + 2 ? 2 : 1;
  final novas = (repeticoesPlanejadas + passo).clamp(1, 15);
  return LeituraWorkFit(
    estado: EstadoLeituraWorkFit.progredir,
    motivo: passo == 2
        ? 'Você fez bem mais repetições que o plano: subir duas repetições.'
        : 'Séries completas com esforço controlado: subir uma repetição.',
    ajuste: AjusteWorkFit(
      tipo: TipoAjusteWorkFit.repeticoes,
      series: seriesPlanejadas,
      repeticoes: novas,
      cargaKg: cargaPlanejadaKg,
    ),
  );
}
