import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/midia/midia_exercicio.dart';

void main() {
  test('validarLinkMidia aceita http(s) e acrescenta https', () {
    expect(
      validarLinkMidia('youtube.com/watch?v=1')?.toString(),
      'https://youtube.com/watch?v=1',
    );
    expect(validarLinkMidia('http://vimeo.com/1')?.scheme, 'http');
  });

  test('validarLinkMidia rejeita entradas inválidas', () {
    expect(validarLinkMidia(''), isNull);
    expect(validarLinkMidia('javascript:alert(1)'), isNull);
    expect(validarLinkMidia('ftp://site.com/a'), isNull);
    expect(validarLinkMidia('com espaço.com'), isNull);
    expect(validarLinkMidia('semponto'), isNull);
  });

  test('MidiaExercicio converte de e para JSON', () {
    final midia = MidiaExercicio(
      id: 'm1',
      tipo: TipoMidia.video,
      destino: '/a/b.mp4',
      legenda: 'Vista lateral',
    );
    final lida = MidiaExercicio.fromJson(midia.toJson())!;
    expect(lida.id, 'm1');
    expect(lida.tipo, TipoMidia.video);
    expect(lida.destino, '/a/b.mp4');
    expect(lida.legenda, 'Vista lateral');
  });

  test('fromJson ignora registros inválidos', () {
    expect(MidiaExercicio.fromJson('x'), isNull);
    expect(MidiaExercicio.fromJson({'tipo': 'foto', 'destino': ''}), isNull);
    expect(MidiaExercicio.fromJson({'tipo': 'gif', 'destino': 'a'}), isNull);
  });
}
