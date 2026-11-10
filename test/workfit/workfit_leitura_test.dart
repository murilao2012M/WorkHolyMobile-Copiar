import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/workfit/workfit_leitura.dart';
import 'package:workholy_mobile/workfit/workfit_progressao.dart';

DesempenhoWorkFit desempenho({
  int series = 3,
  int planejadas = 10,
  int realizadas = 10,
  double carga = 20,
  bool concluida = true,
  int? rpe = 7,
}) => DesempenhoWorkFit(
  rpe: rpe,
  rir: null,
  series: [
    for (var i = 0; i < series; i++)
      ResultadoSerieWorkFit(
        concluida: concluida,
        repeticoesPlanejadas: planejadas,
        repeticoesRealizadas: realizadas,
        cargaKg: carga,
      ),
  ],
);

LeituraWorkFit ler(
  DesempenhoWorkFit ultima, {
  DesempenhoWorkFit? anterior,
  double carga = 20,
}) => lerExercicioWorkFit(
  seriesPlanejadas: 3,
  repeticoesPlanejadas: 10,
  cargaPlanejadaKg: carga,
  ultima: ultima,
  anterior: anterior,
);

void main() {
  test('séries completas sobem uma repetição', () {
    final l = ler(desempenho());
    expect(l.estado, EstadoLeituraWorkFit.progredir);
    expect(l.ajuste!.repeticoes, 11);
  });

  test('repetições bem acima do plano sobem duas', () {
    final l = ler(desempenho(realizadas: 12));
    expect(l.ajuste!.repeticoes, 12);
  });

  test('carga real acima do plano atualiza o plano', () {
    final l = ler(desempenho(carga: 22.5));
    expect(l.ajuste!.tipo, TipoAjusteWorkFit.carga);
    expect(l.ajuste!.cargaKg, 22.5);
  });

  test('carga absurdamente acima do plano não é aplicada', () {
    final l = ler(desempenho(carga: 60));
    expect(l.ajuste, isNull);
    expect(l.estado, EstadoLeituraWorkFit.manter);
  });

  test('duas sessões abaixo do plano reduzem a carga', () {
    final fraca = desempenho(realizadas: 5);
    final l = ler(fraca, anterior: fraca);
    expect(l.estado, EstadoLeituraWorkFit.reduzir);
    expect(l.ajuste!.cargaKg, lessThan(20));
  });

  test('uma sessão fraca só mantém, com motivo', () {
    final l = ler(desempenho(realizadas: 5));
    expect(l.ajuste, isNull);
    expect(l.motivo, isNotEmpty);
  });

  test('esforço alto reduz série e esforço ausente não progride', () {
    expect(ler(desempenho(rpe: 9)).ajuste!.tipo, TipoAjusteWorkFit.recuperacao);
    final l = ler(desempenho(rpe: null));
    expect(l.ajuste, isNull);
    expect(l.motivo, contains('esforço'));
  });

  test('séries diferentes do plano não têm dados', () {
    expect(ler(desempenho(series: 2)).estado, EstadoLeituraWorkFit.semDados);
  });
}
