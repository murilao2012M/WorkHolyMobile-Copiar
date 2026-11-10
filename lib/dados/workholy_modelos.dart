import '../workfit/workfit_ciclo.dart';

int _contadorIds = 0;

String novoId(String prefixo) {
  _contadorIds++;
  return '$prefixo-${DateTime.now().microsecondsSinceEpoch}-$_contadorIds';
}

// ============================================================
// MODELOS
// ============================================================

class Treino {
  final String id;
  final String nome;
  final String objetivo;
  final String grupo;
  final bool favorito;
  final List<int> diasSemana;
  final String anotacoes;

  // Campo mantido para compatibilidade com os dados antigos.
  final int exercicios;
  final WorkFitCiclo? workfitCiclo;

  Treino({
    String? id,
    required this.nome,
    required this.objetivo,
    this.grupo = '',
    this.favorito = false,
    List<int> diasSemana = const [],
    this.anotacoes = '',
    this.exercicios = 0,
    this.workfitCiclo,
  }) : id = id ?? novoId('treino'),
       diasSemana = List<int>.unmodifiable(
         diasSemana.where((dia) => dia >= 1 && dia <= 7).toSet().toList()
           ..sort(),
       );

  Treino copiar({
    String? id,
    String? nome,
    String? objetivo,
    String? grupo,
    bool? favorito,
    List<int>? diasSemana,
    String? anotacoes,
    int? exercicios,
    WorkFitCiclo? workfitCiclo,
  }) => Treino(
    id: id ?? this.id,
    nome: nome ?? this.nome,
    objetivo: objetivo ?? this.objetivo,
    grupo: grupo ?? this.grupo,
    favorito: favorito ?? this.favorito,
    diasSemana: diasSemana ?? this.diasSemana,
    anotacoes: anotacoes ?? this.anotacoes,
    exercicios: exercicios ?? this.exercicios,
    workfitCiclo: workfitCiclo ?? this.workfitCiclo,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'objetivo': objetivo,
    'grupo': grupo,
    'favorito': favorito,
    'diasSemana': diasSemana,
    'anotacoes': anotacoes,
    'exercicios': exercicios,
    if (workfitCiclo != null) 'workfitCiclo': workfitCiclo!.toJson(),
  };

  factory Treino.fromJson(Map<String, dynamic> json) {
    return Treino(
      id: json['id'] is String ? json['id'] as String : null,
      nome: json['nome']?.toString() ?? 'Treino sem nome',
      objetivo: json['objetivo']?.toString() ?? '',
      grupo: json['grupo']?.toString() ?? '',
      favorito: json['favorito'] == true,
      diasSemana: json['diasSemana'] is List
          ? (json['diasSemana'] as List)
                .whereType<num>()
                .map((dia) => dia.toInt())
                .where((dia) => dia >= 1 && dia <= 7)
                .toSet()
                .toList()
          : const [],
      anotacoes: json['anotacoes']?.toString() ?? '',
      exercicios: (json['exercicios'] as num?)?.toInt() ?? 0,
      workfitCiclo: json['workfitCiclo'] == null
          ? null
          : WorkFitCiclo.fromJson(
              Map<String, dynamic>.from(json['workfitCiclo'] as Map),
            ),
    );
  }
}

class Exercicio {
  final String id;
  final String nome;
  final String grupo;
  final int series;
  final int repeticoes;
  final String anotacoes;
  final String? catalogoId;

  Exercicio({
    String? id,
    required this.nome,
    required this.grupo,
    required this.series,
    required this.repeticoes,
    this.anotacoes = '',
    this.catalogoId,
  }) : id = id ?? novoId('exercicio');

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'grupo': grupo,
    'series': series,
    'repeticoes': repeticoes,
    'anotacoes': anotacoes,
    if (catalogoId != null) 'catalogoId': catalogoId,
  };

  factory Exercicio.fromJson(Map<String, dynamic> json) {
    return Exercicio(
      id: json['id'] is String ? json['id'] as String : null,
      nome: json['nome']?.toString() ?? 'Exercício sem nome',
      grupo: json['grupo']?.toString() ?? 'Outros',
      series: (json['series'] as num?)?.toInt() ?? 3,
      repeticoes: (json['repeticoes'] as num?)?.toInt() ?? 12,
      anotacoes: json['anotacoes']?.toString() ?? '',
      catalogoId: json['catalogoId'] as String?,
    );
  }
}

/// Representa um exercício associado a um treino específico.
/// A configuração é independente da configuração do cadastro geral.
class ItemTreino {
  final String id;
  final String treinoId;
  final String exercicioId;
  final int series;
  final int repeticoes;
  final double cargaKg;
  final int descansoSegundos;
  final bool pesoCorporal;
  final String instrucoes;
  final double? metaCargaKg;
  final int? metaRepeticoes;
  final bool progressaoAtiva;
  final String? workfitUltimaSessaoAjustada;
  final String? workfitCicloRecuperado;

  ItemTreino({
    String? id,
    required this.treinoId,
    required this.exercicioId,
    required this.series,
    required this.repeticoes,
    required this.cargaKg,
    required this.descansoSegundos,
    this.pesoCorporal = false,
    this.instrucoes = '',
    this.metaCargaKg,
    this.metaRepeticoes,
    this.progressaoAtiva = true,
    this.workfitUltimaSessaoAjustada,
    this.workfitCicloRecuperado,
  }) : id = id ?? novoId('item');

  Map<String, dynamic> toJson() => {
    'id': id,
    'treinoId': treinoId,
    'exercicioId': exercicioId,
    'series': series,
    'repeticoes': repeticoes,
    'cargaKg': cargaKg,
    'descansoSegundos': descansoSegundos,
    'pesoCorporal': pesoCorporal,
    'instrucoes': instrucoes,
    'metaCargaKg': metaCargaKg,
    'metaRepeticoes': metaRepeticoes,
    'progressaoAtiva': progressaoAtiva,
    if (workfitUltimaSessaoAjustada != null)
      'workfitUltimaSessaoAjustada': workfitUltimaSessaoAjustada,
    if (workfitCicloRecuperado != null)
      'workfitCicloRecuperado': workfitCicloRecuperado,
  };

  factory ItemTreino.fromJson(Map<String, dynamic> json) {
    return ItemTreino(
      id: json['id'] is String ? json['id'] as String : null,
      treinoId: json['treinoId']?.toString() ?? '',
      exercicioId: json['exercicioId']?.toString() ?? '',
      series: (json['series'] as num?)?.toInt() ?? 3,
      repeticoes: (json['repeticoes'] as num?)?.toInt() ?? 12,
      cargaKg: (json['cargaKg'] as num?)?.toDouble() ?? 0,
      descansoSegundos: (json['descansoSegundos'] as num?)?.toInt() ?? 90,
      pesoCorporal: json['pesoCorporal'] == true,
      instrucoes: json['instrucoes']?.toString() ?? '',
      metaCargaKg: (json['metaCargaKg'] as num?)?.toDouble(),
      metaRepeticoes: (json['metaRepeticoes'] as num?)?.toInt(),
      progressaoAtiva: json['progressaoAtiva'] as bool? ?? true,
      workfitUltimaSessaoAjustada:
          json['workfitUltimaSessaoAjustada'] as String?,
      workfitCicloRecuperado: json['workfitCicloRecuperado'] as String?,
    );
  }
}

class SerieExecutada {
  final String id;
  final String exercicioId;
  final String nomeExercicio;
  final int numeroSerie;
  final int repeticoesPlanejadas;
  final int repeticoesRealizadas;
  final double cargaKg;
  final bool concluida;
  final int descansoSegundos;
  final bool pesoCorporal;
  final String instrucoes;
  final double? metaCargaKg;
  final int? metaRepeticoes;
  final String? catalogoId;

  const SerieExecutada({
    required this.id,
    required this.exercicioId,
    required this.nomeExercicio,
    required this.numeroSerie,
    required this.repeticoesPlanejadas,
    required this.repeticoesRealizadas,
    required this.cargaKg,
    required this.concluida,
    required this.descansoSegundos,
    this.pesoCorporal = false,
    this.instrucoes = '',
    this.metaCargaKg,
    this.metaRepeticoes,
    this.catalogoId,
  });

  SerieExecutada copiar({
    int? repeticoesRealizadas,
    double? cargaKg,
    bool? concluida,
    bool? pesoCorporal,
    String? catalogoId,
  }) {
    return SerieExecutada(
      id: id,
      exercicioId: exercicioId,
      nomeExercicio: nomeExercicio,
      numeroSerie: numeroSerie,
      repeticoesPlanejadas: repeticoesPlanejadas,
      repeticoesRealizadas: repeticoesRealizadas ?? this.repeticoesRealizadas,
      cargaKg: cargaKg ?? this.cargaKg,
      concluida: concluida ?? this.concluida,
      descansoSegundos: descansoSegundos,
      pesoCorporal: pesoCorporal ?? this.pesoCorporal,
      instrucoes: instrucoes,
      metaCargaKg: metaCargaKg,
      metaRepeticoes: metaRepeticoes,
      catalogoId: catalogoId ?? this.catalogoId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'exercicioId': exercicioId,
    'nomeExercicio': nomeExercicio,
    'numeroSerie': numeroSerie,
    'repeticoesPlanejadas': repeticoesPlanejadas,
    'repeticoesRealizadas': repeticoesRealizadas,
    'cargaKg': cargaKg,
    'concluida': concluida,
    'descansoSegundos': descansoSegundos,
    'pesoCorporal': pesoCorporal,
    'instrucoes': instrucoes,
    'metaCargaKg': metaCargaKg,
    'metaRepeticoes': metaRepeticoes,
    if (catalogoId != null) 'catalogoId': catalogoId,
  };

  factory SerieExecutada.fromJson(Map<String, dynamic> json) {
    return SerieExecutada(
      id: json['id']?.toString() ?? novoId('serie'),
      exercicioId: json['exercicioId']?.toString() ?? '',
      nomeExercicio: json['nomeExercicio']?.toString() ?? 'Exercício',
      numeroSerie: (json['numeroSerie'] as num?)?.toInt() ?? 1,
      repeticoesPlanejadas:
          (json['repeticoesPlanejadas'] as num?)?.toInt() ?? 0,
      repeticoesRealizadas:
          (json['repeticoesRealizadas'] as num?)?.toInt() ?? 0,
      cargaKg: (json['cargaKg'] as num?)?.toDouble() ?? 0,
      concluida: json['concluida'] == true,
      descansoSegundos: (json['descansoSegundos'] as num?)?.toInt() ?? 90,
      pesoCorporal: json['pesoCorporal'] == true,
      instrucoes: json['instrucoes']?.toString() ?? '',
      metaCargaKg: (json['metaCargaKg'] as num?)?.toDouble(),
      metaRepeticoes: (json['metaRepeticoes'] as num?)?.toInt(),
      catalogoId: json['catalogoId'] as String?,
    );
  }
}

class SessaoTreino {
  final String id;
  final String treinoId;
  final String nomeTreino;
  final DateTime inicio;
  final DateTime? fim;
  final List<SerieExecutada> series;
  final String anotacoes;
  final String? alunoId;
  final String? workfitPlanoId;
  final int? rpe;
  final int? rir;

  const SessaoTreino({
    required this.id,
    required this.treinoId,
    required this.nomeTreino,
    required this.inicio,
    required this.fim,
    required this.series,
    this.anotacoes = '',
    this.alunoId,
    this.workfitPlanoId,
    this.rpe,
    this.rir,
  });

  bool get finalizada => fim != null;

  int get seriesConcluidas => series.where((serie) => serie.concluida).length;

  SessaoTreino copiar({
    DateTime? fim,
    bool limparFim = false,
    List<SerieExecutada>? series,
    String? anotacoes,
    String? alunoId,
    int? rpe,
    int? rir,
  }) {
    return SessaoTreino(
      id: id,
      treinoId: treinoId,
      nomeTreino: nomeTreino,
      inicio: inicio,
      fim: limparFim ? null : (fim ?? this.fim),
      series: series ?? List<SerieExecutada>.from(this.series),
      anotacoes: anotacoes ?? this.anotacoes,
      alunoId: alunoId ?? this.alunoId,
      workfitPlanoId: workfitPlanoId,
      rpe: rpe ?? this.rpe,
      rir: rir ?? this.rir,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'treinoId': treinoId,
    'nomeTreino': nomeTreino,
    'inicio': inicio.toIso8601String(),
    'fim': fim?.toIso8601String(),
    'series': series.map((serie) => serie.toJson()).toList(),
    'anotacoes': anotacoes,
    'alunoId': alunoId,
    if (workfitPlanoId != null) 'workfitPlanoId': workfitPlanoId,
    if (rpe != null) 'rpe': rpe,
    if (rir != null) 'rir': rir,
  };

  factory SessaoTreino.fromJson(Map<String, dynamic> json) {
    final inicioTexto = json['inicio']?.toString();
    final inicio = inicioTexto == null ? null : DateTime.tryParse(inicioTexto);
    if (inicio == null) {
      throw const FormatException('Sessão sem data de início válida.');
    }

    final fimTexto = json['fim']?.toString();
    final fim = fimTexto == null ? null : DateTime.tryParse(fimTexto);
    if (fimTexto != null && fim == null) {
      throw const FormatException('Sessão com data de término inválida.');
    }

    final valorSeries = json['series'];
    if (valorSeries is! List) {
      throw const FormatException('Sessão sem lista de séries válida.');
    }

    final dadosSeries = valorSeries.map((item) {
      if (item is! Map) {
        throw const FormatException('Série com estrutura inválida.');
      }
      return SerieExecutada.fromJson(Map<String, dynamic>.from(item));
    }).toList();
    final rpe = json['rpe'];
    final rir = json['rir'];
    if ((rpe != null && (rpe is! int || rpe < 1 || rpe > 10)) ||
        (rir != null && (rir is! int || rir < 0 || rir > 10))) {
      throw const FormatException('Esforço da sessão inválido.');
    }

    return SessaoTreino(
      id: json['id']?.toString() ?? novoId('sessao'),
      treinoId: json['treinoId']?.toString() ?? '',
      nomeTreino: json['nomeTreino']?.toString() ?? 'Treino',
      inicio: inicio,
      fim: fim,
      series: dadosSeries,
      anotacoes: json['anotacoes']?.toString() ?? '',
      alunoId: json['alunoId']?.toString(),
      workfitPlanoId: json['workfitPlanoId'] as String?,
      rpe: rpe as int?,
      rir: rir as int?,
    );
  }
}
