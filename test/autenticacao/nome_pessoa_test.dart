import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/autenticacao/nome_pessoa.dart';
import 'package:workholy_mobile/tela_boas_vindas_page.dart';

void main() {
  test('extrai o primeiro nome e trata nome ausente', () {
    expect(primeiroNome('  Maria   da Silva '), 'Maria');
    expect(primeiroNome('João'), 'João');
    expect(primeiroNome(' \t '), isNull);
    expect(primeiroNome(null), isNull);
  });

  testWidgets('boas-vindas usam o nome sem bloquear o começo', (tester) async {
    var comecou = false;
    await tester.pumpWidget(
      MaterialApp(
        home: TelaBoasVindasPage(
          nome: 'Maria',
          onComecar: () => comecou = true,
        ),
      ),
    );
    expect(find.text('Maria, seu treino. Sua evolução.'), findsOneWidget);
    await tester.tap(find.text('Começar'));
    expect(comecou, isTrue);
  });

  testWidgets('boas-vindas sem nome não exibem dado inventado', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: TelaBoasVindasPage(onComecar: () {})),
    );
    expect(find.text('Seu treino. Sua evolução.'), findsOneWidget);
  });
}
