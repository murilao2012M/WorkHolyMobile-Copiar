import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workholy_mobile/corrida/corrida_banco.dart';
import 'package:workholy_mobile/dados/workholy_banco.dart';
import 'package:workholy_mobile/perfil_praticante_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory bancoTemporario;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    bancoTemporario = await Directory.systemTemp.createTemp(
      'workholy_perfil_test_',
    );
    await databaseFactory.setDatabasesPath(bancoTemporario.path);
    SharedPreferences.setMockInitialValues({});
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  tearDownAll(() async {
    await CorridaBanco.instancia.fechar();
    await (await WorkHolyBanco.instancia.database).close();
    await bancoTemporario.delete(recursive: true);
  });

  testWidgets('não coleta medidas e preserva as já salvas', (tester) async {
    final banco = WorkHolyBanco.instancia;
    await tester.runAsync(() async {
      await banco.salvarBooleano('workholy_assinatura_premium_ativa_v1', true);
      await banco.salvarTexto(
        chavePerfilPraticante,
        jsonEncode({
          'nome': 'Ana',
          'peso': '70',
          'medidas': {'Cintura': '80', 'Quadril': '95'},
        }),
      );
      await CorridaBanco.instancia.listarFinalizadas();
    });

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PerfilPraticantePage())),
    );
    for (
      var i = 0;
      i < 200 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(find.text('Meu perfil'), findsOneWidget);
    expect(find.text('Medidas atuais'), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Cintura'), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Quadril'), findsNothing);

    await tester.scrollUntilVisible(
      find.byTooltip('Nova avaliação'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byTooltip('Nova avaliação'));
    await tester.tap(find.byTooltip('Nova avaliação'));
    await tester.pumpAndSettle();
    expect(find.text('Peso'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Cintura'), findsNothing);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byTooltip('Criar meta'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byTooltip('Criar meta'));
    await tester.tap(find.byTooltip('Criar meta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Peso corporal').last);
    await tester.pumpAndSettle();
    expect(find.text('Medida corporal'), findsNothing);
    await tester.tap(find.text('Treinos por semana').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.widgetWithText(TextFormField, 'Nome'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.widgetWithText(TextFormField, 'Nome'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome'),
      'Ana Clara',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Salvar dados atuais'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Salvar dados atuais'));
    await tester.tap(find.text('Salvar dados atuais'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    final texto = await tester.runAsync(
      () => banco.lerTexto(chavePerfilPraticante),
    );
    final salvo = jsonDecode(texto!) as Map;
    expect(salvo['medidas'], {'Cintura': '80', 'Quadril': '95'});
    expect(salvo['nome'], 'Ana Clara');
    await tester.pump(const Duration(seconds: 3));
  });
}
