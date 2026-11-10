import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:workholy_mobile/lembretes/lembretes_treino.dart';

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('próxima ocorrência respeita dia e horário', () {
    final sp = tz.getLocation('America/Sao_Paulo');
    final quarta = tz.TZDateTime(sp, 2026, 11, 4, 10); // quarta-feira
    final hoje = proximaOcorrencia(quarta, DateTime.wednesday, 18, 30);
    expect(hoje, tz.TZDateTime(sp, 2026, 11, 4, 18, 30));
    final jaPassou = proximaOcorrencia(quarta, DateTime.wednesday, 8, 0);
    expect(jaPassou, tz.TZDateTime(sp, 2026, 11, 11, 8));
    final segunda = proximaOcorrencia(quarta, DateTime.monday, 7, 0);
    expect(segunda, tz.TZDateTime(sp, 2026, 11, 9, 7));
  });

  test('configuração ignora valores inválidos', () {
    final c = ConfigLembretes.fromJson({
      'ativo': true,
      'dias': [1, 9, 0, 5],
      'hora': 99,
      'minuto': -1,
    });
    expect(c.dias, {1, 5});
    expect(c.hora, 18);
    expect(c.minuto, 0);
    expect(ConfigLembretes.fromJson(null).ativo, isFalse);
  });
}
