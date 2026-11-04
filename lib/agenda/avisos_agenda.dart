import 'agendamento.dart';

/// Antecedência do aviso, em minutos. `desligado` não agenda nada.
const int avisoAgendaDesligado = -1;
const int avisoAgendaPadrao = 30;
const List<int> avisoAgendaOpcoes = [avisoAgendaDesligado, 0, 10, 30, 60];
const String chaveAvisoAgenda = 'workholy_agenda_aviso_v1';

String rotuloAvisoAgenda(int minutos) {
  if (minutos == avisoAgendaDesligado) return 'Desligado';
  if (minutos == 0) return 'No horário';
  if (minutos == 60) return '1 hora antes';
  return '$minutos min antes';
}

class AvisoAgenda {
  final int id;
  final DateTime quando;
  final String titulo;
  final String corpo;

  const AvisoAgenda({
    required this.id,
    required this.quando,
    required this.titulo,
    required this.corpo,
  });
}

const int idAvisoAgendaMin = 8000000;
const int idAvisoAgendaMax = 9100000;

/// Id estável do aviso, dentro de [idAvisoAgendaMin, idAvisoAgendaMax).
int idAvisoDoAgendamento(String id) {
  var h = 2166136261;
  for (final c in id.codeUnits) {
    h = ((h ^ c) * 16777619) & 0xFFFFFFFF;
  }
  return idAvisoAgendaMin + (h & 0xFFFFF);
}

String _hora(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Avisos futuros, em ordem. O Android limita os alarmes agendados, por isso
/// só os [limite] mais próximos são planejados.
List<AvisoAgenda> planejarAvisos({
  required List<Agendamento> agenda,
  required Map<String, String> nomes,
  required DateTime agora,
  required int antecedenciaMin,
  int limite = 60,
}) {
  if (antecedenciaMin < 0) return const [];
  final avisos = <AvisoAgenda>[];
  for (final a in agenda) {
    final quando = a.inicio.subtract(Duration(minutes: antecedenciaMin));
    if (!quando.isAfter(agora)) continue;
    final nome = nomes[a.alunoId] ?? 'Aluno';
    avisos.add(
      AvisoAgenda(
        id: idAvisoDoAgendamento(a.id),
        quando: quando,
        titulo: antecedenciaMin == 0
            ? 'Treino agora: $nome'
            : 'Treino com $nome em $antecedenciaMin min',
        corpo: [
          _hora(a.inicio),
          if (a.local.isNotEmpty) a.local,
        ].join(' • '),
      ),
    );
  }
  avisos.sort((x, y) => x.quando.compareTo(y.quando));
  return avisos.take(limite).toList();
}
