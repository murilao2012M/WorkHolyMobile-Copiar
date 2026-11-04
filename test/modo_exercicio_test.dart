import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/main.dart';
import 'package:workholy_mobile/modo_exercicio.dart';

void main() {
  test('item antigo (sem modo) continua com carga', () {
    final item = ItemTreino.fromJson({
      'id': 'i1',
      'treinoId': 't1',
      'exercicioId': 'e1',
      'series': 3,
      'repeticoes': 10,
      'cargaKg': 20,
      'descansoSegundos': 60,
    });
    expect(item.modo, ModoExercicio.carga);
    expect(item.toJson().containsKey('modo'), isFalse);
  });

  test('item por tempo mantém modo e duração no JSON', () {
    final item = ItemTreino(
      treinoId: 't1',
      exercicioId: 'e1',
      series: 3,
      repeticoes: 1,
      cargaKg: 0,
      descansoSegundos: 30,
      modo: ModoExercicio.tempo,
      duracaoSegundos: 60,
    );
    final volta = ItemTreino.fromJson(item.toJson());
    expect(volta.modo, ModoExercicio.tempo);
    expect(volta.duracaoSegundos, 60);
  });

  test('série por tempo guarda e atualiza a duração realizada', () {
    final serie = SerieExecutada(
      id: 's1',
      exercicioId: 'e1',
      nomeExercicio: 'Corrida',
      numeroSerie: 1,
      repeticoesPlanejadas: 1,
      repeticoesRealizadas: 1,
      cargaKg: 0,
      concluida: false,
      descansoSegundos: 30,
      modo: ModoExercicio.tempo,
      duracaoPlanejadaSegundos: 60,
      duracaoRealizadaSegundos: 60,
    ).copiar(duracaoRealizadaSegundos: 45);
    final volta = SerieExecutada.fromJson(serie.toJson());
    expect(volta.modo, ModoExercicio.tempo);
    expect(volta.duracaoPlanejadaSegundos, 60);
    expect(volta.duracaoRealizadaSegundos, 45);
  });

  test('formata duração curta', () {
    expect(formatarDuracaoCurta(45), '45 s');
    expect(formatarDuracaoCurta(60), '1 min');
    expect(formatarDuracaoCurta(90), '1 min 30 s');
  });
}
