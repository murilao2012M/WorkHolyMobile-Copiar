import 'dart:convert';

import '../dados/workholy_banco.dart';

const chaveAgendaPersonal = 'workholy_agenda_personal_v1';

/// Horário marcado de um aluno com o personal.
class Agendamento {
  final String id;
  final String alunoId;
  final DateTime inicio;
  final String local;
  final String observacoes;

  Agendamento({
    String? id,
    required this.alunoId,
    required this.inicio,
    this.local = '',
    this.observacoes = '',
  }) : id = id ?? 'agenda_${DateTime.now().microsecondsSinceEpoch}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'alunoId': alunoId,
    'inicio': inicio.toIso8601String(),
    'local': local,
    'observacoes': observacoes,
  };

  /// Retorna `null` se o registro não tiver aluno ou data válidos.
  static Agendamento? deJson(Object? bruto) {
    if (bruto is! Map) return null;
    final json = Map<String, dynamic>.from(bruto);
    final inicio = DateTime.tryParse(json['inicio']?.toString() ?? '');
    final alunoId = json['alunoId']?.toString() ?? '';
    if (inicio == null || alunoId.isEmpty) return null;
    return Agendamento(
      id: json['id'] is String ? json['id'] as String : null,
      alunoId: alunoId,
      inicio: inicio,
      local: json['local']?.toString() ?? '',
      observacoes: json['observacoes']?.toString() ?? '',
    );
  }
}

/// Agendamentos do dia [dia], em ordem de horário.
List<Agendamento> agendamentosDoDia(List<Agendamento> todos, DateTime dia) {
  return todos
      .where(
        (a) =>
            a.inicio.year == dia.year &&
            a.inicio.month == dia.month &&
            a.inicio.day == dia.day,
      )
      .toList()
    ..sort((a, b) => a.inicio.compareTo(b.inicio));
}

/// Agendamentos a partir do início de [desde], agrupados por dia e ordenados.
Map<DateTime, List<Agendamento>> agruparPorDia(
  List<Agendamento> todos,
  DateTime desde,
) {
  final inicio = DateTime(desde.year, desde.month, desde.day);
  final futuros = todos.where((a) => !a.inicio.isBefore(inicio)).toList()
    ..sort((a, b) => a.inicio.compareTo(b.inicio));
  final grupos = <DateTime, List<Agendamento>>{};
  for (final a in futuros) {
    final dia = DateTime(a.inicio.year, a.inicio.month, a.inicio.day);
    grupos.putIfAbsent(dia, () => []).add(a);
  }
  return grupos;
}

/// Persistência local da agenda (JSON na tabela de configurações).
class AgendaRepositorio {
  AgendaRepositorio._();
  static final instancia = AgendaRepositorio._();

  Future<List<Agendamento>> carregar() async {
    final texto = await WorkHolyBanco.instancia.lerTexto(chaveAgendaPersonal);
    if (texto == null || texto.isEmpty) return [];
    try {
      final lista = jsonDecode(texto);
      if (lista is! List) return [];
      return lista.map(Agendamento.deJson).whereType<Agendamento>().toList();
    } on FormatException {
      return [];
    }
  }

  Future<void> salvar(List<Agendamento> agenda) =>
      WorkHolyBanco.instancia.salvarTexto(
        chaveAgendaPersonal,
        jsonEncode(agenda.map((a) => a.toJson()).toList()),
      );
}
