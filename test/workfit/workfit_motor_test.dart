import 'package:test/test.dart';
import 'package:workholy_mobile/workfit/workfit_perfil.dart';
import 'package:workholy_mobile/workfit/workfit_motor.dart';

List<ExercicioBanco> _criarExerciciosMock() {
  final exemplos = [
    // Peito
    ExercicioBanco(
      id: '1',
      nome: 'Supino com Barra',
      grupo: 'Peito',
      equipamento: 'body only',
    ),
    ExercicioBanco(id: '2', nome: 'Supino Inclinado', grupo: 'Peito'),
    ExercicioBanco(id: '3', nome: 'Crucifixo', grupo: 'Peito'),
    ExercicioBanco(id: '4', nome: 'Supino na Máquina', grupo: 'Peito'),
    ExercicioBanco(id: '5', nome: 'Flexão de Peitoral', grupo: 'Peito'),
    // Costas
    ExercicioBanco(id: '6', nome: 'Puxada Frontal', grupo: 'Costas'),
    ExercicioBanco(id: '7', nome: 'Remada Curvada', grupo: 'Costas'),
    ExercicioBanco(id: '8', nome: 'Puxada Costas', grupo: 'Back'),
    ExercicioBanco(id: '9', nome: 'Remada Máquina', grupo: 'Dorso'),
    // Ombros
    ExercicioBanco(
      id: '10',
      nome: 'Desenvolvimento com Halteres',
      grupo: 'Ombro',
    ),
    ExercicioBanco(id: '11', nome: 'Elevação Lateral', grupo: 'Shoulder'),
    ExercicioBanco(
      id: '12',
      nome: 'Encolhimento de Ombros',
      grupo: 'Deltoides',
    ),
    // Pernas
    ExercicioBanco(id: '13', nome: 'Agachamento com Barra', grupo: 'Perna'),
    ExercicioBanco(id: '14', nome: 'Leg Press', grupo: 'Leg'),
    ExercicioBanco(id: '15', nome: 'Flexão de Pernas', grupo: 'Quadriceps'),
    ExercicioBanco(id: '16', nome: 'Extensão de Pernas', grupo: 'Gluteo'),
    ExercicioBanco(id: '17', nome: 'Agachamento Completo', grupo: 'Pernas'),
    // Braços
    ExercicioBanco(id: '18', nome: 'Rosca Direta', grupo: 'Biceps'),
    ExercicioBanco(id: '19', nome: 'Rosca Alternada', grupo: 'Bíceps'),
    ExercicioBanco(id: '20', nome: 'Extensão de Tríceps', grupo: 'Triceps'),
    ExercicioBanco(id: '21', nome: 'Mergulho', grupo: 'Tríceps'),
    ExercicioBanco(id: '22', nome: 'Rosca Martelo', grupo: 'Braço'),
    // Cardio
    ExercicioBanco(
      id: 'Trail_Running_Walking',
      nome: 'Corrida',
      grupo: 'Cardio',
    ),
    ExercicioBanco(id: '24', nome: 'Burpee', grupo: 'Cardio'),
    ExercicioBanco(id: '25', nome: 'Jump Rope', grupo: 'Jumping'),
    ExercicioBanco(id: '26', nome: 'Pular Corda', grupo: 'HIIT'),
    // CrossFit
    ExercicioBanco(id: '27', nome: 'Clean and Jerk', grupo: 'Clean'),
    ExercicioBanco(id: '28', nome: 'Snatch', grupo: 'Snatch'),
    ExercicioBanco(id: '29', nome: 'Thruster', grupo: 'Thruster'),
    ExercicioBanco(id: '30', nome: 'Kettlebell Swing', grupo: 'Kettlebell'),
    // Levantamento
    ExercicioBanco(id: '31', nome: 'Deadlift', grupo: 'Deadlift'),
    ExercicioBanco(id: '32', nome: 'Front Squat', grupo: 'Front Squat'),
    ExercicioBanco(id: '33', nome: 'Bench Press', grupo: 'Bench Press'),
  ];
  return exemplos
      .map(
        (ex) => ExercicioBanco(
          id: ex.id,
          nome: ex.nome,
          grupo: ex.grupo,
          nivel: 'beginner',
          equipamento: ex.equipamento.isEmpty ? 'body only' : ex.equipamento,
        ),
      )
      .toList();
}

void main() {
  group('WorkFitMotor - Geração de Treinos com Exercícios Reais', () {
    late List<ExercicioBanco> exercicios;

    setUp(() {
      exercicios = _criarExerciciosMock();
    });

    test('Gera sugestões para musculação hipertrofia 4x/semana com exercícios reais', () {
      final perfil = WorkFitPerfil(
        tipoTreino: 'musculacao',
        minutosPorDia: 60,
        diasPorSemana: 4,
        objetivo: 'hipertrofia',
        equipamento: 'Treino na Academia',
      );

      final sugestoes = WorkFitMotor.gerarSugestoes(perfil, exercicios);

      expect(sugestoes, isNotEmpty);
      expect(sugestoes.length, greaterThanOrEqualTo(3));
      expect(sugestoes.any((s) => s.nomeTreino.contains('Peito')), true);
      expect(sugestoes.any((s) => s.nomeTreino.contains('Costas')), true);
      expect(sugestoes.any((s) => s.nomeTreino.contains('Pernas')), true);

      // Verifica que os exercícios vieram do banco
      for (final sug in sugestoes) {
        for (final ex in sug.exercicios) {
          expect(
            exercicios.any((e) => e.nome == ex.nomeExercicio),
            true,
            reason: '${ex.nomeExercicio} deveria estar no banco de dados',
          );
        }
      }
    });

    test('Adapta para treino em casa sem academia', () {
      final perfil = WorkFitPerfil(
        tipoTreino: 'musculacao',
        minutosPorDia: 30,
        diasPorSemana: 3,
        objetivo: 'emagrecimento',
        equipamento: 'Treino em casa com alguns aparelhos',
      );

      final sugestoes = WorkFitMotor.gerarSugestoes(perfil, exercicios);

      expect(sugestoes, isNotEmpty);
      final temPeito = sugestoes.any((s) => s.nomeTreino.contains('Peito'));
      expect(temPeito, true);
    });

    test(
      'musculação de três dias distribui grupos e reutiliza se necessário',
      () {
        final grupos = [
          'Peito',
          'Costas',
          'Pernas',
          'Ombros',
          'Braços',
          'Abdômen',
        ];
        final catalogo = [
          for (final grupo in grupos)
            ExercicioBanco(
              id: grupo,
              nome: grupo,
              grupo: grupo,
              equipamento: 'body only',
              nivel: 'beginner',
            ),
        ];
        final perfil = WorkFitPerfil(
          tipoTreino: 'musculacao',
          minutosPorDia: 60,
          diasPorSemana: 3,
          objetivo: 'hipertrofia',
          equipamento: 'Treino em casa',
          equipamentosDisponiveis: [],
        );
        final sugestoes = WorkFitMotor.gerarSugestoes(perfil, catalogo);
        expect(sugestoes, hasLength(3));
        for (final sugestao in sugestoes) {
          expect(
            sugestao.exercicios.map((ex) => ex.grupo).toSet(),
            grupos.toSet(),
          );
          expect(sugestao.tempoEstimadoMinutos, lessThanOrEqualTo(60));
          expect(sugestao.descricao, isNot(contains('Atenção:')));
        }
      },
    );

    test('avisa quando catálogo insuficiente não cobre grupos musculares', () {
      final perfil = WorkFitPerfil(
        tipoTreino: 'musculacao',
        minutosPorDia: 10,
        diasPorSemana: 3,
        objetivo: 'hipertrofia',
        equipamento: 'Treino em casa',
        equipamentosDisponiveis: [],
      );
      final sugestoes = WorkFitMotor.gerarSugestoes(perfil, [
        const ExercicioBanco(
          id: 'peito',
          nome: 'Flexão',
          grupo: 'Peito',
          equipamento: 'body only',
          nivel: 'beginner',
        ),
      ]);
      expect(sugestoes, hasLength(3));
      expect(sugestoes.first.descricao, contains('Costas'));
      expect(sugestoes.first.descricao, contains('Pernas'));
      expect(sugestoes.first.descricao, contains('Revise com um profissional'));
    });

    test('ajusta repetições e descanso ao objetivo sem definir carga', () {
      for (final objetivo in {
        'forca': (6, 120),
        'hipertrofia': (8, 60),
        'resistencia': (15, 60),
        'condicionamento': (12, 60),
      }.entries) {
        final perfil = WorkFitPerfil(
          tipoTreino: 'musculacao',
          minutosPorDia: 30,
          diasPorSemana: 1,
          objetivo: objetivo.key,
          equipamento: 'Treino em casa',
          equipamentosDisponiveis: [],
        );
        final sugestoes = WorkFitMotor.gerarSugestoes(perfil, [
          const ExercicioBanco(
            id: 'exercicio',
            nome: 'Exercício',
            grupo: 'Peito',
            equipamento: 'body only',
            nivel: 'beginner',
          ),
        ]);
        final item = sugestoes.single.exercicios.single;
        expect(item.repeticoes, objetivo.value.$1);
        expect(item.descansoSegundos, objetivo.value.$2);
        expect(item.cargaKgPadrao, 0);
        expect(sugestoes.single.tempoEstimadoMinutos, lessThanOrEqualTo(30));
      }
    });

    test('Gera sugestões para CrossFit com exercícios reais', () {
      final perfil = WorkFitPerfil(
        tipoTreino: 'crossfit',
        minutosPorDia: 60,
        diasPorSemana: 5,
        objetivo: 'hipertrofia',
        equipamento: 'Treino em Estúdio de CrossFit',
      );

      final sugestoes = WorkFitMotor.gerarSugestoes(perfil, exercicios);

      expect(sugestoes, isNotEmpty);
      expect(sugestoes.first.nomeTreino, contains('CrossFit'));
    });

    test('Gera sugestões para corrida de rua', () {
      final perfil = WorkFitPerfil(
        tipoTreino: 'corrida',
        minutosPorDia: 45,
        diasPorSemana: 3,
        objetivo: 'emagrecimento',
        equipamento: 'Corro na rua',
      );

      final sugestoes = WorkFitMotor.gerarSugestoes(perfil, exercicios);

      expect(sugestoes, isNotEmpty);
      expect(sugestoes.first.nomeTreino, contains('Corrida'));
    });

    test('Nomes de treinos são descritivos, não genéricos', () {
      final perfil = WorkFitPerfil(
        tipoTreino: 'musculacao',
        minutosPorDia: 60,
        diasPorSemana: 4,
        objetivo: 'hipertrofia',
        equipamento: 'Treino na Academia',
      );

      final sugestoes = WorkFitMotor.gerarSugestoes(perfil, exercicios);

      for (final sugestao in sugestoes) {
        expect(sugestao.nomeTreino, isNotEmpty);
        expect(sugestao.nomeTreino, isNot(RegExp(r'^[A-Z]$')));
        expect(sugestao.nomeTreino, isNot('Treino A'));
        expect(sugestao.nomeTreino, isNot('Treino B'));
      }
    });

    test('Exercícios têm séries e repetições coerentes', () {
      final perfil = WorkFitPerfil(
        tipoTreino: 'musculacao',
        minutosPorDia: 60,
        diasPorSemana: 4,
        objetivo: 'hipertrofia',
        equipamento: 'Treino na Academia',
      );

      final sugestoes = WorkFitMotor.gerarSugestoes(perfil, exercicios);

      for (final sugestao in sugestoes) {
        for (final ex in sugestao.exercicios) {
          expect(ex.series, greaterThan(0));
          expect(ex.repeticoes, greaterThan(0));
          expect(ex.descansoSegundos, greaterThanOrEqualTo(0));
          expect(ex.nomeExercicio, isNotEmpty);
        }
      }
    });
  });

  group('WorkFitPerfil - Serialização', () {
    test('Serializa e desserializa JSON corretamente', () {
      final original = WorkFitPerfil(
        tipoTreino: 'musculacao',
        minutosPorDia: 60,
        diasPorSemana: 4,
        objetivo: 'hipertrofia',
        equipamento: 'Treino na Academia',
      );

      final json = original.toJson();
      final desserializado = WorkFitPerfil.fromJson(json);

      expect(desserializado.tipoTreino, equals(original.tipoTreino));
      expect(desserializado.minutosPorDia, equals(original.minutosPorDia));
      expect(desserializado.diasPorSemana, equals(original.diasPorSemana));
      expect(desserializado.objetivo, equals(original.objetivo));
      expect(desserializado.equipamento, equals(original.equipamento));
    });
  });
}
