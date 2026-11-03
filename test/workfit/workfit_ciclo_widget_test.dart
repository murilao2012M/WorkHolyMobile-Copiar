import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/workfit/workfit_ciclo.dart';
import 'package:workholy_mobile/workfit/workfit_ciclo_card.dart';
import 'package:workholy_mobile/workfit/workfit_esforco_dialog.dart';
import 'package:workholy_mobile/workfit/workfit_selecao_corrida.dart';

void main() {
  final ciclo = WorkFitCiclo(
    id: 'plano-a',
    inicio: DateTime(2026, 1, 1),
    diasPorSemana: 5,
    modalidade: 'corrida',
  );
  testWidgets('aviso considera apenas semana completa e limiar de 80%', (
    tester,
  ) async {
    Future<void> mostrar(int dias) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkFitCicloCard(
              ciclo: ciclo,
              agora: DateTime(2026, 1, 8),
              sessoes: [
                for (var dia = 1; dia <= dias; dia++)
                  DiaConcluidoWorkFit(
                    planoId: ciclo.id,
                    data: DateTime(2026, 1, dia),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await mostrar(4);
    expect(find.textContaining('abaixo de 80%'), findsNothing);
    await mostrar(3);
    expect(find.textContaining('abaixo de 80%'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkFitCicloCard(
            ciclo: ciclo,
            agora: DateTime(2026, 1, 8),
            sessoes: const [],
            dadosDisponiveis: false,
          ),
        ),
      ),
    );
    expect(find.textContaining('aderência está indisponível'), findsOneWidget);
    expect(find.textContaining('abaixo de 80%'), findsNothing);
  });

  testWidgets('corrida pode ser vinculada ou mantida avulsa', (tester) async {
    SelecaoCicloCorrida? resultado;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                resultado = await showDialog<SelecaoCicloCorrida>(
                  context: context,
                  builder: (_) => SelecaoCicloCorridaDialog(ciclos: [ciclo]),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Ciclo 01/01/2026'));
    await tester.pumpAndSettle();
    expect(resultado!.planoId, ciclo.id);
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Corrida avulsa, sem vínculo'));
    await tester.pumpAndSettle();
    expect(resultado, isNotNull);
    expect(resultado!.planoId, isNull);
  });

  testWidgets('corrida permite RPE sem exibir RIR', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WorkFitEsforcoDialog(permiteRir: false)),
      ),
    );
    expect(find.text('RPE da sessão'), findsOneWidget);
    expect(find.text('RIR da sessão'), findsNothing);
  });

  testWidgets('mostra sugestão de recuperação para esforço alto na corrida', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkFitCicloCard(
            ciclo: ciclo,
            agora: DateTime(2026, 1, 8),
            sessoes: const [],
            temCorrida: true,
            ultimoRpeCorrida: 9,
          ),
        ),
      ),
    );
    expect(find.textContaining('atividade mais leve'), findsOneWidget);
  });
}
