/// Dados coletados durante o onboarding do WorkFit Personal.
class WorkFitPerfil {
  final String tipoTreino;
  final int minutosPorDia;
  final int diasPorSemana;
  final String objetivo;
  final String equipamento;
  final String experiencia;
  final List<String>? equipamentosDisponiveis;
  final DateTime criadoEm;

  WorkFitPerfil({
    required this.tipoTreino,
    required this.minutosPorDia,
    required this.diasPorSemana,
    required this.objetivo,
    required this.equipamento,
    this.experiencia = 'iniciante',
    this.equipamentosDisponiveis,
    DateTime? criadoEm,
  }) : criadoEm = criadoEm ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'tipoTreino': tipoTreino,
    'minutosPorDia': minutosPorDia,
    'diasPorSemana': diasPorSemana,
    'objetivo': objetivo,
    'equipamento': equipamento,
    'experiencia': experiencia,
    'equipamentosDisponiveis': equipamentosDisponiveis,
    'criadoEm': criadoEm.toIso8601String(),
  };

  factory WorkFitPerfil.fromJson(Map<String, dynamic> json) {
    return WorkFitPerfil(
      tipoTreino: json['tipoTreino']?.toString() ?? 'musculacao',
      minutosPorDia: (json['minutosPorDia'] as num?)?.toInt() ?? 30,
      diasPorSemana: (json['diasPorSemana'] as num?)?.toInt() ?? 4,
      objetivo: json['objetivo']?.toString() ?? 'hipertrofia',
      equipamento: json['equipamento']?.toString() ?? 'academia',
      experiencia: json['experiencia']?.toString() ?? 'iniciante',
      equipamentosDisponiveis: (json['equipamentosDisponiveis'] as List?)
          ?.map((item) => item.toString())
          .toList(),
      criadoEm: json['criadoEm'] is String
          ? DateTime.parse(json['criadoEm'] as String)
          : null,
    );
  }
}

/// Item sugerido no treino WorkFit.
class WorkFitItemExercicio {
  final String nomeExercicio;
  final int series;
  final int repeticoes;
  final double cargaKgPadrao;
  final int descansoSegundos;
  final String grupo;
  final String justificativa;
  final String? exercicioId;

  WorkFitItemExercicio({
    required this.nomeExercicio,
    required this.series,
    required this.repeticoes,
    required this.cargaKgPadrao,
    required this.descansoSegundos,
    required this.grupo,
    this.justificativa = '',
    this.exercicioId,
  });
}

/// Sugestão de treino gerada pelo WorkFit Personal.
class WorkFitSugestao {
  final String nomeTreino;
  final String descricao;
  final List<WorkFitItemExercicio> exercicios;
  final int tempoEstimadoMinutos;
  final WorkFitPerfil? perfil;

  WorkFitSugestao({
    required this.nomeTreino,
    required this.descricao,
    required this.exercicios,
    required this.tempoEstimadoMinutos,
    this.perfil,
  });
}
