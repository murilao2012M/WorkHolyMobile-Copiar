
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
    expect(exercicio.grupo, 'Braços');
    expect(exercicio.musculosSecundarios, ['forearms']);
    expect(
      exercicio.instrucoes,
      ['Mantenha os cotovelos próximos ao tronco.'],
    );
    expect(exercicio.imagens, ['alternate_curl/0.jpg']);
    expect(
      exercicio.caminhosImagensAssets,
      ['assets/exercicios/imagens/alternate_curl/0.jpg'],
    );
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
    final traducoesPorId =
        (traducoes['exercicios'] as Map).cast<String, dynamic>();

    expect(originais, hasLength(876));
    expect(catalogo, hasLength(876));

    final originaisPorId = {
      for (final item in originais) item['id'].toString(): item,
    };
    final carregadosPorId = {
      for (final exercicio in catalogo) exercicio.id: exercicio,
    };

    expect(carregadosPorId.keys.toSet(), originaisPorId.keys.toSet());

    for (final exercicio in catalogo) {
      final original = originaisPorId[exercicio.id]!;
      final traducao =
          (traducoesPorId[exercicio.id] as Map).cast<String, dynamic>();

      expect(exercicio.nome, traducao['nome'], reason: exercicio.id);
      expect(
        exercicio.imagens,
        (original['images'] as List? ?? []).cast<String>(),
        reason: 'Imagens do exercício ${exercicio.id}',
      );

      final instrucoesTraduzidas = traducao['instrucoes'];
      if (instrucoesTraduzidas is List) {
        expect(
          exercicio.instrucoes,
          instrucoesTraduzidas.cast<String>(),
          reason: 'Instruções do exercício ${exercicio.id}',
        );
      }
    }

    expect(
      catalogo.every((exercicio) => exercicio.nome.trim().isNotEmpty),
      isTrue,
    );
  });
}
