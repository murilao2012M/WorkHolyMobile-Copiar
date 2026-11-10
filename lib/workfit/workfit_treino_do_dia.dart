import 'workfit_ciclo.dart';

/// Dados mínimos de um treino candidato, sem depender dos modelos da tela.
class CandidatoTreinoDia {
  const CandidatoTreinoDia({
    required this.id,
    required this.nome,
    required this.quantidadeExercicios,
    this.ciclo,
  });

  final String id;
  final String nome;
  final int quantidadeExercicios;
  final WorkFitCiclo? ciclo;
}

/// Sessão concluída ou em andamento, reduzida ao necessário.
class SessaoTreinoDia {
  const SessaoTreinoDia({
    required this.id,
    required this.treinoId,
    required this.inicio,
    this.fim,
    this.planoId,
  });

  final String id;
  final String treinoId;
  final DateTime inicio;
  final DateTime? fim;
  final String? planoId;

  bool get finalizada => fim != null;
}

enum SituacaoTreinoDia { retomar, iniciar, concluidoHoje, descanso, semTreino }

class TreinoDoDia {
  const TreinoDoDia({
    required this.situacao,
    required this.mensagem,
    this.treino,
    this.sessaoAberta,
    this.estadoCiclo,
    this.fraseFase,
  });

  final SituacaoTreinoDia situacao;
  final String mensagem;
  final CandidatoTreinoDia? treino;
  final SessaoTreinoDia? sessaoAberta;
  final EstadoCicloWorkFit? estadoCiclo;

  /// O que a fase atual do ciclo muda na prática; nulo fora de um ciclo.
  final String? fraseFase;

  bool get podeAbrirExecucao =>
      treino != null &&
      (situacao == SituacaoTreinoDia.iniciar ||
          situacao == SituacaoTreinoDia.retomar);
}

String? descreverFaseCiclo(EstadoCicloWorkFit estado) {
  if (estado.naoIniciado) return null;
  if (estado.encerrado) {
    return 'Ciclo encerrado: revise os resultados e considere uma semana '
        'de recuperação antes de um novo plano.';
  }
  return switch (estado.semana) {
    1 =>
      'Semana 1 de 4 (base): registre bem cada série. Ainda não há '
          'progressão de carga.',
    2 =>
      'Semana 2 de 4 (progressão): o WorkFit pode sugerir mais '
          'repetições ou carga.',
    3 =>
      'Semana 3 de 4 (progressão): mantenha a regularidade; as '
          'sugestões seguem liberadas.',
    _ => 'Semana 4 de 4 (revisão): compare o realizado com o planejado.',
  };
}

DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

/// Escolhe o treino de hoje. Sem dias fixos cadastrados, usa rodízio: o
/// treino feito há mais tempo (ou nunca feito) vem primeiro. Não inventa
/// um calendário que o cliente não definiu.
TreinoDoDia escolherTreinoDoDia({
  required List<CandidatoTreinoDia> treinos,
  required List<SessaoTreinoDia> sessoes,
  required DateTime agora,
}) {
  final elegiveis = treinos
      .where(
        (t) => t.quantidadeExercicios > 0 && t.ciclo?.modalidade != 'corrida',
      )
      .toList();
  if (elegiveis.isEmpty) {
    return const TreinoDoDia(
      situacao: SituacaoTreinoDia.semTreino,
      mensagem: 'Crie um treino para ver o que fazer hoje.',
    );
  }

  final ids = elegiveis.map((t) => t.id).toSet();
  final doDia = sessoes.where((s) => ids.contains(s.treinoId)).toList();

  final abertas = doDia.where((s) => !s.finalizada).toList()
    ..sort((a, b) => b.inicio.compareTo(a.inicio));
  if (abertas.isNotEmpty) {
    final aberta = abertas.first;
    final treino = elegiveis.firstWhere((t) => t.id == aberta.treinoId);
    return TreinoDoDia(
      situacao: SituacaoTreinoDia.retomar,
      mensagem: 'Você tem um treino em andamento: ${treino.nome}.',
      treino: treino,
      sessaoAberta: aberta,
      estadoCiclo: _estado(treino, sessoes, agora),
      fraseFase: _fase(treino, sessoes, agora),
    );
  }

  final finalizadas = doDia.where((s) => s.finalizada).toList();
  final ultimaPorTreino = <String, DateTime>{};
  for (final s in finalizadas) {
    final atual = ultimaPorTreino[s.treinoId];
    if (atual == null || s.fim!.isAfter(atual)) {
      ultimaPorTreino[s.treinoId] = s.fim!;
    }
  }

  final hoje = _dia(agora);
  final feitoHoje = finalizadas.any((s) => _dia(s.fim!) == hoje);

  // Treinos nunca feitos primeiro; depois o feito há mais tempo. Empate: nome.
  final ordenados = [...elegiveis]
    ..sort((a, b) {
      final ua = ultimaPorTreino[a.id];
      final ub = ultimaPorTreino[b.id];
      if (ua == null && ub == null) return a.nome.compareTo(b.nome);
      if (ua == null) return -1;
      if (ub == null) return 1;
      final c = ua.compareTo(ub);
      return c != 0 ? c : a.nome.compareTo(b.nome);
    });
  final proximo = ordenados.first;
  final estado = _estado(proximo, sessoes, agora);
  final fase = _fase(proximo, sessoes, agora);

  if (feitoHoje) {
    return TreinoDoDia(
      situacao: SituacaoTreinoDia.concluidoHoje,
      mensagem:
          'Treino de hoje concluído. Próximo na sequência: ${proximo.nome}.',
      treino: proximo,
      estadoCiclo: estado,
      fraseFase: fase,
    );
  }

  if (estado != null &&
      !estado.naoIniciado &&
      !estado.encerrado &&
      estado.diasConcluidos >= estado.metaSemanal) {
    return TreinoDoDia(
      situacao: SituacaoTreinoDia.descanso,
      mensagem:
          'Você já cumpriu a meta de ${estado.metaSemanal} dia(s) desta '
          'semana. Hoje pode ser descanso.',
      treino: proximo,
      estadoCiclo: estado,
      fraseFase: fase,
    );
  }

  final nunca = !ultimaPorTreino.containsKey(proximo.id);
  return TreinoDoDia(
    situacao: SituacaoTreinoDia.iniciar,
    mensagem: nunca
        ? 'Hoje é dia de ${proximo.nome}.'
        : 'Hoje é dia de ${proximo.nome}, o que você fez há mais tempo.',
    treino: proximo,
    estadoCiclo: estado,
    fraseFase: fase,
  );
}

EstadoCicloWorkFit? _estado(
  CandidatoTreinoDia treino,
  List<SessaoTreinoDia> sessoes,
  DateTime agora,
) {
  final ciclo = treino.ciclo;
  if (ciclo == null) return null;
  return avaliarCicloWorkFit(ciclo, agora, [
    for (final s in sessoes)
      if (s.finalizada && s.planoId == ciclo.id)
        DiaConcluidoWorkFit(planoId: ciclo.id, data: s.fim!),
  ]);
}

String? _fase(
  CandidatoTreinoDia treino,
  List<SessaoTreinoDia> sessoes,
  DateTime agora,
) {
  final estado = _estado(treino, sessoes, agora);
  return estado == null ? null : descreverFaseCiclo(estado);
}
