import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workholy_mobile/dados/workholy_banco.dart';
import 'package:workholy_mobile/main.dart';
import 'package:workholy_mobile/workfit/workfit_ciclo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory diretorio;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    diretorio = await Directory.systemTemp.createTemp('workfit_ajustes_');
    await databaseFactory.setDatabasesPath(diretorio.path);
    SharedPreferences.setMockInitialValues({});
    await WorkHolyBanco.instancia.preparar();
  });

  tearDownAll(() async {
    await (await WorkHolyBanco.instancia.database).close();
    await diretorio.delete(recursive: true);
  });

  testWidgets('ajuste exige confirmação e preserva dados se salvar falhar', (
    tester,
  ) async {
    final exercicio = Exercicio(
      id: 'exercicio',
      nome: 'Agachamento',
      grupo: 'Pernas',
      series: 2,
      repeticoes: 8,
    );
    final item = ItemTreino(
      id: 'item',
      treinoId: 'workfit_treino',
      exercicioId: exercicio.id,
      series: 2,
      repeticoes: 8,
      cargaKg: 10,
      descansoSegundos: 60,
    );
    final sessao = SessaoTreino(
      id: 'sessao',
      treinoId: item.treinoId,
      nomeTreino: 'Treino',
      inicio: DateTime(2026, 1, 1),
      fim: DateTime(2026, 1, 1, 1),
      series: [
        for (var numero = 1; numero <= 2; numero++)
          SerieExecutada(
            id: 'serie-$numero',
            exercicioId: exercicio.id,
            nomeExercicio: exercicio.nome,
            numeroSerie: numero,
            repeticoesPlanejadas: 8,
            repeticoesRealizadas: 8,
            cargaKg: 10,
            concluida: true,
            descansoSegundos: 60,
          ),
      ],
    );
    var falhar = true;
    var tentativas = 0;
    final sessoes = [sessao];
    List<ItemTreino>? salvos;
    await tester.pumpWidget(
      MaterialApp(
        home: DetalheTreinoPage(
          treino: Treino(id: item.treinoId, nome: 'Treino', objetivo: ''),
          exerciciosDisponiveis: [exercicio],
          itensIniciais: [item],
          sessoesTreino: sessoes,
          onSalvar: (novos) async {
            tentativas++;
            if (falhar) throw StateError('falha de gravação');
            salvos = novos;
          },
          onIniciarTreino: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> abrirSugestao() async {
      await tester.tap(find.byTooltip('Sugerir ajustes'));
      await tester.pumpAndSettle();
      expect(find.text('Agachamento: 8 → 9 repetições'), findsOneWidget);
    }

    await abrirSugestao();
    await tester.tap(find.text('Agora não'));
    await tester.pumpAndSettle();
    expect(salvos, isNull);

    await abrirSugestao();
    await tester.tap(find.text('Aplicar ajustes'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Não foi possível salvar os ajustes'),
      findsOneWidget,
    );
    expect(salvos, isNull);

    falhar = false;
    await abrirSugestao();
    await tester.tap(find.text('Aplicar ajustes'));
    await tester.pumpAndSettle();
    expect(salvos!.single.repeticoes, 9);
    expect(salvos!.single.cargaKg, 10);
    expect(sessao.series.first.repeticoesPlanejadas, 8);

    await tester.tap(find.byTooltip('Sugerir ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Sugestões para o próximo treino'), findsNothing);
    expect(tentativas, 2);

    sessoes.add(
      SessaoTreino(
        id: 'sessao-aberta',
        treinoId: item.treinoId,
        nomeTreino: 'Treino',
        inicio: DateTime(2026, 1, 2),
        fim: null,
        series: [],
      ),
    );
    await tester.tap(find.byTooltip('Sugerir ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Sugestões para o próximo treino'), findsNothing);
    expect(tentativas, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'carga e recuperação exigem confirmação e não se repetem no ciclo',
    (tester) async {
      final exercicio = Exercicio(
        id: 'exercicio',
        nome: 'Agachamento',
        grupo: 'Pernas',
        series: 2,
        repeticoes: 8,
      );
      final item = ItemTreino(
        id: 'item',
        treinoId: 'workfit_treino',
        exercicioId: exercicio.id,
        series: 2,
        repeticoes: 8,
        cargaKg: 10,
        descansoSegundos: 60,
      );
      SessaoTreino sessao(String id, int dias, {int series = 2}) =>
          SessaoTreino(
            id: id,
            treinoId: item.treinoId,
            nomeTreino: 'Treino',
            inicio: DateTime.now().subtract(Duration(days: dias, hours: 1)),
            fim: DateTime.now().subtract(Duration(days: dias)),
            workfitPlanoId: 'plano',
            rpe: 7,
            rir: 3,
            series: [
              for (var numero = 1; numero <= series; numero++)
                SerieExecutada(
                  id: '$id-$numero',
                  exercicioId: exercicio.id,
                  nomeExercicio: exercicio.nome,
                  numeroSerie: numero,
                  repeticoesPlanejadas: 8,
                  repeticoesRealizadas: 8,
                  cargaKg: 10,
                  concluida: true,
                  descansoSegundos: 60,
                ),
            ],
          );
      List<ItemTreino>? salvos;
      final sessoes = [sessao('anterior', 2), sessao('recente', 1)];
      Future<void> mostrar(int diasCiclo) async {
        await tester.pumpWidget(
          MaterialApp(
            home: DetalheTreinoPage(
              key: ValueKey(diasCiclo),
              treino: Treino(
                id: item.treinoId,
                nome: 'Treino',
                objetivo: '',
                workfitCiclo: WorkFitCiclo(
                  id: 'plano',
                  inicio: DateTime.now().subtract(Duration(days: diasCiclo)),
                  diasPorSemana: 3,
                  modalidade: 'musculacao',
                ),
              ),
              exerciciosDisponiveis: [exercicio],
              itensIniciais: [item],
              sessoesTreino: sessoes,
              onSalvar: (novos) async {
                salvos = novos;
              },
              onIniciarTreino: () async {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump();
        await tester.tap(find.byTooltip('Sugerir ajustes'));
        await tester.pumpAndSettle();
      }

      await mostrar(10);
      expect(find.text('Agachamento: 10.0 → 10.5 kg'), findsOneWidget);
      await tester.tap(find.text('Agora não'));
      await tester.pumpAndSettle();
      expect(salvos, isNull);

      await mostrar(29);
      expect(
        find.text('Agachamento: 2 → 1 séries (recuperação)'),
        findsOneWidget,
      );
      await tester.tap(find.text('Aplicar ajustes'));
      await tester.pumpAndSettle();
      expect(salvos!.single.series, 1);
      expect(salvos!.single.cargaKg, 10);
      expect(salvos!.single.workfitCicloRecuperado, 'plano');
      sessoes.add(sessao('outra', 0, series: 1));
      await tester.tap(find.byTooltip('Sugerir ajustes'));
      await tester.pumpAndSettle();
      expect(find.text('Sugestões para o próximo treino'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('progressão desativada não impede sugestão de recuperação', (
    tester,
  ) async {
    final exercicio = Exercicio(
      id: 'exercicio',
      nome: 'Agachamento',
      grupo: 'Pernas',
      series: 2,
      repeticoes: 8,
    );
    final item = ItemTreino(
      id: 'item',
      treinoId: 'treino',
      exercicioId: exercicio.id,
      series: 2,
      repeticoes: 8,
      cargaKg: 10,
      descansoSegundos: 60,
      progressaoAtiva: false,
    );
    SessaoTreino sessao(int? rpe) => SessaoTreino(
      id: 'sessao',
      treinoId: 'treino',
      nomeTreino: 'Treino',
      inicio: DateTime(2026, 1, 1),
      fim: DateTime(2026, 1, 1, 1),
      rpe: rpe,
      series: [
        for (var n = 1; n <= 2; n++)
          SerieExecutada(
            id: 'serie-$n',
            exercicioId: exercicio.id,
            nomeExercicio: exercicio.nome,
            numeroSerie: n,
            repeticoesPlanejadas: 8,
            repeticoesRealizadas: 8,
            cargaKg: 10,
            concluida: true,
            descansoSegundos: 60,
          ),
      ],
    );
    Future<void> mostrar(int? rpe) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DetalheTreinoPage(
            key: ValueKey(rpe),
            treino: Treino(id: 'treino', nome: 'Treino', objetivo: ''),
            exerciciosDisponiveis: [exercicio],
            itensIniciais: [item],
            sessoesTreino: [sessao(rpe)],
            onSalvar: (_) async {},
            onIniciarTreino: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Sugerir ajustes'));
      await tester.pumpAndSettle();
    }

    await mostrar(7);
    expect(find.text('Agachamento: sem alteração'), findsOneWidget);
    expect(find.text('Aplicar ajustes'), findsNothing);
    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();
    await mostrar(9);
    expect(
      find.text('Agachamento: 2 → 1 séries (recuperação)'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
