import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/corrida/filtro_gps.dart';

PontoGps ponto({
  required double latitude,
  required double longitude,
  required int segundo,
  double precisao = 8,
  bool temPrecisao = true,
}) {
  return PontoGps(
    latitude: latitude,
    longitude: longitude,
    horario: DateTime.utc(2026, 1, 1).add(Duration(seconds: segundo)),
    precisaoMetros: precisao,
    temPrecisao: temPrecisao,
  );
}

void main() {
  group('FiltroGpsCorrida', () {
    test('aceita o primeiro ponto válido sem acrescentar distância', () {
      final resultado = FiltroGpsCorrida.avaliar(
        atual: ponto(latitude: -23.55, longitude: -46.63, segundo: 0),
      );

      expect(resultado.aceito, isTrue);
      expect(resultado.distanciaMetros, 0);
    });

    test('descarta leitura com precisão insuficiente', () {
      final resultado = FiltroGpsCorrida.avaliar(
        atual: ponto(
          latitude: -23.55,
          longitude: -46.63,
          segundo: 0,
          precisao: 25,
        ),
      );

      expect(resultado.aceito, isFalse);
      expect(resultado.motivoDescarte, MotivoDescarteGps.precisaoInsuficiente);
    });

    test('descarta leitura sem precisao informada pelo dispositivo', () {
      final resultado = FiltroGpsCorrida.avaliar(
        atual: ponto(
          latitude: -23.55,
          longitude: -46.63,
          segundo: 0,
          precisao: 0,
          temPrecisao: false,
        ),
      );

      expect(resultado.aceito, isFalse);
      expect(resultado.motivoDescarte, MotivoDescarteGps.precisaoIndisponivel);
    });

    test('descarta variação pequena causada por ruído do GPS', () {
      final anterior = ponto(latitude: -23.55, longitude: -46.63, segundo: 0);
      final resultado = FiltroGpsCorrida.avaliar(
        atual: ponto(latitude: -23.55, longitude: -46.62999, segundo: 5),
        anteriorAceito: anterior,
      );

      expect(resultado.aceito, isFalse);
      expect(resultado.motivoDescarte, MotivoDescarteGps.movimentoMuitoCurto);
    });

    test('descarta salto incompatível com velocidade de corrida', () {
      final anterior = ponto(latitude: -23.55, longitude: -46.63, segundo: 0);
      final resultado = FiltroGpsCorrida.avaliar(
        atual: ponto(latitude: -23.55, longitude: -46.629, segundo: 1),
        anteriorAceito: anterior,
      );

      expect(resultado.aceito, isFalse);
      expect(resultado.motivoDescarte, MotivoDescarteGps.velocidadeImprovavel);
    });

    test('aceita deslocamento plausível e retorna a distância', () {
      final anterior = ponto(latitude: -23.55, longitude: -46.63, segundo: 0);
      final resultado = FiltroGpsCorrida.avaliar(
        atual: ponto(latitude: -23.55, longitude: -46.6299, segundo: 10),
        anteriorAceito: anterior,
      );

      expect(resultado.aceito, isTrue);
      expect(resultado.distanciaMetros, greaterThan(5));
      expect(resultado.distanciaMetros, lessThan(20));
    });
  });
}
