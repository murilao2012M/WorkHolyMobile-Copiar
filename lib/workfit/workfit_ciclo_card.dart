import 'package:flutter/material.dart';

import 'workfit_ciclo.dart';

class WorkFitCicloCard extends StatelessWidget {
  const WorkFitCicloCard({
    super.key,
    required this.ciclo,
    required this.sessoes,
    this.agora,
    this.dadosDisponiveis = true,
    this.temCorrida = false,
    this.ultimoRpeCorrida,
  });

  final WorkFitCiclo ciclo;
  final List<DiaConcluidoWorkFit> sessoes;
  final DateTime? agora;
  final bool dadosDisponiveis;
  final bool temCorrida;
  final int? ultimoRpeCorrida;

  @override
  Widget build(BuildContext context) {
    final estado = avaliarCicloWorkFit(ciclo, agora ?? DateTime.now(), sessoes);
    if (estado.naoIniciado) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text('O ciclo ainda não começou. Confira a data do aparelho.'),
        ),
      );
    }
    final corrida = ciclo.modalidade == 'corrida';
    final baixaAderencia =
        estado.diasSemanaConcluida != null &&
        estado.diasSemanaConcluida! * 5 < estado.metaSemanal * 4;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!dadosDisponiveis)
              const Text(
                'A aderência está indisponível: não foi possível carregar as corridas.',
              )
            else ...[
              Text(
                estado.encerrado
                    ? 'Ciclo de 4 semanas encerrado'
                    : 'Ciclo WorkFit • semana ${estado.semana} de 4',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                estado.encerrado
                    ? 'Revise os resultados e considere uma etapa de recuperação antes de criar um novo ciclo.'
                    : switch (estado.semana) {
                        1 => 'Fase de base: conheça e registre seus treinos.',
                        2 || 3 => 'Fase de progressão: revise as sugestões com base no que foi registrado.',
                        _ => 'Fase de revisão: compare o realizado com o planejado.',
                      },
              ),
              const SizedBox(height: 8),
              Text(
                '${estado.diasConcluidos} de ${estado.metaSemanal} dias '
                'com ${corrida ? 'corrida vinculada' : 'treino'} '
                'concluído nesta semana do ciclo.',
              ),
              if (estado.semanaConcluida != null)
                Text(
                  'Semana ${estado.semanaConcluida}: '
                  '${estado.diasSemanaConcluida} de ${estado.metaSemanal} dias.',
                ),
              if (baixaAderencia)
                const Text(
                  'A frequência ficou abaixo de 80% na última semana completa. '
                  'Considere revisar a meta com um profissional.',
                ),
              if (corrida && temCorrida && ultimoRpeCorrida == null)
                const Text(
                  'Registre o RPE no histórico da corrida para acompanhar o esforço.',
                ),
              if (corrida && ultimoRpeCorrida != null)
                Text(
                  ultimoRpeCorrida! >= 9
                      ? 'Último RPE: $ultimoRpeCorrida. Considere uma próxima atividade mais leve e revise o plano.'
                      : 'Último RPE: $ultimoRpeCorrida. Compare os registros antes de ajustar o plano.',
                ),
            ],
          ],
        ),
      ),
    );
  }
}
