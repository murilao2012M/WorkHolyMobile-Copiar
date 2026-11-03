import 'package:workholy_mobile/workfit/workfit_perfil.dart';

import 'workfit_ciclo.dart';

/// Converte sugestões do WorkFit para modelos do app (Treino + ItemTreino).
///
/// Este adapter:
/// 1. Converte WorkFitSugestao em Treino (com nomes descritivos)
/// 2. Converte WorkFitItemExercicio em ItemTreino
/// 3. Cria Exercicio automaticamente se não existir no catálogo
class WorkFitAdapter {
  /// Converte uma lista de WorkFitSugestao em dados do app.
  ///
  /// Retorna um Map com:
  /// - 'treinos': List<Map> (Treino.toJson())
  /// - 'exercicios': List<Map> (Exercicio.toJson())
  /// - 'itensTreino': List<Map> (ItemTreino.toJson())
  static Map<String, List<Map<String, dynamic>>> converterSugestoes(
    List<WorkFitSugestao> sugestoes,
  ) {
    final treinos = <Map<String, dynamic>>[];
    final exercicios = <Map<String, dynamic>>[];
    final itensTreino = <Map<String, dynamic>>[];
    final exerciciosCriados = <String, String>{}; // nome -> id

    final agora = DateTime.now();
    final timestampBase = agora.microsecondsSinceEpoch;
    final perfil = sugestoes.isEmpty ? null : sugestoes.first.perfil;
    if (sugestoes.any((sugestao) => !identical(sugestao.perfil, perfil))) {
      throw ArgumentError('As sugestões devem pertencer ao mesmo perfil.');
    }
    final ciclo = perfil == null
        ? null
        : WorkFitCiclo(
            id: 'workfit_plano_$timestampBase',
            inicio: agora,
            diasPorSemana: perfil.diasPorSemana,
            modalidade: perfil.tipoTreino,
          );

    for (int i = 0; i < sugestoes.length; i++) {
      final sugestao = sugestoes[i];
      final treinoId = 'workfit_${timestampBase}_$i';

      // Cria o treino
      treinos.add({
        'id': treinoId,
        'nome': sugestao.nomeTreino,
        'objetivo': sugestao.descricao,
        'exercicios': sugestao.exercicios.length,
        if (ciclo != null) 'workfitCiclo': ciclo.toJson(),
      });

      // Processa exercícios
      for (int j = 0; j < sugestao.exercicios.length; j++) {
        final itemEx = sugestao.exercicios[j];

        // Cria exercício se não existe
        String exercicioId;
        final chaveExercicio = itemEx.exercicioId ?? itemEx.nomeExercicio;
        if (exerciciosCriados.containsKey(chaveExercicio)) {
          exercicioId = exerciciosCriados[chaveExercicio]!;
        } else {
          exercicioId =
              'workfit_ex_${timestampBase}_${exerciciosCriados.length}';
          exerciciosCriados[chaveExercicio] = exercicioId;

          exercicios.add({
            'id': exercicioId,
            'nome': itemEx.nomeExercicio,
            'grupo': itemEx.grupo,
            'series': itemEx.series,
            'repeticoes': itemEx.repeticoes,
            if (itemEx.exercicioId != null) 'catalogoId': itemEx.exercicioId,
          });
        }

        // Cria item treino
        itensTreino.add({
          'id': 'workfit_item_${timestampBase}_${i}_$j',
          'treinoId': treinoId,
          'exercicioId': exercicioId,
          'series': itemEx.series,
          'repeticoes': itemEx.repeticoes,
          'cargaKg': itemEx.cargaKgPadrao,
          'descansoSegundos': itemEx.descansoSegundos,
        });
      }
    }

    return {
      'treinos': treinos,
      'exercicios': exercicios,
      'itensTreino': itensTreino,
    };
  }
}
