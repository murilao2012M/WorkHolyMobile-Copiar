import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/agenda/agendamento.dart';

void main() {
  test('JSON ida e volta mantém local e horário', () {
    final a = Agendamento(
      alunoId: 'a1',
      inicio: DateTime(2026, 11, 5, 7, 30),
      local: 'Praça central',
    );
    final volta = Agendamento.deJson(a.toJson())!;
    expect(volta.id, a.id);
    expect(volta.inicio, a.inicio);
    expect(volta.local, 'Praça central');
  });

  test('registro inválido é ignorado', () {
    expect(Agendamento.deJson({'alunoId': 'a1', 'inicio': 'x'}), isNull);
    expect(Agendamento.deJson({'inicio': '2026-11-05T07:00:00'}), isNull);
    expect(Agendamento.deJson('texto'), isNull);
  });

  test('filtra o dia e agrupa a partir de hoje em ordem', () {
    final lista = [
      Agendamento(alunoId: 'a', inicio: DateTime(2026, 11, 5, 18)),
      Agendamento(alunoId: 'b', inicio: DateTime(2026, 11, 4, 9)),
      Agendamento(alunoId: 'c', inicio: DateTime(2026, 11, 4, 7)),
      Agendamento(alunoId: 'd', inicio: DateTime(2026, 11, 3, 7)),
    ];
    final hoje = agendamentosDoDia(lista, DateTime(2026, 11, 4, 12));
    expect(hoje.map((e) => e.alunoId), ['c', 'b']);

    final grupos = agruparPorDia(lista, DateTime(2026, 11, 4, 12));
    expect(grupos.keys.toList(), [DateTime(2026, 11, 4), DateTime(2026, 11, 5)]);
    expect(grupos.values.expand((e) => e).any((e) => e.alunoId == 'd'), isFalse);
  });
}
