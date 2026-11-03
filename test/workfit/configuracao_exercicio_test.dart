import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/main.dart';

void main() {
  test('itens antigos mantêm progressão e nova preferência é persistida', () {
    final antigo = ItemTreino.fromJson({
      'id': 'i',
      'treinoId': 't',
      'exercicioId': 'e',
    });
    expect(antigo.progressaoAtiva, isTrue);
    final desativado = ItemTreino(
      treinoId: 't',
      exercicioId: 'e',
      series: 2,
      repeticoes: 10,
      cargaKg: 5,
      descansoSegundos: 60,
      progressaoAtiva: false,
    );
    expect(ItemTreino.fromJson(desativado.toJson()).progressaoAtiva, isFalse);
  });

  testWidgets('cadastro simplificado preserva valores anteriores', (
    tester,
  ) async {
    final antigo = Exercicio(
      id: 'e',
      nome: 'Agachamento',
      grupo: 'Pernas',
      series: 5,
      repeticoes: 6,
      catalogoId: 'catalogo',
    );
    Exercicio? resultado;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              resultado = await showDialog<Exercicio>(
                context: context,
                builder: (_) => FormularioExercicioDialog(existente: antigo),
              );
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Séries'), findsNothing);
    expect(find.text('Repetições'), findsNothing);
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(resultado!.series, 5);
    expect(resultado!.repeticoes, 6);
    expect(resultado!.catalogoId, 'catalogo');
  });

  testWidgets('progressão pode ser desativada na configuração', (tester) async {
    final item = ItemTreino(
      id: 'i',
      treinoId: 't',
      exercicioId: 'e',
      series: 3,
      repeticoes: 8,
      cargaKg: 10,
      descansoSegundos: 60,
    );
    ItemTreino? resultado;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              resultado = await showDialog<ItemTreino>(
                context: context,
                builder: (_) => ConfiguracaoExercicioDialog(
                  item: item,
                  nomeExercicio: 'Agachamento',
                ),
              );
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(resultado!.progressaoAtiva, isFalse);
    expect(resultado!.series, 3);
    expect(resultado!.cargaKg, 10);
  });
}
