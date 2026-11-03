import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/exercicios/aviso_atividade_fisica.dart';

void main() {
  for (final decisao in ['Voltar', 'Continuar']) {
    testWidgets('aviso retorna decisão ao selecionar $decisao', (tester) async {
      bool? resultado;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  resultado = await mostrarAvisoAtividadeFisica(context);
                },
                child: const Text('Iniciar'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Iniciar'));
      await tester.pumpAndSettle();
      expect(find.text('Aviso importante'), findsOneWidget);
      expect(find.textContaining('procurar um médico'), findsOneWidget);
      expect(
        find.textContaining('registrado no conselho profissional'),
        findsOneWidget,
      );

      await tester.tap(find.text(decisao));
      await tester.pumpAndSettle();
      expect(resultado, decisao == 'Continuar');
      expect(find.text('Aviso importante'), findsNothing);
    });
  }
}
