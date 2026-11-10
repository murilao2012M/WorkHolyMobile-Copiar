import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/main.dart';

void main() {
  for (final automatico in [true, false]) {
    testWidgets(
      'registra RPE e RIR na finalização ${automatico ? 'automática' : 'manual'}',
      (tester) async {
        SessaoTreino? enviada;
        final sessao = SessaoTreino(
          id: 'sessao',
          treinoId: 'workfit_treino',
          nomeTreino: 'Treino',
          inicio: DateTime(2026, 1, 1),
          fim: null,
          workfitPlanoId: 'plano',
          series: const [
            SerieExecutada(
              id: 'serie',
              exercicioId: 'exercicio',
              nomeExercicio: 'Agachamento',
              numeroSerie: 1,
              repeticoesPlanejadas: 8,
              repeticoesRealizadas: 8,
              cargaKg: 10,
              concluida: false,
              descansoSegundos: 60,
            ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: ExecucaoTreinoPage(
              sessaoInicial: sessao,
              onSalvar: (atualizada) async {
                if (atualizada.finalizada) {
                  enviada = atualizada;
                  throw StateError('falha simulada');
                }
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> animar() async {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        }

        if (automatico) {
          await tester.ensureVisible(find.text('Concluir série'));
          await tester.tap(find.text('Concluir série'));
          await animar();
        } else {
          await tester.ensureVisible(find.text('Finalizar treino'));
          await tester.tap(find.text('Finalizar treino'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Finalizar'));
          await animar();
        }
        expect(find.text('Como foi o esforço?'), findsOneWidget);
        final listas = find.byType(DropdownButtonFormField<int>);
        await tester.tap(listas.at(0));
        await animar();
        await tester.tap(find.text('7').last);
        await animar();
        await tester.tap(listas.at(1));
        await animar();
        await tester.tap(find.text('3').last);
        await animar();
        await tester.tap(find.text('Concluir'));
        await tester.pumpAndSettle();
        expect(enviada!.rpe, 7);
        expect(enviada!.rir, 3);
        expect(enviada!.workfitPlanoId, 'plano');
        expect(find.textContaining('falha simulada'), findsOneWidget);
      },
    );
  }
}
