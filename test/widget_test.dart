import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workholy_mobile/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    SharedPreferences.setMockInitialValues({});

    // Inicializa o Firebase para os testes sem usar um projeto real.
    setupFirebaseCoreMocks();

    await Firebase.initializeApp();
  });

  testWidgets('WorkHoly inicia com a tela principal do aplicativo', (
    tester,
  ) async {
    await tester.pumpWidget(const WorkHolyApp());

    await tester.pump();

    expect(find.byType(WorkHolyApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
