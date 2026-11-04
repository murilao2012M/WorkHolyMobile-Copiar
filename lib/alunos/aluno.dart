import 'dart:convert';

import '../dados/workholy_banco.dart';

const chaveAlunosPersonal = 'workholy_alunos_personal_v1';

/// Aluno acompanhado pelo personal trainer.
class Aluno {
  final String id;
  final String nome;
  final String telefone;
  final String objetivo;
  final String observacoes;
  final DateTime criadoEm;

  Aluno({
    String? id,
    required this.nome,
    this.telefone = '',
    this.objetivo = '',
    this.observacoes = '',
    DateTime? criadoEm,
  }) : id = id ?? 'aluno_${DateTime.now().microsecondsSinceEpoch}',
       criadoEm = criadoEm ?? DateTime.now();

  Aluno copiarCom({
    String? nome,
    String? telefone,
    String? objetivo,
    String? observacoes,
  }) => Aluno(
    id: id,
    nome: nome ?? this.nome,
    telefone: telefone ?? this.telefone,
    objetivo: objetivo ?? this.objetivo,
    observacoes: observacoes ?? this.observacoes,
    criadoEm: criadoEm,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'telefone': telefone,
    'objetivo': objetivo,
    'observacoes': observacoes,
    'criadoEm': criadoEm.toIso8601String(),
  };

  factory Aluno.fromJson(Map<String, dynamic> json) => Aluno(
    id: json['id'] is String ? json['id'] as String : null,
    nome: json['nome']?.toString() ?? 'Aluno sem nome',
    telefone: json['telefone']?.toString() ?? '',
    objetivo: json['objetivo']?.toString() ?? '',
    observacoes: json['observacoes']?.toString() ?? '',
    criadoEm: DateTime.tryParse(json['criadoEm']?.toString() ?? ''),
  );
}

/// Persistência local dos alunos (lista JSON na tabela de configurações).
class AlunosRepositorio {
  AlunosRepositorio._();
  static final instancia = AlunosRepositorio._();

  Future<List<Aluno>> carregar() async {
    final texto = await WorkHolyBanco.instancia.lerTexto(chaveAlunosPersonal);
    if (texto == null || texto.isEmpty) return [];
    try {
      final lista = jsonDecode(texto);
      if (lista is! List) return [];
      return lista
          .whereType<Map>()
          .map((m) => Aluno.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } on FormatException {
      return [];
    }
  }

  Future<void> salvar(List<Aluno> alunos) => WorkHolyBanco.instancia
      .salvarTexto(
        chaveAlunosPersonal,
        jsonEncode(alunos.map((a) => a.toJson()).toList()),
      );
}
