import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/workfit/workfit_progressao.dart';

ResultadoSerieWorkFit serie({
  bool concluida = true,
  int planejadas = 8,
  int realizadas = 8,
  double carga = 10,
}) => ResultadoSerieWorkFit(
  concluida: concluida,
  repeticoesPlanejadas: planejadas,
  repeticoesRealizadas: realizadas,
  cargaKg: carga,
);

void main() {
  int? sugerir(List<ResultadoSerieWorkFit> series, {int repeticoes = 8}) =>
      sugerirProximasRepeticoes(
        seriesPlanejadas: 2,
        repeticoesPlanejadas: repeticoes,
        cargaPlanejadaKg: 10,
        seriesRegistradas: series,
      );

  test('sugere uma repetição quando todas as séries atendem ao plano', () {
    expect(sugerir([serie(), serie(realizadas: 9)]), 9);
  });

  test('não sugere com série faltante, incompleta ou abaixo da meta', () {
    expect(sugerir([serie()]), isNull);
    expect(sugerir([serie(), serie(concluida: false)]), isNull);
    expect(sugerir([serie(), serie(realizadas: 7)]), isNull);
  });

  test('não usa registros de carga ou plano diferentes', () {
    expect(sugerir([serie(), serie(carga: 5)]), isNull);
    expect(sugerir([serie(), serie(planejadas: 7)]), isNull);
    expect(sugerir([serie(), serie(carga: double.nan)]), isNull);
  });

  test('não aumenta repetições acima do limite da sugestão', () {
    expect(
      sugerir([
        serie(planejadas: 15, realizadas: 15),
        serie(planejadas: 15, realizadas: 15),
      ], repeticoes: 15),
      isNull,
    );
  });

  test(
    'sugere carga só após duas sessões consistentes com esforço informado',
    () {
      final desempenho = DesempenhoWorkFit(
        series: [serie(), serie()],
        rpe: 7,
        rir: 3,
      );
      final ajuste = sugerirAjusteWorkFit(
        seriesPlanejadas: 2,
        repeticoesPlanejadas: 8,
        cargaPlanejadaKg: 10,
        ultima: desempenho,
        anterior: desempenho,
      );
      expect(ajuste!.tipo, TipoAjusteWorkFit.carga);
      expect(ajuste.cargaKg, 10.5);
      expect(ajuste.repeticoes, 8);
      final semEsforco = DesempenhoWorkFit(
        series: [serie(), serie()],
        rpe: null,
        rir: null,
      );
      expect(
        sugerirAjusteWorkFit(
          seriesPlanejadas: 2,
          repeticoesPlanejadas: 8,
          cargaPlanejadaKg: 10,
          ultima: semEsforco,
          anterior: desempenho,
        ),
        isNull,
      );
    },
  );

  test(
    'esforço alto e fim do ciclo sugerem reduzir séries sem alterar carga',
    () {
      for (final entrada in [(9, 3, false), (7, 1, false), (7, 3, true)]) {
        final ajuste = sugerirAjusteWorkFit(
          seriesPlanejadas: 2,
          repeticoesPlanejadas: 8,
          cargaPlanejadaKg: 10,
          ultima: DesempenhoWorkFit(
            series: [serie(), serie()],
            rpe: entrada.$1,
            rir: entrada.$2,
          ),
          cicloEncerrado: entrada.$3,
        );
        expect(ajuste!.tipo, TipoAjusteWorkFit.recuperacao);
        expect(ajuste.series, 1);
        expect(ajuste.cargaKg, 10);
      }
    },
  );

  test(
    'não progride em fase de base ou revisão nem com desempenho incompleto',
    () {
      final completo = DesempenhoWorkFit(
        series: [serie(), serie()],
        rpe: 7,
        rir: null,
      );
      expect(
        sugerirAjusteWorkFit(
          seriesPlanejadas: 2,
          repeticoesPlanejadas: 8,
          cargaPlanejadaKg: 10,
          ultima: completo,
          permitirProgressao: false,
        ),
        isNull,
      );
      expect(
        sugerirAjusteWorkFit(
          seriesPlanejadas: 2,
          repeticoesPlanejadas: 8,
          cargaPlanejadaKg: 10,
          ultima: DesempenhoWorkFit(
            series: [serie(), serie(concluida: false)],
            rpe: 7,
            rir: 3,
          ),
        ),
        isNull,
      );
    },
  );
}
