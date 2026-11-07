import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/exercicios/biblioteca_exercicios.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('converte os campos do Free Exercise DB', () {
    final exercicio = ExercicioPredefinido.fromFreeExerciseDb(
      {
        'id': 'alternate_curl',
        'name': 'Alternate Curl',
        'force': 'pull',
        'level': 'beginner',
        'mechanic': 'isolation',
        'equipment': 'dumbbell',
        'category': 'strength',
        'primaryMuscles': ['biceps'],
        'secondaryMuscles': ['forearms'],
        'instructions': ['Keep the elbows close to the torso.'],
        'images': ['alternate_curl/0.jpg'],
      },
      traducaoExercicio: {
        'nome': 'Rosca alternada',
        'instrucoes': ['Mantenha os cotovelos próximos ao tronco.'],
      },
    );

    expect(exercicio.id, 'alternate_curl');
    expect(exercicio.nome, 'Rosca alternada');
    expect(exercicio.nomeOriginal, 'Alternate Curl');
    expect(exercicio.nomeComNomeOriginal, 'Rosca alternada (Alternate Curl)');
    expect(exercicio.grupo, 'Braços');
    expect(exercicio.musculosSecundarios, ['forearms']);
    expect(exercicio.instrucoes, ['Mantenha os cotovelos próximos ao tronco.']);
    expect(exercicio.imagens, ['alternate_curl/0.jpg']);
    expect(exercicio.caminhosImagensAssets, [
      'assets/exercicios/imagens/alternate_curl/0.jpg',
    ]);
  });

  test('carrega os 876 exercícios com traduções e IDs preservados', () async {
    final catalogo = await CatalogoExercicios.instancia.carregar();

    final catalogoOriginalJson = await rootBundle.loadString(
      CatalogoExercicios.caminhoAsset,
    );
    final traducoesJson = await rootBundle.loadString(
      CatalogoExercicios.caminhoTraducoesAsset,
    );

    final originais = (jsonDecode(catalogoOriginalJson) as List)
        .cast<Map<String, dynamic>>();
    final traducoes = jsonDecode(traducoesJson) as Map<String, dynamic>;
    final traducoesPorId = (traducoes['exercicios'] as Map)
        .cast<String, dynamic>();

    expect(originais, hasLength(876));
    expect(catalogo, hasLength(876));

    final originaisPorId = {
      for (final item in originais) item['id'].toString(): item,
    };
    final carregadosPorId = {
      for (final exercicio in catalogo) exercicio.id: exercicio,
    };

    expect(carregadosPorId.keys.toSet(), originaisPorId.keys.toSet());
    expect(
      originais.where((item) => (item['instructions'] as List).isNotEmpty),
      hasLength(871),
    );

    for (final exercicio in catalogo) {
      final original = originaisPorId[exercicio.id]!;
      final traducao = (traducoesPorId[exercicio.id] as Map)
          .cast<String, dynamic>();
      final nomeTraduzido = traducao['nome'].toString();
      final nomeOriginal = original['name'].toString();
      final nomeExibido =
          nomeTraduzido.toLowerCase() == nomeOriginal.trim().toLowerCase()
          ? nomeTraduzido
          : '$nomeTraduzido ($nomeOriginal)';

      expect(exercicio.nome, traducao['nome'], reason: exercicio.id);
      expect(exercicio.nomeOriginal, original['name'], reason: exercicio.id);
      expect(
        exercicio.nomeComNomeOriginal,
        nomeExibido,
        reason: 'Nome original do exercício ${exercicio.id}',
      );
      expect(
        exercicio.imagens,
        (original['images'] as List? ?? []).cast<String>(),
        reason: 'Imagens do exercício ${exercicio.id}',
      );

      final instrucoesTraduzidas = traducao['instrucoes'];
      expect(
        instrucoesTraduzidas,
        isA<List<dynamic>>(),
        reason: 'Instruções ausentes no exercício ${exercicio.id}',
      );
      expect(
        exercicio.instrucoes,
        isNotEmpty,
        reason: 'Instruções vazias no exercício ${exercicio.id}',
      );
      expect(
        exercicio.instrucoes,
        (instrucoesTraduzidas as List).cast<String>(),
        reason: 'Instruções do exercício ${exercicio.id}',
      );
      expect(
        exercicio.instrucoes.every((instrucao) => instrucao.trim().isNotEmpty),
        isTrue,
        reason: 'Instrução em branco no exercício ${exercicio.id}',
      );
      expect(
        traducao['status_instrucoes'],
        anyOf('traduzido_automaticamente_revisao_tecnica', 'corrigido_manual'),
        reason: 'Status ausente no exercício ${exercicio.id}',
      );
    }

    expect(
      catalogo.every((exercicio) => exercicio.nome.trim().isNotEmpty),
      isTrue,
    );
    expect(
      catalogo.every((exercicio) => exercicio.nomeComNomeOriginal.isNotEmpty),
      isTrue,
    );

    for (final id in [
      'Iron_Cross',
      'One-Arm_Kettlebell_Swings',
      'Push_Press',
      'Side_Bridge',
      'Side_Jackknife',
    ]) {
      expect(
        carregadosPorId[id]!.instrucoes,
        isNotEmpty,
        reason: 'Instruções ausentes no exercício $id',
      );
      expect(
        (traducoesPorId[id] as Map)['status_instrucoes'],
        'corrigido_manual',
      );
    }

    expect(carregadosPorId['Power_Clean']!.nome, 'Power clean');
    expect(carregadosPorId['Push_Press']!.nome, 'Desenvolvimento com impulso');
  });
}
