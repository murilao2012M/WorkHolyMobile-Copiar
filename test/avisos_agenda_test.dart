import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/agenda/agendamento.dart';
import 'package:workholy_mobile/agenda/avisos_agenda.dart';

void main() {
  final agora = DateTime(2026, 11, 4, 12);

  test('avisa antes do horário e ignora o que já passou', () {
    final agenda = [
      Agendamento(
        id: 'x1',
        alunoId: 'a',
        inicio: DateTime(2026, 11, 4, 18),
        local: 'Praça',
      ),
      Agendamento(id: 'x2', alunoId: 'a', inicio: DateTime(2026, 11, 4, 12, 20)),
      Agendamento(id: 'x3', alunoId: 'a', inicio: DateTime(2026, 11, 3, 9)),
    ];
    final avisos = planejarAvisos(
      agenda: agenda,
      nomes: {'a': 'Ana'},
      agora: agora,
      antecedenciaMin: 30,
    );
    expect(avisos.length, 1);
    expect(avisos.single.quando, DateTime(2026, 11, 4, 17, 30));
    expect(avisos.single.titulo, contains('Ana'));
    expect(avisos.single.corpo, '18:00 • Praça');
  });

  test('desligado não agenda e 0 avisa no horário', () {
    final agenda = [
      Agendamento(id: 'x1', alunoId: 'a', inicio: DateTime(2026, 11, 5, 8)),
    ];
    expect(
      planejarAvisos(
        agenda: agenda,
        nomes: {},
        agora: agora,
        antecedenciaMin: avisoAgendaDesligado,
      ),
      isEmpty,
    );
    final no = planejarAvisos(
      agenda: agenda,
      nomes: {},
      agora: agora,
      antecedenciaMin: 0,
    );
    expect(no.single.quando, DateTime(2026, 11, 5, 8));
  });

  test('id estável e dentro da faixa; respeita o limite', () {
    final id = idAvisoDoAgendamento('agenda_123');
    expect(id, idAvisoDoAgendamento('agenda_123'));
    expect(id, inInclusiveRange(idAvisoAgendaMin, idAvisoAgendaMax - 1));
    final muitos = [
      for (var i = 0; i < 100; i++)
        Agendamento(
          id: 'a$i',
          alunoId: 'a',
          inicio: DateTime(2026, 12, 1).add(Duration(hours: i)),
        ),
    ];
    expect(
      planejarAvisos(
        agenda: muitos,
        nomes: {},
        agora: agora,
        antecedenciaMin: 10,
        limite: 60,
      ).length,
      60,
    );
  });
}
