import 'package:latlong2/latlong.dart';

/// A leitura de localização necessária para validar um ponto de corrida.
///
/// Esta classe é deliberadamente independente do plugin de GPS para que as
/// regras possam ser testadas sem um aparelho físico.
class PontoGps {
  const PontoGps({
    required this.latitude,
    required this.longitude,
    required this.horario,
    required this.precisaoMetros,
    this.temPrecisao = true,
  });

  final double latitude;
  final double longitude;
  final DateTime horario;
  final double precisaoMetros;
  final bool temPrecisao;
}

enum MotivoDescarteGps {
  coordenadaInvalida,
  precisaoIndisponivel,
  precisaoInsuficiente,
  horarioInvalido,
  movimentoMuitoCurto,
  velocidadeImprovavel,
}

class ResultadoFiltroGps {
  const ResultadoFiltroGps.aceito(this.distanciaMetros) : motivoDescarte = null;

  const ResultadoFiltroGps.descartado(this.motivoDescarte)
    : distanciaMetros = 0;

  final double distanciaMetros;
  final MotivoDescarteGps? motivoDescarte;

  bool get aceito => motivoDescarte == null;
}

/// Regras conservadoras para impedir que ruído do GPS infle a distância.
///
/// Um ponto inicial válido é aceito sem somar distância. Os próximos precisam
/// ter boa precisão, avançar pelo menos [distanciaMinimaMetros] e não exceder
/// [velocidadeMaximaMetrosPorSegundo]. O limite de 10 m/s (36 km/h) fica bem
/// acima de uma corrida recreativa e ainda descarta saltos comuns de GPS.
class FiltroGpsCorrida {
  const FiltroGpsCorrida._();

  static const double precisaoMaximaMetros = 20;
  static const double distanciaMinimaMetros = 3;
  static const double velocidadeMaximaMetrosPorSegundo = 10;

  static ResultadoFiltroGps avaliar({
    required PontoGps atual,
    PontoGps? anteriorAceito,
  }) {
    if (!_coordenadaValida(atual)) {
      return const ResultadoFiltroGps.descartado(
        MotivoDescarteGps.coordenadaInvalida,
      );
    }

    if (!atual.temPrecisao) {
      return const ResultadoFiltroGps.descartado(
        MotivoDescarteGps.precisaoIndisponivel,
      );
    }

    if (atual.precisaoMetros > precisaoMaximaMetros) {
      return const ResultadoFiltroGps.descartado(
        MotivoDescarteGps.precisaoInsuficiente,
      );
    }

    if (anteriorAceito == null) {
      return const ResultadoFiltroGps.aceito(0);
    }

    final intervaloMs = atual.horario
        .difference(anteriorAceito.horario)
        .inMilliseconds;

    if (intervaloMs <= 0) {
      return const ResultadoFiltroGps.descartado(
        MotivoDescarteGps.horarioInvalido,
      );
    }

    const distance = Distance();
    final distancia = distance.as(
      LengthUnit.Meter,
      LatLng(anteriorAceito.latitude, anteriorAceito.longitude),
      LatLng(atual.latitude, atual.longitude),
    );

    if (distancia < distanciaMinimaMetros) {
      return const ResultadoFiltroGps.descartado(
        MotivoDescarteGps.movimentoMuitoCurto,
      );
    }

    final intervaloSegundos = intervaloMs / Duration.millisecondsPerSecond;
    final velocidade = distancia / intervaloSegundos;

    if (velocidade > velocidadeMaximaMetrosPorSegundo) {
      return const ResultadoFiltroGps.descartado(
        MotivoDescarteGps.velocidadeImprovavel,
      );
    }

    return ResultadoFiltroGps.aceito(distancia);
  }

  static bool _coordenadaValida(PontoGps ponto) {
    return ponto.latitude.isFinite &&
        ponto.longitude.isFinite &&
        ponto.precisaoMetros.isFinite &&
        ponto.precisaoMetros >= 0 &&
        ponto.latitude >= -90 &&
        ponto.latitude <= 90 &&
        ponto.longitude >= -180 &&
        ponto.longitude <= 180;
  }
}
