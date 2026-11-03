import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/exercicios/biblioteca_exercicios.dart';
import 'package:workholy_mobile/workfit/workfit_motor.dart';
import 'package:workholy_mobile/workfit/workfit_perfil.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'três dias com catálogo real distribuem os grupos no tempo informado',
    () async {
      final catalogo = await CatalogoExercicios.instancia.carregar();
      final exercicios = catalogo.map(ExercicioBanco.doCatalogo).toList();
      for (final minutos in [10, 30, 60]) {
        final perfil = WorkFitPerfil(
          tipoTreino: 'musculacao',
          minutosPorDia: minutos,
          diasPorSemana: 3,
          objetivo: 'hipertrofia',
          equipamento: 'Treino em casa',
          equipamentosDisponiveis: const [],
        );
        final sugestoes = WorkFitMotor.gerarSugestoes(perfil, exercicios);
        expect(sugestoes, hasLength(3), reason: '$minutos minutos');
        expect(
          sugestoes.every((s) => s.tempoEstimadoMinutos <= minutos),
          isTrue,
        );
        for (final grupo in [
          'Peito',
          'Costas',
          'Pernas',
          'Ombros',
          'Braços',
          'Abdômen',
        ]) {
          expect(
            sugestoes.any((s) => s.nomeTreino.contains(grupo)) ||
                sugestoes.every(
                  (s) =>
                      s.descricao.contains('Atenção:') &&
                      s.descricao.contains(grupo),
                ),
            isTrue,
            reason:
                '$grupo deve aparecer no plano ou no aviso, $minutos minutos',
          );
        }
      }
    },
  );

  test('gera planos com o catálogo real para as quatro modalidades', () async {
    final catalogo = await CatalogoExercicios.instancia.carregar();
    final exercicios = catalogo.map(ExercicioBanco.doCatalogo).toList();

    for (final modalidade in [
      'musculacao',
      'crossfit',
      'corrida',
      'personal',
    ]) {
      for (final local in [
        'Treino na Academia',
        'Treino em casa com alguns aparelhos',
        'Corro na rua',
        'Treino em condomínio',
        'Treino com Personal na Academia',
        'Treino em Estúdio de CrossFit',
      ]) {
        for (final dias in [2, 3, 4, 5, 6, 7]) {
          for (final minutos in [10, 30, 60]) {
            final perfil = WorkFitPerfil(
              tipoTreino: modalidade,
              minutosPorDia: minutos,
              diasPorSemana: dias,
              objetivo: 'hipertrofia',
              equipamento: local,
              equipamentosDisponiveis: const [],
            );
            final sugestoes = WorkFitMotor.gerarSugestoes(perfil, exercicios);
            final contexto = '$modalidade, $local, $dias dias, $minutos min';
            expect(sugestoes, isNotEmpty, reason: contexto);
            for (final sugestao in sugestoes) {
              expect(sugestao.exercicios, isNotEmpty, reason: contexto);
              expect(sugestao.tempoEstimadoMinutos, lessThanOrEqualTo(minutos));
              for (final item in sugestao.exercicios) {
                final original = exercicios.singleWhere(
                  (ex) => ex.id == item.exercicioId,
                );
                expect(original.nome, item.nomeExercicio);
                expect(item.cargaKgPadrao, 0);
                if (modalidade != 'corrida') {
                  expect(
                    original.equipamento,
                    anyOf('body only', 'body weight'),
                    reason: contexto,
                  );
                  expect(original.nivel, 'beginner', reason: contexto);
                }
              }
            }
          }
        }
      }
    }
  });
}
