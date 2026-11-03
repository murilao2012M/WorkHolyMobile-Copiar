import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/workfit/workfit_adapter.dart';
import 'package:workholy_mobile/workfit/workfit_motor.dart';
import 'package:workholy_mobile/workfit/workfit_perfil.dart';

WorkFitPerfil perfil({
  String experiencia = 'iniciante',
  List<String> equipamentos = const [],
  int minutos = 10,
}) => WorkFitPerfil(
  tipoTreino: 'personal',
  minutosPorDia: minutos,
  diasPorSemana: 2,
  objetivo: 'hipertrofia',
  equipamento: 'Treino em casa',
  experiencia: experiencia,
  equipamentosDisponiveis: equipamentos,
);

ExercicioBanco exercicio(
  String id, {
  String nivel = 'beginner',
  String equipamento = 'body only',
  List<String> instrucoes = const [],
}) => ExercicioBanco(
  id: id,
  nome: id,
  grupo: 'Peito',
  nivel: nivel,
  equipamento: equipamento,
  categoria: 'strength',
  instrucoesOriginais: instrucoes,
);

void main() {
  test('instruções influenciam o ranking, não apenas o nome', () {
    final catalogo = [
      exercicio('a', instrucoes: ['Repeat the movement.']),
      exercicio('z', instrucoes: ['Lower slowly with a controlled motion.']),
    ];
    final sugestao = WorkFitMotor.gerarSugestoes(perfil(), catalogo).single;
    expect(sugestao.exercicios.single.exercicioId, 'z');
    expect(sugestao.exercicios.single.justificativa, contains('controlado'));
  });

  test(
    'exclui equipamento identificado nas instruções e nível acima do informado',
    () {
      final catalogo = [
        exercicio('a', instrucoes: ['Use a flat bench for this movement.']),
        exercicio('b', nivel: 'expert'),
        exercicio('c', nivel: ''),
        exercicio('d'),
      ];
      final selecionado = WorkFitMotor.gerarSugestoes(
        perfil(),
        catalogo,
      ).single;
      expect(selecionado.exercicios.single.exercicioId, 'd');
      final avancado = WorkFitMotor.gerarSugestoes(
        perfil(experiencia: 'avancado', equipamentos: ['banco']),
        [catalogo.first],
      );
      expect(avancado.single.exercicios.single.exercicioId, 'a');
    },
  );

  test('equipamento declarado permite o exercício e ausência não', () {
    final catalogo = [exercicio('halter', equipamento: 'dumbbell')];
    expect(WorkFitMotor.gerarSugestoes(perfil(), catalogo), isEmpty);
    expect(
      WorkFitMotor.gerarSugestoes(perfil(equipamentos: ['halteres']), catalogo),
      isNotEmpty,
    );
  });

  test('resultado é determinístico e não inventa carga', () {
    final catalogo = [exercicio('b'), exercicio('a')];
    final primeira = WorkFitMotor.gerarSugestoes(perfil(), catalogo);
    final segunda = WorkFitMotor.gerarSugestoes(
      perfil(),
      catalogo.reversed.toList(),
    );
    expect(
      primeira.single.exercicios.single.exercicioId,
      segunda.single.exercicios.single.exercicioId,
    );
    expect(primeira.single.exercicios.single.cargaKgPadrao, 0);
  });

  test(
    'exercícios com nomes iguais e IDs diferentes são salvos separadamente',
    () {
      final sugestao = WorkFitSugestao(
        nomeTreino: 'Teste',
        descricao: '',
        tempoEstimadoMinutos: 10,
        exercicios: [
          for (final id in ['primeiro', 'segundo'])
            WorkFitItemExercicio(
              exercicioId: id,
              nomeExercicio: 'Mesmo nome',
              grupo: 'Peito',
              series: 2,
              repeticoes: 8,
              cargaKgPadrao: 0,
              descansoSegundos: 60,
            ),
        ],
      );
      final dados = WorkFitAdapter.converterSugestoes([sugestao]);
      expect(dados['exercicios'], hasLength(2));
      expect(
        dados['exercicios']!
            .map((exercicio) => exercicio['catalogoId'])
            .toSet(),
        {'primeiro', 'segundo'},
      );
      expect(
        dados['itensTreino']!.map((item) => item['exercicioId']).toSet(),
        hasLength(2),
      );
    },
  );

  test('perfil conserva experiência e equipamentos na serialização', () {
    final original = perfil(
      experiencia: 'intermediario',
      equipamentos: ['halteres'],
    );
    final recuperado = WorkFitPerfil.fromJson(original.toJson());
    expect(recuperado.experiencia, 'intermediario');
    expect(recuperado.equipamentosDisponiveis, ['halteres']);
  });
}
