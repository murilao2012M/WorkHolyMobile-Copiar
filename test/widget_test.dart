import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workholy_mobile/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('WorkHoly inicia com o painel principal', (tester) async {
    await tester.pumpWidget(const WorkHolyApp());

    // Aguarda um quadro da interface sem esperar que todas
    // as animações terminem.
    await tester.pump();

    expect(find.byType(WorkHolyApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
