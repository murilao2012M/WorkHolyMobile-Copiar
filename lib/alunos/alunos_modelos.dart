class Aluno {
  const Aluno({
    required this.id,
    required this.nome,
    required this.telefone,
    required this.email,
    required this.inicio,
    required this.status,
    required this.objetivo,
    required this.nivel,
    required this.disponibilidade,
    required this.preferencias,
    required this.observacoes,
    required this.treinoIds,
  });

  final String id;
  final String nome;
  final String telefone;
  final String email;
  final DateTime inicio;
  final String status;
  final String objetivo;
  final String nivel;
  final String disponibilidade;
  final String preferencias;
  final String observacoes;
  final List<String> treinoIds;

  Aluno copiar({
    String? nome,
    String? telefone,
    String? email,
    DateTime? inicio,
    String? status,
    String? objetivo,
    String? nivel,
    String? disponibilidade,
    String? preferencias,
    String? observacoes,
    List<String>? treinoIds,
  }) => Aluno(
    id: id,
    nome: nome ?? this.nome,
    telefone: telefone ?? this.telefone,
    email: email ?? this.email,
    inicio: inicio ?? this.inicio,
    status: status ?? this.status,
    objetivo: objetivo ?? this.objetivo,
    nivel: nivel ?? this.nivel,
    disponibilidade: disponibilidade ?? this.disponibilidade,
    preferencias: preferencias ?? this.preferencias,
    observacoes: observacoes ?? this.observacoes,
    treinoIds: treinoIds ?? this.treinoIds,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'telefone': telefone,
    'email': email,
    'inicio': inicio.toIso8601String(),
    'status': status,
    'objetivo': objetivo,
    'nivel': nivel,
    'disponibilidade': disponibilidade,
    'preferencias': preferencias,
    'observacoes': observacoes,
    'treinoIds': treinoIds,
  };

  factory Aluno.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final nome = json['nome'];
    final inicio = DateTime.tryParse(json['inicio']?.toString() ?? '');
    final treinoIds = json['treinoIds'];
    final status = json['status'] ?? 'ativo';
    if (id is! String ||
        id.trim().isEmpty ||
        nome is! String ||
        nome.trim().isEmpty ||
        inicio == null ||
        status is! String ||
        !const {'ativo', 'pausado', 'inativo'}.contains(status) ||
        (treinoIds != null &&
            (treinoIds is! List || treinoIds.any((item) => item is! String)))) {
      throw const FormatException('Dados do aluno inválidos.');
    }

    return Aluno(
      id: id,
      nome: nome.trim(),
      telefone: json['telefone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      inicio: inicio,
      status: status,
      objetivo: json['objetivo']?.toString() ?? '',
      nivel: json['nivel']?.toString() ?? '',
      disponibilidade: json['disponibilidade']?.toString() ?? '',
      preferencias: json['preferencias']?.toString() ?? '',
      observacoes: json['observacoes']?.toString() ?? '',
      treinoIds: List<String>.unmodifiable(
        (treinoIds as List? ?? const []).cast<String>(),
      ),
    );
  }
}

class AnotacaoAluno {
  const AnotacaoAluno({
    required this.id,
    required this.alunoId,
    required this.texto,
    required this.criadaEm,
  });

  final String id;
  final String alunoId;
  final String texto;
  final DateTime criadaEm;

  factory AnotacaoAluno.fromRegistro(Map<String, Object?> registro) {
    final criadaMs = registro['criada_ms'];
    if (criadaMs is! num) {
      throw const FormatException('Data da anotação inválida.');
    }
    return AnotacaoAluno(
      id: registro['id']?.toString() ?? '',
      alunoId: registro['aluno_id']?.toString() ?? '',
      texto: registro['texto']?.toString() ?? '',
      criadaEm: DateTime.fromMillisecondsSinceEpoch(criadaMs.toInt()),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'alunoId': alunoId,
    'texto': texto,
    'criadaEm': criadaEm.toIso8601String(),
  };

  factory AnotacaoAluno.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final alunoId = json['alunoId'];
    final texto = json['texto'];
    final criadaEm = DateTime.tryParse(json['criadaEm']?.toString() ?? '');
    if (id is! String ||
        id.trim().isEmpty ||
        alunoId is! String ||
        alunoId.trim().isEmpty ||
        texto is! String ||
        texto.trim().isEmpty ||
        criadaEm == null) {
      throw const FormatException('Dados da anotação do aluno inválidos.');
    }
    return AnotacaoAluno(
      id: id,
      alunoId: alunoId,
      texto: texto.trim(),
      criadaEm: criadaEm,
    );
  }

  Map<String, Object> paraRegistro() => {
    'id': id,
    'aluno_id': alunoId,
    'texto': texto,
    'criada_ms': criadaEm.millisecondsSinceEpoch,
  };
}
