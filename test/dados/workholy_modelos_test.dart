import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/dados/workholy_modelos.dart';

void main() {
  test('Treino preserva favoritos, divisão, agenda e anotações', () {
    final treino = Treino(
      id: 'treino-a',
      nome: 'Superior A',
      objetivo: 'Força',
      grupo: 'A',
      favorito: true,
      diasSemana: const [1, 3, 5, 3, 0],
      anotacoes: 'Priorizar técnica.',
    );

    final decodificado = Treino.fromJson(treino.toJson());

    expect(decodificado.id, 'treino-a');
    expect(decodificado.grupo, 'A');
    expect(decodificado.favorito, isTrue);
    expect(decodificado.diasSemana, [1, 3, 5]);
    expect(decodificado.anotacoes, 'Priorizar técnica.');
  });

  test('Treino legado usa valores padrão para novos campos', () {
    final treino = Treino.fromJson({
      'id': 'treino-antigo',
      'nome': 'Treino antigo',
      'objetivo': '',
    });

    expect(treino.grupo, isEmpty);
    expect(treino.favorito, isFalse);
    expect(treino.diasSemana, isEmpty);
    expect(treino.anotacoes, isEmpty);
  });

  group('SessaoTreino', () {
    test('preserva anotacoes e séries ao serializar', () {
      final sessao = SessaoTreino(
        id: 'sessao-1',
        treinoId: 'treino-1',
        nomeTreino: 'Treino A',
        inicio: DateTime(2026, 11, 7, 9),
        fim: DateTime(2026, 11, 7, 10),
        anotacoes: 'Boa execução',
        series: const [
          SerieExecutada(
            id: 'serie-1',
            exercicioId: 'exercicio-1',
            nomeExercicio: 'Agachamento',
            numeroSerie: 1,
            repeticoesPlanejadas: 10,
            repeticoesRealizadas: 10,
            cargaKg: 20,
            concluida: true,
            descansoSegundos: 90,
            instrucoes: 'Manter o tronco firme.',
            metaCargaKg: 25,
            metaRepeticoes: 12,
          ),
        ],
      );

      final decodificada = SessaoTreino.fromJson(sessao.toJson());

      expect(decodificada.anotacoes, 'Boa execução');
      expect(decodificada.series.single.cargaKg, 20);
      expect(decodificada.series.single.instrucoes, 'Manter o tronco firme.');
      expect(decodificada.series.single.metaCargaKg, 25);
      expect(decodificada.series.single.metaRepeticoes, 12);
      expect(decodificada.finalizada, isTrue);
    });

    test('rejeita data inicial inválida em vez de usar a data atual', () {
      expect(
        () => SessaoTreino.fromJson({
          'id': 'sessao-1',
          'inicio': 'data inválida',
          'series': [],
        }),
        throwsFormatException,
      );
    });

    test('rejeita itens de série com formato inválido', () {
      expect(
        () => SessaoTreino.fromJson({
          'id': 'sessao-1',
          'inicio': '2026-11-07T09:00:00.000',
          'series': ['inválida'],
        }),
        throwsFormatException,
      );
    });
  });

  test('preserva anotacoes e configuracao de peso corporal do exercício', () {
    final exercicio = Exercicio(
      id: 'exercicio-1',
      nome: 'Flexão',
      grupo: 'Peito',
      series: 3,
      repeticoes: 12,
      anotacoes: 'Manter o tronco alinhado',
    );
    final item = ItemTreino(
      id: 'item-1',
      treinoId: 'treino-1',
      exercicioId: 'exercicio-1',
      series: 3,
      repeticoes: 12,
      cargaKg: 0,
      descansoSegundos: 60,
      pesoCorporal: true,
    );

    expect(
      Exercicio.fromJson(exercicio.toJson()).anotacoes,
      'Manter o tronco alinhado',
    );
    expect(ItemTreino.fromJson(item.toJson()).pesoCorporal, isTrue);
  });

  test('ItemTreino preserva instruções e metas planejadas', () {
    final item = ItemTreino(
      id: 'item-1',
      treinoId: 'treino-1',
      exercicioId: 'exercicio-1',
      series: 4,
      repeticoes: 8,
      cargaKg: 50,
      descansoSegundos: 120,
      instrucoes: 'Descer controlando por três segundos.',
      metaCargaKg: 55,
      metaRepeticoes: 10,
    );
    final decodificado = ItemTreino.fromJson(item.toJson());

    expect(decodificado.instrucoes, item.instrucoes);
    expect(decodificado.metaCargaKg, 55);
    expect(decodificado.metaRepeticoes, 10);
  });
}
