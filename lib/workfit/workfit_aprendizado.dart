import 'dart:math';

import 'workfit_modelo.dart';
import 'workfit_motor.dart';

/// Série executada, reduzida ao que o aprendizado precisa.
class SerieAprendizado {
  const SerieAprendizado({
    required this.catalogoId,
    required this.nome,
    required this.concluida,
  });

  final String? catalogoId;
  final String nome;
  final bool concluida;
}

/// Sessão finalizada, reduzida ao que o aprendizado precisa.
class SessaoAprendizado {
  const SessaoAprendizado({required this.fim, required this.series, this.rpe});

  final DateTime fim;
  final List<SerieAprendizado> series;
  final int? rpe;
}

/// Exercício do catálogo retirado pelo cliente de um treino do WorkFit.
class RemocaoAprendizado {
  const RemocaoAprendizado({required this.catalogoId, required this.em});

  final String catalogoId;
  final DateTime em;

  Map<String, dynamic> toJson() => {
    'catalogoId': catalogoId,
    'em': em.toIso8601String(),
  };

  static RemocaoAprendizado? tentarLer(Object? dado) {
    if (dado is! Map) return null;
    final id = dado['catalogoId']?.toString() ?? '';
    final em = DateTime.tryParse(dado['em']?.toString() ?? '');
    if (id.isEmpty || em == null) return null;
    return RemocaoAprendizado(catalogoId: id, em: em);
  }
}

class EstatisticaExercicio {
  const EstatisticaExercicio({
    required this.catalogoId,
    required this.nome,
    required this.sessoes,
    required this.seriesPlanejadas,
    required this.seriesConcluidas,
    required this.remocoes,
  });

  final String catalogoId;
  final String nome;
  final int sessoes;
  final int seriesPlanejadas;
  final int seriesConcluidas;
  final int remocoes;

  double get taxaConclusao =>
      seriesPlanejadas == 0 ? 1 : seriesConcluidas / seriesPlanejadas;
}

class InsightWorkFit {
  const InsightWorkFit({required this.titulo, required this.texto});

  final String titulo;
  final String texto;
}

/// Aprendizado local por cliente, calculado só com o histórico dele.
///
/// Cada exercício recebe uma taxa de adesão suavizada (a posteriori de uma
/// Beta com média inicial de 70 %), em que cada remoção pelo cliente pesa como
/// três séries não feitas. Com pouca evidência o efeito é nulo. O resultado só
/// reordena exercícios já compatíveis; não relaxa nenhuma regra de segurança.
class AprendizadoWorkFit {
  AprendizadoWorkFit._(
    this._estatisticas,
    this._sessoes,
    this._agora, [
    this._modelo,
  ]);

  static const int minimoSessoes = 3;
  static const double _mediaInicial = 0.7;
  static const double _forcaInicial = 4;
  static const double _pesoRemocao = 3;

  final Map<String, EstatisticaExercicio> _estatisticas;
  final List<SessaoAprendizado> _sessoes;
  final DateTime _agora;
  final ModeloConclusao? _modelo;

  /// Com [catalogo], treina o modelo de conclusão do cliente (se houver dados).
  factory AprendizadoWorkFit.construir({
    required List<SessaoAprendizado> sessoes,
    List<RemocaoAprendizado> remocoes = const [],
    DateTime? agora,
    List<ExercicioBanco>? catalogo,
  }) {
    final modelo = catalogo == null
        ? null
        : ModeloConclusao.treinar(
            sessoes: sessoes,
            catalogo: {for (final e in catalogo) e.id: e},
            vetores: VetoresExercicios.construir(catalogo),
          );
    final planejadas = <String, int>{};
    final concluidas = <String, int>{};
    final sessoesPorExercicio = <String, int>{};
    final nomes = <String, String>{};
    final remocoesPorExercicio = <String, int>{};

    for (final sessao in sessoes) {
      final presentes = <String>{};
      for (final serie in sessao.series) {
        final id = serie.catalogoId;
        if (id == null || id.isEmpty) continue;
        nomes[id] = serie.nome;
        planejadas[id] = (planejadas[id] ?? 0) + 1;
        if (serie.concluida) concluidas[id] = (concluidas[id] ?? 0) + 1;
        presentes.add(id);
      }
      for (final id in presentes) {
        sessoesPorExercicio[id] = (sessoesPorExercicio[id] ?? 0) + 1;
      }
    }
    for (final remocao in remocoes) {
      remocoesPorExercicio[remocao.catalogoId] =
          (remocoesPorExercicio[remocao.catalogoId] ?? 0) + 1;
    }

    final ids = {...planejadas.keys, ...remocoesPorExercicio.keys};
    return AprendizadoWorkFit._(
      {
        for (final id in ids)
          id: EstatisticaExercicio(
            catalogoId: id,
            nome: nomes[id] ?? id,
            sessoes: sessoesPorExercicio[id] ?? 0,
            seriesPlanejadas: planejadas[id] ?? 0,
            seriesConcluidas: concluidas[id] ?? 0,
            remocoes: remocoesPorExercicio[id] ?? 0,
          ),
      },
      List.unmodifiable(sessoes),
      agora ?? DateTime.now(),
      modelo,
    );
  }

  bool get usaModelo => _modelo?.treinado ?? false;

  /// Exercício sem histórico próprio, avaliado só pela semelhança aprendida.
  bool somenteModelo(ExercicioBanco ex) =>
      usaModelo && pontuacao(ex.id) == null;

  /// Bônus do motor: combina a adesão própria com a previsão do modelo.
  int bonusPara(ExercicioBanco ex) {
    final regra = bonus(ex.id);
    final p = _modelo?.prever(ex);
    if (p == null) return regra;
    final previsto = ((p - _mediaInicial) * 20).round().clamp(-8, 4);
    return pontuacao(ex.id) == null
        ? previsto
        : ((regra + previsto) / 2).round();
  }

  /// Sem histórico suficiente o aprendizado não interfere em nada.
  static AprendizadoWorkFit get vazio => AprendizadoWorkFit._(
    const {},
    const [],
    DateTime.fromMillisecondsSinceEpoch(0),
  );

  bool get temEvidenciaSuficiente => _sessoes.length >= minimoSessoes;

  EstatisticaExercicio? estatistica(String catalogoId) =>
      _estatisticas[catalogoId];

  /// Adesão suavizada entre 0 e 1, ou nula sem evidência para o exercício.
  double? pontuacao(String catalogoId) {
    final dado = _estatisticas[catalogoId];
    if (dado == null || dado.sessoes + dado.remocoes < 2) return null;
    final tentativas =
        dado.seriesPlanejadas + dado.remocoes * _pesoRemocao + _forcaInicial;
    return (dado.seriesConcluidas + _mediaInicial * _forcaInicial) / tentativas;
  }

  /// Pontos somados na classificação do motor, entre -8 e +4.
  int bonus(String catalogoId) {
    final pontos = pontuacao(catalogoId);
    if (pontos == null) return 0;
    return ((pontos - _mediaInicial) * 20).round().clamp(-8, 4);
  }

  /// Exercícios que o cliente recusou ou abandona de forma consistente.
  bool evitar(String catalogoId) {
    final dado = _estatisticas[catalogoId];
    if (dado == null) return false;
    return dado.remocoes >= 2 ||
        (dado.sessoes >= 3 && dado.taxaConclusao < 0.4);
  }

  double? mediaSessoesPorSemana() {
    if (_sessoes.isEmpty) return null;
    final limite = _agora.subtract(const Duration(days: 28));
    final recentes = _sessoes.where((s) => !s.fim.isBefore(limite)).toList();
    if (recentes.isEmpty) return 0;
    final primeira = _sessoes
        .map((s) => s.fim)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final dias = min(28, max(7, _agora.difference(primeira).inDays));
    return recentes.length / (dias / 7);
  }

  double? esforcoMedioRecente() {
    final com = _sessoes.where((s) => s.rpe != null).toList()
      ..sort((a, b) => b.fim.compareTo(a.fim));
    if (com.length < minimoSessoes) return null;
    final ultimas = com.take(5).map((s) => s.rpe!);
    return ultimas.reduce((a, b) => a + b) / ultimas.length;
  }

  /// Observações explicáveis; vazio enquanto houver pouca evidência.
  List<InsightWorkFit> insights({int? diasPlanejadosPorSemana}) {
    if (!temEvidenciaSuficiente) return const [];
    final resultado = <InsightWorkFit>[];

    final frequencia = mediaSessoesPorSemana();
    if (frequencia != null &&
        diasPlanejadosPorSemana != null &&
        diasPlanejadosPorSemana > 0 &&
        frequencia < diasPlanejadosPorSemana * 0.6) {
      resultado.add(
        InsightWorkFit(
          titulo: 'Frequência abaixo do plano',
          texto:
              'Você treinou em média ${frequencia.toStringAsFixed(1)} '
              'vez(es) por semana nas últimas semanas, e o plano prevê '
              '$diasPlanejadosPorSemana. Um novo plano com menos dias pode '
              'se encaixar melhor na sua rotina.',
        ),
      );
    }

    final esforco = esforcoMedioRecente();
    if (esforco != null && esforco >= 8.5) {
      resultado.add(
        InsightWorkFit(
          titulo: 'Esforço alto nos últimos treinos',
          texto:
              'Seu esforço médio informado foi ${esforco.toStringAsFixed(1)} '
              'de 10. Considere reduzir séries ou carga antes de progredir.',
        ),
      );
    } else if (esforco != null && esforco <= 5.5) {
      resultado.add(
        InsightWorkFit(
          titulo: 'Há espaço para progredir',
          texto:
              'Seu esforço médio informado foi ${esforco.toStringAsFixed(1)} '
              'de 10. Se a técnica estiver boa, você pode aumentar a carga '
              'ou as repetições.',
        ),
      );
    }

    final abandonados =
        _estatisticas.values
            .where((e) => e.sessoes >= 3 && e.taxaConclusao < 0.5)
            .toList()
          ..sort((a, b) => a.taxaConclusao.compareTo(b.taxaConclusao));
    for (final dado in abandonados.take(3)) {
      resultado.add(
        InsightWorkFit(
          titulo: 'Você costuma deixar "${dado.nome}" incompleto',
          texto:
              'Concluiu ${dado.seriesConcluidas} de ${dado.seriesPlanejadas} '
              'séries em ${dado.sessoes} treinos. Nos próximos planos o '
              'WorkFit vai dar menos prioridade a esse exercício.',
        ),
      );
    }
    return resultado;
  }
}
