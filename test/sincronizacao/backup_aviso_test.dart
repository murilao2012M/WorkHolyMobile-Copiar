import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/sincronizacao/backup_aviso.dart';
import 'package:workholy_mobile/sincronizacao/sincronizacao_usuario.dart';

void main() {
  final servico = SincronizacaoUsuario.instancia;

  tearDown(() {
    servico.estado.value = const EstadoBackup(SituacaoBackup.desativado);
  });

  testWidgets('backup permanece bloqueado na compilação padrão', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BackupAviso(restaurar: (_, _) async {})),
      ),
    );
    expect(
      find.textContaining('Backup na nuvem em preparação'),
      findsOneWidget,
    );
    expect(find.text('Ativar backup'), findsNothing);
    await expectLater(servico.ativar(), throwsStateError);
  });

  testWidgets(
    'exige confirmação para ativar e informa quais dados são enviados',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BackupAviso(
              restaurar: (_, _) async {},
              recursoDisponivel: true,
            ),
          ),
        ),
      );
      expect(find.textContaining('somente neste aparelho'), findsOneWidget);
      await tester.tap(find.text('Ativar backup'));
      await tester.pumpAndSettle();
      expect(find.textContaining('incluindo rotas'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(servico.estado.value.situacao, SituacaoBackup.desativado);
    },
  );

  testWidgets('conflito apresenta as opções e exige confirmar restauração', (
    tester,
  ) async {
    servico.estado.value = const EstadoBackup(
      SituacaoBackup.conflito,
      versaoRemota: 'remota',
    );
    var restaurou = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BackupAviso(
            restaurar: (_, _) async => restaurou = true,
            recursoDisponivel: true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Resolver conflito'));
    await tester.pumpAndSettle();
    expect(find.text('Usar este aparelho'), findsOneWidget);
    await tester.tap(find.text('Usar a nuvem'));
    await tester.pumpAndSettle();
    expect(find.text('Restaurar esta versão?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(restaurou, isFalse);
  });
}
