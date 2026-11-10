import 'package:flutter/material.dart' hide Icon;
import 'package:flutter/widgets.dart' as w show Icon;
import 'package:flutter_svg/flutter_svg.dart';

/// Ícone SVG do WorkHoly (assets/icons), pelo nome do arquivo sem extensão.
/// A cor padrão vem do [IconTheme] do contexto.
class WIcone extends StatelessWidget {
  const WIcone(this.nome, {super.key, this.size, this.color});

  final String nome;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tema = IconTheme.of(context);
    final tam = size ?? tema.size ?? 24;
    final corFinal = color ?? tema.color ?? const Color(0xFFFFFFFF);
    return SvgPicture.asset(
      'assets/icons/$nome.svg',
      width: tam,
      height: tam,
      colorFilter: ColorFilter.mode(corFinal, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}

/// Substitui o Icon do Material (importado com `hide Icon`): usa o SVG equivalente do WorkHoly quando
/// existe e mantém o ícone do Material nos demais casos.
class Icon extends StatelessWidget {
  const Icon(this.icone, {super.key, this.size, this.color});

  final IconData? icone;
  final double? size;
  final Color? color;

  static final Map<int, String> _svg = {
    for (final entrada in _mapa.entries)
      for (final dado in entrada.value) dado.codePoint: entrada.key,
  };

  static const Map<String, List<IconData>> _mapa = {
    'dumbbell': [Icons.fitness_center, Icons.fitness_center_outlined],
    'plus': [
      Icons.add,
      Icons.add_circle,
      Icons.add_circle_outline,
      Icons.library_add,
      Icons.playlist_add,
    ],
    'check': [Icons.check, Icons.check_circle, Icons.check_circle_outline],
    'running': [Icons.directions_run, Icons.directions_run_outlined],
    'trash': [Icons.delete, Icons.delete_outline, Icons.delete_sweep_outlined],
    'clock': [Icons.history, Icons.history_outlined, Icons.schedule],
    'refresh': [Icons.refresh, Icons.restart_alt, Icons.replay],
    'play': [Icons.play_arrow, Icons.play_circle_outline],
    'pause': [Icons.pause, Icons.pause_circle_outline],
    'stop': [Icons.stop],
    'search': [Icons.search],
    'flame': [Icons.local_fire_department],
    'trophy': [Icons.emoji_events, Icons.emoji_events_outlined],
    'medal': [Icons.military_tech],
    'crown': [Icons.workspace_premium],
    'gps': [Icons.gps_fixed, Icons.gps_not_fixed, Icons.my_location],
    'map_pin': [Icons.location_on, Icons.trip_origin],
    'map': [Icons.map_outlined],
    'calendar': [
      Icons.calendar_month,
      Icons.calendar_month_outlined,
      Icons.calendar_view_week_outlined,
      Icons.calendar_view_month,
    ],
    'info': [Icons.info_outline],
    'warning': [Icons.error_outline],
    'timer': [Icons.timer_outlined],
    'stopwatch': [Icons.speed],
    'close': [Icons.close, Icons.clear],
    'user': [Icons.person_outline],
    'scale': [Icons.monitor_weight_outlined],
    'ruler': [Icons.height, Icons.straighten],
    'edit': [Icons.edit_outlined],
    'flag': [Icons.flag_outlined],
    'chart_bar': [Icons.bar_chart],
    'chart_line': [
      Icons.show_chart,
      Icons.trending_up,
      Icons.insights,
      Icons.analytics_outlined,
    ],
    'sun': [Icons.light_mode_outlined],
    'moon': [Icons.dark_mode_outlined],
    'bolt': [Icons.bolt, Icons.lightbulb_outline],
    'forward': [Icons.arrow_forward, Icons.skip_next],
    'back': [Icons.undo],
    'filter': [Icons.filter_list],
    'repeat': [Icons.repeat, Icons.swap_horiz],
    'image': [Icons.image_search, Icons.image_not_supported_outlined],
    'mail': [Icons.mark_email_unread_outlined],
    'brain': [Icons.auto_awesome],
    'route': [Icons.route],
    'book': [Icons.library_books_outlined, Icons.school_outlined],
    'list': [Icons.view_list, Icons.view_list_outlined],
    'dashboard': [Icons.dashboard, Icons.dashboard_outlined],
    'settings': [Icons.settings_outlined],
    'certificate': [Icons.gavel_outlined],
    'shield': [Icons.privacy_tip_outlined],
  };

  @override
  Widget build(BuildContext context) {
    final dado = icone;
    final nome = dado == null ? null : _svg[dado.codePoint];
    if (dado == null || nome == null || dado.fontFamily != 'MaterialIcons') {
      return w.Icon(icone, size: size, color: color);
    }
    return WIcone(nome, size: size, color: color);
  }
}

String _semAcento(String texto) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const para = 'aaaaaeeeeiiiiooooouuuuc';
  final buffer = StringBuffer();
  for (final letra in texto.toLowerCase().split('')) {
    final i = de.indexOf(letra);
    buffer.write(i >= 0 ? para[i] : letra);
  }
  return buffer.toString();
}

/// Nome do SVG do grupo muscular, ou nulo quando não há ícone coerente.
String? nomeIconeGrupo(String grupo) {
  final g = _semAcento(grupo);
  if (g == 'todos') return 'list';
  if (g.contains('peito')) return 'bench';
  if (g.contains('costas')) return 'body';
  if (g.contains('ombro')) return 'muscle';
  if (g.contains('braco') || g.contains('biceps') || g.contains('triceps')) {
    return 'muscle';
  }
  if (g.contains('abdom') || g.contains('core')) return 'body';
  if (g.contains('perna') ||
      g.contains('gluteo') ||
      g.contains('panturrilha') ||
      g.contains('quadriceps')) {
    return 'footprints';
  }
  if (g.contains('cardio')) return 'heart_pulse';
  if (g.contains('alongamento') || g.contains('mobilidade')) return 'stretch';
  if (g.contains('pescoco')) return 'user';
  return 'activity';
}

/// Nome do SVG do equipamento, ou nulo quando não há ícone coerente.
String? nomeIconeEquipamento(String equipamento) {
  final e = _semAcento(equipamento);
  if (e.contains('todos')) return 'dumbbell';
  if (e.contains('kettlebell')) return 'kettlebell';
  if (e.contains('halter')) return 'dumbbell';
  if (e.contains('barra')) return 'barbell';
  if (e.contains('peso corporal')) return 'body';
  if (e.contains('elastico') || e.contains('rolo')) return 'stretch';
  if (e.contains('carga adicional')) return 'weight_plate';
  if (e.contains('bicicleta') ||
      e.contains('eliptico') ||
      e.contains('escada')) {
    return 'running';
  }
  if (e.contains('bola') || e.contains('bosu')) return 'yoga';
  return null;
}

/// Ícone SVG do grupo muscular, com o ícone de halteres como alternativa.
Widget iconeGrupo(String grupo, {double? size, Color? color}) =>
    WIcone(nomeIconeGrupo(grupo) ?? 'dumbbell', size: size, color: color);

/// Ícone SVG do equipamento; vazio quando não há equivalente.
Widget iconeEquipamento(String equipamento, {double? size, Color? color}) {
  final nome = nomeIconeEquipamento(equipamento);
  if (nome == null) return SizedBox(width: size ?? 24, height: size ?? 24);
  return WIcone(nome, size: size, color: color);
}
