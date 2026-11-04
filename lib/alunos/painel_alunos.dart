/// Sessão concluída reduzida ao que o painel do personal precisa.
class SessaoPainelAluno {
  final String? alunoId;
  final String nomeTreino;
  final DateTime inicio;
  final int seriesConcluidas;

  const SessaoPainelAluno({
    required this.alunoId,
    required this.nomeTreino,
    required this.inicio,
    required this.seriesConcluidas,
  });
}

class ResumoPainelAluno {
  final String? alunoId;
  final int concluidos;
  final int naSemana;
  final DateTime? ultima;

  /// Sessões do dia, da mais recente para a mais antiga.
  final List<SessaoPainelAluno> hoje;

  const ResumoPainelAluno({
    required this.alunoId,
    required this.concluidos,
    required this.naSemana,
    required this.ultima,
    required this.hoje,
  });
}

/// Agrupa as sessões por aluno. Mantém a ordem de [alunoIds]; sessões sem
/// aluno (ou de aluno removido) entram no grupo `null`, só se existirem.
List<ResumoPainelAluno> resumirPainelPorAluno(
  List<String> alunoIds,
  List<SessaoPainelAluno> sessoes,
  DateTime agora,
) {
  final hoje = DateTime(agora.year, agora.month, agora.day);
  final inicioSemana = hoje.subtract(Duration(days: agora.weekday - 1));
  final conhecidos = alunoIds.toSet();

  ResumoPainelAluno montar(String? id, List<SessaoPainelAluno> lista) {
    final ordenadas = [...lista]..sort((a, b) => b.inicio.compareTo(a.inicio));
    return ResumoPainelAluno(
      alunoId: id,
      concluidos: ordenadas.length,
      naSemana: ordenadas.where((s) => !s.inicio.isBefore(inicioSemana)).length,
      ultima: ordenadas.isEmpty ? null : ordenadas.first.inicio,
      hoje: ordenadas.where((s) {
        return s.inicio.year == hoje.year &&
            s.inicio.month == hoje.month &&
            s.inicio.day == hoje.day;
      }).toList(),
    );
  }

  final resultado = [
    for (final id in alunoIds)
      montar(id, sessoes.where((s) => s.alunoId == id).toList()),
  ];
  final semAluno = sessoes
      .where((s) => s.alunoId == null || !conhecidos.contains(s.alunoId))
      .toList();
  if (semAluno.isNotEmpty) resultado.add(montar(null, semAluno));
  return resultado;
}
