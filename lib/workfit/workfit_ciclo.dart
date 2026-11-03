class WorkFitCiclo {
  const WorkFitCiclo({
    required this.id,
    required this.inicio,
    required this.diasPorSemana,
    required this.modalidade,
  });

  final String id;
  final DateTime inicio;
  final int diasPorSemana;
  final String modalidade;

  Map<String, Object> toJson() => {
    'id': id,
    'inicio': inicio.toIso8601String(),
    'diasPorSemana': diasPorSemana,
    'modalidade': modalidade,
  };

  factory WorkFitCiclo.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final data = json['inicio'];
    final dias = json['diasPorSemana'];
    final modalidade = json['modalidade'];
    if (id is! String ||
        id.isEmpty ||
        data is! String ||
        dias is! int ||
        dias < 1 ||
        dias > 7 ||
        modalidade is! String ||
        modalidade.isEmpty) {
      throw const FormatException('Ciclo WorkFit inválido.');
    }
    return WorkFitCiclo(
      id: id,
      inicio: DateTime.parse(data),
      diasPorSemana: dias,
      modalidade: modalidade,
    );
  }
}

class DiaConcluidoWorkFit {
  const DiaConcluidoWorkFit({required this.planoId, required this.data});
  final String planoId;
  final DateTime data;
}

class EstadoCicloWorkFit {
  const EstadoCicloWorkFit({
    required this.encerrado,
    required this.naoIniciado,
    required this.semana,
    required this.diasConcluidos,
    required this.metaSemanal,
    required this.semanaConcluida,
    required this.diasSemanaConcluida,
  });
  final bool encerrado;
  final bool naoIniciado;
  final int semana;
  final int diasConcluidos;
  final int metaSemanal;
  final int? semanaConcluida;
  final int? diasSemanaConcluida;
}

DateTime _dia(DateTime data) {
  final local = data.toLocal();
  return DateTime.utc(local.year, local.month, local.day);
}

EstadoCicloWorkFit avaliarCicloWorkFit(
  WorkFitCiclo ciclo,
  DateTime agora,
  Iterable<DiaConcluidoWorkFit> sessoes,
) {
  final inicio = _dia(ciclo.inicio);
  final hoje = _dia(agora);
  final diasDecorridos = hoje.difference(inicio).inDays;
  if (diasDecorridos < 0) {
    return EstadoCicloWorkFit(
      encerrado: false,
      naoIniciado: true,
      semana: 0,
      diasConcluidos: 0,
      metaSemanal: ciclo.diasPorSemana,
      semanaConcluida: null,
      diasSemanaConcluida: null,
    );
  }
  final encerrado = diasDecorridos >= 28;
  final semana = encerrado ? 4 : diasDecorridos ~/ 7 + 1;
  final inicioSemana = inicio.add(Duration(days: (semana - 1) * 7));
  final fimSemana = inicioSemana.add(const Duration(days: 7));
  final datas = sessoes
      .where((sessao) => sessao.planoId == ciclo.id)
      .map((sessao) => _dia(sessao.data))
      .toSet();
  final dias = datas
      .where(
        (dia) =>
            !dia.isBefore(inicioSemana) &&
            dia.isBefore(fimSemana) &&
            !dia.isAfter(hoje),
      )
      .toSet();
  final semanaConcluida = diasDecorridos >= 7
      ? (diasDecorridos ~/ 7).clamp(1, 4)
      : null;
  final inicioConcluida = semanaConcluida == null
      ? null
      : inicio.add(Duration(days: (semanaConcluida - 1) * 7));
  final diasConcluidos = inicioConcluida == null
      ? null
      : datas
            .where(
              (dia) =>
                  !dia.isBefore(inicioConcluida) &&
                  dia.isBefore(inicioConcluida.add(const Duration(days: 7))),
            )
            .length;
  return EstadoCicloWorkFit(
    encerrado: encerrado,
    naoIniciado: false,
    semana: semana,
    diasConcluidos: dias.length,
    metaSemanal: ciclo.diasPorSemana,
    semanaConcluida: semanaConcluida,
    diasSemanaConcluida: diasConcluidos,
  );
}
