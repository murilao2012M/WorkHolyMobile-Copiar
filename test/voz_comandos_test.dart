import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/voz/comandos_voz.dart';

void main() {
  test('reconhece comandos com acento e variações', () {
    expect(interpretarComandoVoz('Pausar'), ComandoVoz.pausar);
    expect(interpretarComandoVoz('pare'), ComandoVoz.pausar);
    expect(interpretarComandoVoz('continuar'), ComandoVoz.retomar);
    expect(interpretarComandoVoz('Próximo!'), ComandoVoz.proximo);
    expect(interpretarComandoVoz('série concluída'), ComandoVoz.serieConcluida);
    expect(
      interpretarComandoVoz('terminei a série'),
      ComandoVoz.serieConcluida,
    );
    expect(interpretarComandoVoz('finalizar treino'), ComandoVoz.finalizar);
    expect(interpretarComandoVoz('repetir'), ComandoVoz.repetir);
  });

  test('frase desconhecida ou vazia não executa nada', () {
    expect(interpretarComandoVoz(''), isNull);
    expect(interpretarComandoVoz('que horas são'), isNull);
  });
}
