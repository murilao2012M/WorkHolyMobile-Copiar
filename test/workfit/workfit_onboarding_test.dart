import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/workfit/workfit_motor.dart';
import 'package:workholy_mobile/workfit/workfit_onboarding_page.dart';
import 'package:workholy_mobile/workfit/workfit_perfil.dart';

void main() {
  testWidgets('objetivo força e disponibilidade de um dia chegam ao motor', (
    tester,
  ) async {
    List<WorkFitSugestao>? resultado;
    await tester.pumpWidget(
      MaterialApp(
        home: WorkFitOnboardingPage(
          exercicios: const [
            ExercicioBanco(
              id: 'peito',
              nome: 'Flexão',
              grupo: 'Peito',
              equipamento: 'body only',
              nivel: 'beginner',
            ),
          ],
          onConfirm: (sugestoes) => resultado = sugestoes,
          onSkip: () {},
        ),
      ),
    );
    Future<void> tocar(String texto) async {
      await tester.ensureVisible(find.text(texto).first);
      await tester.tap(find.text(texto).first);
      await tester.pumpAndSettle();
    }

    await tocar('Musculação');
    await tocar('Próximo');
    await tocar('20 min');
    await tocar('Próximo');
    await tocar('1 x');
    await tocar('Próximo');
    await tocar('Força');
    await tocar('Próximo');
    await tocar('Treino na Academia');
    await tocar('Próximo');
    await tocar('Iniciante');
    await tocar('Próximo');
    await tocar('Gerar Treinos');
    await tocar('Confirmar e Começar');
    expect(resultado!.single.exercicios.single.repeticoes, 6);
    expect(resultado!.single.exercicios.single.descansoSegundos, 120);
  });

  for (final entrada in {
    'Musculação': 'Peito',
    'CrossFit': 'CrossFit',
    'Corrida de Rua': 'Corrida',
    'Personal Trainer': 'Personal Trainer',
  }.entries) {
    testWidgets('onboarding seleciona ${entrada.key}', (tester) async {
      List<WorkFitSugestao>? resultado;
      await tester.pumpWidget(
        MaterialApp(
          home: WorkFitOnboardingPage(
            exercicios: [
              ExercicioBanco(
                id: 'chest',
                nome: 'Supino',
                grupo: 'Peito',
                equipamento: 'body only',
                nivel: 'beginner',
              ),
              ExercicioBanco(
                id: 'Clean',
                nome: 'Clean',
                grupo: 'Pernas',
                equipamento: 'body only',
                nivel: 'beginner',
              ),
              ExercicioBanco(
                id: 'Trail_Running_Walking',
                nome: 'Corrida em trilha',
                grupo: 'Cardio',
              ),
            ],
            onConfirm: (sugestoes) => resultado = sugestoes,
            onSkip: () {},
          ),
        ),
      );

      Future<void> tocar(String texto) async {
        await tester.ensureVisible(find.text(texto).first);
        await tester.tap(find.text(texto).first);
        await tester.pumpAndSettle();
      }

      await tocar(entrada.key);
      await tocar('Próximo');
      await tocar('30 min');
      await tocar('Próximo');
      await tocar('2 x');
      await tocar('Próximo');
      await tocar('Hipertrofia');
      await tocar('Próximo');
      await tocar('Treino na Academia');
      await tocar('Próximo');
      await tocar('Iniciante');
      await tocar('Próximo');
      await tocar('Gerar Treinos');
      expect(find.textContaining(entrada.value), findsWidgets);
      await tocar('Confirmar e Começar');
      expect(resultado, isNotNull);
      expect(resultado!.first.nomeTreino, contains(entrada.value));
    });
  }
}
