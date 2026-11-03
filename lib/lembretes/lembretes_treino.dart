import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../dados/workholy_banco.dart';

/// Dias usam o padrão do DateTime: 1 = segunda ... 7 = domingo.
class ConfigLembretes {
  const ConfigLembretes({
    this.ativo = false,
    this.dias = const {1, 3, 5},
    this.hora = 18,
    this.minuto = 0,
  });

  final bool ativo;
  final Set<int> dias;
  final int hora;
  final int minuto;

  ConfigLembretes copiar({
    bool? ativo,
    Set<int>? dias,
    int? hora,
    int? minuto,
  }) => ConfigLembretes(
    ativo: ativo ?? this.ativo,
    dias: dias ?? this.dias,
    hora: hora ?? this.hora,
    minuto: minuto ?? this.minuto,
  );

  Map<String, Object?> toJson() => {
    'ativo': ativo,
    'dias': (dias.toList()..sort()),
    'hora': hora,
    'minuto': minuto,
  };

  factory ConfigLembretes.fromJson(Object? json) {
    if (json is! Map) return const ConfigLembretes();
    final dias = json['dias'];
    final hora = json['hora'];
    final minuto = json['minuto'];
    return ConfigLembretes(
      ativo: json['ativo'] == true,
      dias: dias is List
          ? dias.whereType<int>().where((d) => d >= 1 && d <= 7).toSet()
          : const {1, 3, 5},
      hora: hora is int && hora >= 0 && hora <= 23 ? hora : 18,
      minuto: minuto is int && minuto >= 0 && minuto <= 59 ? minuto : 0,
    );
  }
}

/// Próxima data em que o lembrete do [diaSemana] dispara, depois de [agora].
tz.TZDateTime proximaOcorrencia(
  tz.TZDateTime agora,
  int diaSemana,
  int hora,
  int minuto,
) {
  var data = tz.TZDateTime(
    agora.location,
    agora.year,
    agora.month,
    agora.day,
    hora,
    minuto,
  );
  while (data.weekday != diaSemana || !data.isAfter(agora)) {
    data = tz.TZDateTime(
      agora.location,
      data.year,
      data.month,
      data.day + 1,
      hora,
      minuto,
    );
  }
  return data;
}

/// Lembretes semanais por notificação local. O horário é aproximado: o
/// Android pode atrasar alguns minutos para poupar bateria. A notificação
/// não fala; ela só avisa.
class LembretesTreino {
  LembretesTreino._();

  static final LembretesTreino instancia = LembretesTreino._();

  static const String _chave = 'workholy_lembretes_treino_v1';
  static const int _idBase = 7100;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _pronto = false;

  Future<ConfigLembretes> ler() async {
    try {
      final texto = await WorkHolyBanco.instancia.lerTexto(_chave);
      if (texto == null) return const ConfigLembretes();
      return ConfigLembretes.fromJson(jsonDecode(texto));
    } catch (erro) {
      debugPrint('Não foi possível ler os lembretes: $erro');
      return const ConfigLembretes();
    }
  }

  Future<void> _iniciar() async {
    if (_pronto) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (erro) {
      debugPrint('Fuso horário não identificado, usando UTC: $erro');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _pronto = true;
  }

  Future<bool> _permitido() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return false;
    return await android.requestNotificationsPermission() ?? false;
  }

  /// Salva e reagenda. Devolve uma mensagem de erro, ou null se deu certo.
  Future<String?> aplicar(ConfigLembretes config) async {
    try {
      await _iniciar();
      for (var d = 1; d <= 7; d++) {
        await _plugin.cancel(id: _idBase + d);
      }
      if (config.ativo) {
        if (config.dias.isEmpty) return 'Escolha pelo menos um dia.';
        if (!await _permitido()) {
          return 'Permita as notificações do WorkHoly nas configurações do '
              'aparelho para receber os lembretes.';
        }
        final agora = tz.TZDateTime.now(tz.local);
        for (final dia in config.dias) {
          await _plugin.zonedSchedule(
            id: _idBase + dia,
            title: 'Hora de treinar',
            body: 'Abra o WorkHoly: seu treino do dia está esperando.',
            scheduledDate: proximaOcorrencia(
              agora,
              dia,
              config.hora,
              config.minuto,
            ),
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'lembretes_treino',
                'Lembretes de treino',
                channelDescription: 'Avisos nos dias e horários de treino.',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        }
      }
      await WorkHolyBanco.instancia.salvarTexto(
        _chave,
        jsonEncode(config.toJson()),
      );
      return null;
    } catch (erro) {
      debugPrint('Falha ao agendar lembretes: $erro');
      return 'Não foi possível agendar os lembretes neste aparelho.';
    }
  }
}
