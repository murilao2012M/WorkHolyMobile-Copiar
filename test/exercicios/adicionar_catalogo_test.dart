import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workholy_mobile/dados/workholy_banco.dart';
import 'package:workholy_mobile/exercicios/biblioteca_exercicios.dart';
import 'package:workholy_mobile/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<ExercicioPredefinido> catalogo;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    catalogo = await CatalogoExercicios.instancia.carregar();
  });

  test(
    'catálogo inteiro preserva dados, IDs e persiste após reabrir',
    () async {
      SharedPreferences.setMockInitialValues({});
      final diretorio = await Directory.systemTemp.createTemp(
        'workholy_catalogo_',
      );
      final caminho = p.join(diretorio.path, 'dados.db');
      final banco = WorkHolyBanco.paraTestes(caminho: caminho);
      final primeiro = catalogo.first;
      final antigo = {
        'id': 'antigo',
        'nome': primeiro.nome,
        'grupo': primeiro.grupo,
        'series': 3,
        'repeticoes': 12,
      };
      final treino = {'id': 'treino', 'nome': 'Meu treino'};
      final item = {
        'id': 'item',
        'treinoId': 'treino',
        'exercicioId': 'antigo',
      };
      final sessao = {'id': 'sessao', 'treinoId': 'treino'};
      await banco.salvarDadosTreino(
        treinos: [treino],
        exercicios: [antigo],
        itensTreino: [item],
        sessoesTreino: [sessao],
      );
      final versaoAntes = await banco.versaoAlteracoes();
      final candidatos = catalogo
          .map(
            (exercicio) => {
              'id': 'catalogo-${exercicio.id}',
              'catalogoId': exercicio.id,
              'nome': exercicio.nome,
              'grupo': exercicio.grupo,
              'series': exercicio.series,
              'repeticoes': exercicio.repeticoes,
            },
          )
          .toList();

      expect(
        await banco.adicionarExerciciosDoCatalogo(candidatos),
        hasLength(876),
      );
      final versaoDepois = await banco.versaoAlteracoes();
      expect(versaoDepois, versaoAntes + 876);
      expect(await banco.adicionarExerciciosDoCatalogo(candidatos), isEmpty);
      expect(await banco.versaoAlteracoes(), versaoDepois);
      var dados = await banco.carregarDadosTreino();
      expect(dados.exercicios, hasLength(877));
      expect(dados.exercicios.first, antigo);
      expect(
        dados.exercicios.skip(1).map((e) => e['catalogoId']).toSet(),
        hasLength(876),
      );
      expect(dados.treinos, [treino]);
      expect(dados.itensTreino, [item]);
      expect(dados.sessoesTreino, [sessao]);
      final nomesGrupos = catalogo.map((e) => '${e.nome}|${e.grupo}').toSet();
      expect(nomesGrupos.length, lessThan(catalogo.length));
      await (await banco.database).close();

      final reaberto = WorkHolyBanco.paraTestes(caminho: caminho);
      dados = await reaberto.carregarDadosTreino();
      expect(dados.exercicios, hasLength(877));
      expect(dados.exercicios.first, antigo);
      expect(dados.itensTreino, [item]);
      expect(await reaberto.versaoAlteracoes(), versaoDepois);
      await (await reaberto.database).close();
      await diretorio.delete(recursive: true);
    },
  );

  test('erro de inserção reverte todo o lote e o contador', () async {
    SharedPreferences.setMockInitialValues({});
    final diretorio = await Directory.systemTemp.createTemp(
      'workholy_catalogo_',
    );
    final banco = WorkHolyBanco.paraTestes(
      caminho: p.join(diretorio.path, 'dados.db'),
    );
    await banco.salvarDadosTreino(
      treinos: [],
      exercicios: [
        {'id': 'existente', 'nome': 'Antigo', 'grupo': 'Outros'},
      ],
      itensTreino: [],
      sessoesTreino: [],
    );
    final versao = await banco.versaoAlteracoes();
    await expectLater(
      banco.adicionarExerciciosDoCatalogo([
        {
          'id': 'novo',
          'catalogoId': 'cat-1',
          'nome': 'Mesmo',
          'grupo': 'Pernas',
        },
        {
          'id': 'existente',
          'catalogoId': 'cat-2',
          'nome': 'Mesmo',
          'grupo': 'Pernas',
        },
      ]),
      throwsA(isA<DatabaseException>()),
    );
    expect((await banco.carregarDadosTreino()).exercicios, hasLength(1));
    expect(await banco.versaoAlteracoes(), versao);
    await (await banco.database).close();
    await diretorio.delete(recursive: true);
  });

  test('identidade do catálogo é opcional e persiste no modelo', () {
    final antigo = Exercicio.fromJson({'id': 'antigo', 'nome': 'Antigo'});
    expect(antigo.catalogoId, isNull);
    final novo = Exercicio(
      id: 'novo',
      nome: 'Nome',
      grupo: 'Pernas',
      series: 3,
      repeticoes: 12,
      catalogoId: 'original',
    );
    expect(Exercicio.fromJson(novo.toJson()).catalogoId, 'original');
  });

  testWidgets('editar exercício preserva o ID do catálogo', (tester) async {
    final original = Exercicio(
      id: 'salvo',
      nome: 'Nome',
      grupo: 'Pernas',
      series: 3,
      repeticoes: 12,
      catalogoId: 'original',
    );
    Exercicio? resultado;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                resultado = await showDialog<Exercicio>(
                  context: context,
                  builder: (_) =>
                      FormularioExercicioDialog(existente: original),
                );
              },
              child: const Text('Editar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Nome alterado');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(resultado?.nome, 'Nome alterado');
    expect(resultado?.id, 'salvo');
    expect(resultado?.catalogoId, 'original');
  });

  testWidgets('confirmação usa catálogo completo, inclusive com filtro', (
    tester,
  ) async {
    final existente = catalogo.first;
    final concluido = Completer<int>();
    List<ExercicioPredefinido>? recebidos;
    await tester.pumpWidget(
      MaterialApp(
        home: BibliotecaExerciciosPage(
          exerciciosCadastrados: [
            Exercicio(
              nome: existente.nome,
              grupo: existente.grupo,
              series: 3,
              repeticoes: 12,
              catalogoId: existente.id,
            ),
          ],
          onAdicionar: (exercicios) {
            recebidos = exercicios;
            return concluido.future;
          },
        ),
      ),
    );
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Adicionar todos (875 restantes)'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'termo inexistente 12345');
    await tester.pumpAndSettle();
    expect(find.text('Nenhum exercício encontrado.'), findsOneWidget);
    await tester.tap(find.text('Adicionar todos (875 restantes)'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('inclusive os que não aparecem nos filtros'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(recebidos, isNull);
    await tester.tap(find.text('Adicionar todos (875 restantes)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar todos'));
    await tester.pump();
    expect(recebidos, hasLength(875));
    expect(recebidos!.map((e) => e.id), isNot(contains(existente.id)));
    expect(find.text('Adicionando exercícios. Aguarde...'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
    concluido.complete(875);
    await tester.pumpAndSettle();
    expect(
      find.text('875 exercícios adicionados. 1 já estavam no acervo.'),
      findsOneWidget,
    );
    expect(find.text('Adicionar todos (0 restantes)'), findsOneWidget);
  });

  testWidgets(
    'combina equipamento, grupo e busca sem limitar adicionar todos',
    (tester) async {
      List<ExercicioPredefinido>? recebidos;
      await tester.pumpWidget(
        MaterialApp(
          home: BibliotecaExerciciosPage(
            exerciciosCadastrados: const [],
            onAdicionar: (itens) async {
              recebidos = itens;
              return itens.length;
            },
          ),
        ),
      );
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('Halteres'),
        find.byType(Scrollable).last,
        const Offset(0, -180),
      );
      await tester.tap(find.text('Halteres').last);
      await tester.pumpAndSettle();
      expect(find.text('123 de 876 exercícios disponíveis'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Braços'));
      await tester.pumpAndSettle();
      final bracos = catalogo
          .where(
            (item) =>
                item.equipamentoParaFiltro == 'Halteres' &&
                item.grupo == 'Braços',
          )
          .toList();
      expect(
        find.text('${bracos.length} de 876 exercícios disponíveis'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'termo inexistente 12345');
      await tester.pumpAndSettle();
      expect(find.text('0 de 876 exercícios disponíveis'), findsOneWidget);
      await tester.tap(find.text('Adicionar todos (876 restantes)'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Adicionar todos'));
      await tester.pumpAndSettle();
      expect(recebidos, hasLength(876));

      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('Todos os equipamentos'),
        find.byType(Scrollable).last,
        const Offset(0, 180),
      );
      await tester.tap(find.text('Todos os equipamentos').last);
      await tester.pumpAndSettle();
      final totalBracos = catalogo
          .where((item) => item.grupo == 'Braços')
          .length;
      expect(
        find.text('$totalBracos de 876 exercícios disponíveis'),
        findsOneWidget,
      );
    },
  );

  testWidgets('falha no lote é informada e permite tentar novamente', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BibliotecaExerciciosPage(
          exerciciosCadastrados: const [],
          onAdicionar: (_) async => throw StateError('erro de teste'),
        ),
      ),
    );
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Adicionar todos (876 restantes)'), findsOneWidget);
    await tester.tap(find.text('Adicionar todos (876 restantes)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar todos'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nenhuma alteração foi salva.'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNotNull,
    );
  });
}
