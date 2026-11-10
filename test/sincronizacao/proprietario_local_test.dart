import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/sincronizacao/sincronizacao_usuario.dart';

void main() {
  test('permite acesso aos dados da mesma conta', () {
    expect(
      () => verificarProprietarioLocal('conta-a', 'conta-a'),
      returnsNormally,
    );
  });

  test('permite preparar dados ainda sem proprietário', () {
    expect(() => verificarProprietarioLocal(null, 'conta-a'), returnsNormally);
  });

  test('bloqueia outra conta sem apagar os dados anteriores', () {
    expect(
      () => verificarProprietarioLocal('conta-a', 'conta-b'),
      throwsA(isA<TrocaDeContaBloqueada>()),
    );
  });

  test(
    'tentativa de sincronização informa que o backup está desativado',
    () async {
      await expectLater(
        SincronizacaoUsuario.instancia.sincronizarAgora(),
        throwsStateError,
      );
    },
  );
}
