/// Sessão finalizada reduzida ao que a ficha do aluno precisa.
class SessaoAluno {
  final String nomeTreino;
  final DateTime inicio;
  final DateTime fim;
  final int seriesConcluidas;
  final double volumeKg;

  /// Maior carga usada em cada exercício nesta sessão (nome -> kg).
  final Map<String, double> cargaMaxima;

  const SessaoAluno({
    required this.nomeTreino,
    required this.inicio,
    required this.fim,
    required this.seriesConcluidas,
    required this.volumeKg,
    required this.cargaMaxima,
  });
}

class EvolucaoExercicio {
  final String nome;
  final double cargaInicial;
  final double cargaAtual;

  const EvolucaoExercicio(this.nome, this.cargaInicial, this.cargaAtual);

  double get diferenca => cargaAtual - cargaInicial;
}

class ResumoAluno {
  final int totalSessoes;
  final DateTime? ultimaSessao;

  /// Sessões por semana, da mais antiga para a mais recente (4 semanas).
  final List<int> sessoesPorSemana;
  final double volumeTotalKg;
  final List<EvolucaoExercicio> evolucao;

  const ResumoAluno({
    required this.totalSessoes,
    required this.ultimaSessao,
    required this.sessoesPorSemana,
    required this.volumeTotalKg,
    required this.evolucao,
  });
}

ResumoAluno calcularResumoAluno(List<SessaoAluno> sessoes, DateTime agora) {
  final ordenadas = [...sessoes]..sort((a, b) => a.inicio.compareTo(b.inicio));

  final semanas = List<int>.filled(4, 0);
  for (final s in ordenadas) {
    final dias = agora.difference(s.inicio).inDays;
    if (dias < 0 || dias >= 28) continue;
    semanas[3 - dias ~/ 7]++;
  }

  final cargas = <String, List<double>>{};
  for (final s in ordenadas) {
    s.cargaMaxima.forEach((nome, carga) {
      if (carga > 0) cargas.putIfAbsent(nome, () => []).add(carga);
    });
  }
  final evolucao = [
    for (final e in cargas.entries)
      if (e.value.length >= 2)
        EvolucaoExercicio(e.key, e.value.first, e.value.last),
  ]..sort((a, b) => b.diferenca.compareTo(a.diferenca));

  return ResumoAluno(
    totalSessoes: ordenadas.length,
    ultimaSessao: ordenadas.isEmpty ? null : ordenadas.last.inicio,
    sessoesPorSemana: semanas,
    volumeTotalKg: ordenadas.fold<double>(0, (t, s) => t + s.volumeKg),
    evolucao: evolucao,
  );
}
