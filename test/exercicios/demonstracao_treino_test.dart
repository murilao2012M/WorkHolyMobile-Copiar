import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/exercicios/biblioteca_exercicios.dart';
import 'package:workholy_mobile/main.dart';

const exercicioCatalogo = ExercicioPredefinido(
  id: 'cat-a',
  nome: 'Exercício de exemplo',
  grupo: 'Pernas',
  musculosPrimarios: [],
  musculosSecundarios: [],
  instrucoes: ['Posicione-se corretamente.', 'Execute o movimento.'],
  imagens: ['3_4_Sit-Up/0.jpg', '3_4_Sit-Up/1.jpg'],
);

const outroExercicio = ExercicioPredefinido(
  id: 'cat-b',
  nome: 'Exercício sem foto',
  grupo: 'Braços',
  musculosPrimarios: [],
  musculosSecundarios: [],
  instrucoes: ['Mantenha o controle.'],
  imagens: [],
);

SessaoTreino sessao({String? catalogoId}) => SessaoTreino(
  id: 'sessao',
  treinoId: 'treino',
  nomeTreino: 'Meu treino',
  inicio: DateTime(2026, 1, 1),
  fim: null,
  series: [
    for (var numero = 1; numero <= 2; numero++)
      SerieExecutada(
        id: 'serie-$numero',
        exercicioId: 'exercicio-local',
        nomeExercicio: 'Exercício personalizado',
        numeroSerie: numero,
        repeticoesPlanejadas: 10,
        repeticoesRealizadas: 10,
        cargaKg: 0,
        concluida: false,
        descansoSegundos: 30,
        catalogoId: catalogoId,
      ),
  ],
);

Future<void> animar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'catálogo real contém imagens acessíveis para o exercício identificado',
    () async {
      final catalogo = await CatalogoExercicios.instancia.carregar();
      final exercicio = catalogo.singleWhere((item) => item.id == '3_4_Sit-Up');
      expect(exercicio.caminhosImagensAssets, hasLength(2));
      for (final caminho in exercicio.caminhosImagensAssets) {
        expect((await rootBundle.load(caminho)).lengthInBytes, greaterThan(0));
      }
    },
  );

  test('séries antigas continuam válidas e preservam o ID ao copiar', () {
    final antiga = sessao().series.first;
    expect(SerieExecutada.fromJson(antiga.toJson()).catalogoId, isNull);
    final vinculada = antiga
        .copiar(catalogoId: 'cat-a')
        .copiar(concluida: true);
    final recuperada = SerieExecutada.fromJson(vinculada.toJson());
    expect(recuperada.catalogoId, 'cat-a');
    expect(recuperada.concluida, isTrue);
  });

  testWidgets('exibe imagens, instruções e mantém os controles do treino', (
    tester,
  ) async {
    SessaoTreino? salva;
    await tester.pumpWidget(
      MaterialApp(
        home: ExecucaoTreinoPage(
          sessaoInicial: sessao(catalogoId: 'cat-a'),
          carregarCatalogo: () async => [exercicioCatalogo],
          onSalvar: (valor) async => salva = valor,
        ),
      ),
    );
    await animar(tester);
    expect(find.text('Como executar'), findsOneWidget);
    expect(find.text('Demonstração: Exercício de exemplo'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    final imagem = tester.widget<Image>(find.byType(Image).first);
    expect(
      (imagem.image as AssetImage).assetName,
      'assets/exercicios/imagens/3_4_Sit-Up/0.jpg',
    );
    expect(
      find.textContaining('Deslize para ver as 2 imagens'),
      findsOneWidget,
    );
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await animar(tester);
    final imagens = tester.widgetList<Image>(find.byType(Image));
    expect(
      imagens.map((imagem) => (imagem.image as AssetImage).assetName),
      contains('assets/exercicios/imagens/3_4_Sit-Up/1.jpg'),
    );
    await tester.ensureVisible(find.text('Ver instruções'));
    await animar(tester);
    await tester.tap(find.text('Ver instruções'));
    await animar(tester);
    expect(find.text('1. Posicione-se corretamente.'), findsOneWidget);
    await tester.ensureVisible(find.text('Concluir série').first);
    await animar(tester);
    await tester.tap(find.text('Concluir série').first);
    await tester.pump();
    expect(salva!.series.first.concluida, isTrue);
    expect(salva!.series.first.catalogoId, 'cat-a');
    expect(find.text('TEMPO DE DESCANSO'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'permite escolher demonstração para sessão antiga e persistir nas séries',
    (tester) async {
      SessaoTreino? salva;
      await tester.pumpWidget(
        MaterialApp(
          home: ExecucaoTreinoPage(
            sessaoInicial: sessao(),
            carregarCatalogo: () async => [exercicioCatalogo, outroExercicio],
            onSalvar: (valor) async => salva = valor,
          ),
        ),
      );
      expect(find.textContaining('ainda não está vinculado'), findsOneWidget);
      await tester.tap(find.text('Escolher demonstração'));
      await animar(tester);
      await tester.enterText(find.byType(TextField).last, 'sem foto');
      await animar(tester);
      await tester.tap(find.text('Exercício sem foto').last);
      await animar(tester);
      expect(
        find.textContaining('Confira se são o mesmo movimento'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancelar'));
      await animar(tester);
      expect(salva, isNull);
      await tester.tap(find.text('Exercício sem foto').last);
      await animar(tester);
      await tester.tap(find.text('Usar demonstração'));
      await animar(tester);
      expect(salva!.series.every((s) => s.catalogoId == 'cat-b'), isTrue);
      expect(
        find.text('Este exercício não possui imagens no catálogo.'),
        findsOneWidget,
      );
      expect(find.text('Ver instruções'), findsOneWidget);
    },
  );

  testWidgets('retoma sessão antiga usando o vínculo salvo no exercício', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ExecucaoTreinoPage(
          sessaoInicial: sessao(),
          exercicios: [
            Exercicio(
              id: 'exercicio-local',
              nome: 'Exercício personalizado',
              grupo: 'Pernas',
              series: 2,
              repeticoes: 10,
              catalogoId: 'cat-a',
            ),
          ],
          carregarCatalogo: () async => [exercicioCatalogo],
          onSalvar: (_) async {},
        ),
      ),
    );
    await animar(tester);
    expect(find.text('Como executar'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('ID ausente no catálogo não mostra demonstração incorreta', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ExecucaoTreinoPage(
          sessaoInicial: sessao(catalogoId: 'inexistente'),
          carregarCatalogo: () async => [exercicioCatalogo],
          onSalvar: (_) async {},
        ),
      ),
    );
    await animar(tester);
    expect(
      find.textContaining('não foi encontrada no catálogo'),
      findsOneWidget,
    );
    expect(find.byType(PageView), findsNothing);
    expect(find.text('Escolher demonstração'), findsOneWidget);
  });

  testWidgets('mostra erro de carregamento sem impedir o treino', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ExecucaoTreinoPage(
          sessaoInicial: sessao(catalogoId: 'cat-a'),
          carregarCatalogo: () async =>
              throw StateError('catálogo indisponível'),
          onSalvar: (_) async {},
        ),
      ),
    );
    await animar(tester);
    expect(
      find.textContaining('Não foi possível carregar as demonstrações'),
      findsOneWidget,
    );
    expect(find.text('Concluir série'), findsWidgets);
  });

  testWidgets('informa falha ao salvar vínculo e não altera a sessão', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ExecucaoTreinoPage(
          sessaoInicial: sessao(),
          carregarCatalogo: () async => [outroExercicio],
          onSalvar: (_) async => throw StateError('erro simulado'),
        ),
      ),
    );
    await tester.tap(find.text('Escolher demonstração'));
    await animar(tester);
    await tester.tap(find.text('Exercício sem foto').last);
    await animar(tester);
    await tester.tap(find.text('Usar demonstração'));
    await animar(tester);
    expect(
      find.textContaining('Não foi possível salvar a demonstração'),
      findsOneWidget,
    );
    expect(find.textContaining('ainda não está vinculado'), findsOneWidget);
  });
}
