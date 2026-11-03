/// Exemplo de Uso Completo - WorkFit Personal com 1786 Exercícios
/// 
/// Este arquivo demonstra como usar WorkFit com exercícios reais do banco de dados.
library;

// ignore_for_file: avoid_print

import 'package:workholy_mobile/workfit/workfit_perfil.dart';
import 'package:workholy_mobile/workfit/workfit_motor.dart';
import 'package:workholy_mobile/workfit/workfit_adapter.dart';

List<ExercicioBanco> _gerarExerciciosMock(int quantidade) {
  final grupos = [
    'Peito', 'Costas', 'Perna', 'Ombro', 'Biceps', 
    'Triceps', 'Cardio', 'Gluteo', 'Quadriceps'
  ];
  
  final exercicios = <ExercicioBanco>[];
  for (int i = 0; i < quantidade; i++) {
    final grupo = grupos[i % grupos.length];
    exercicios.add(
      ExercicioBanco(
        id: 'mock_$i',
        nome: 'Exercício Mock $i - $grupo',
        grupo: grupo,
        seriesPadrao: 3,
        repeticoesPadrao: 12,
      ),
    );
  }
  return exercicios;
}

void exemploPrimeiroAcesso() {
  // 1. Usuário responde as 6 perguntas no onboarding
  final perfilDoUsuario = WorkFitPerfil(
    tipoTreino: 'musculacao',
    minutosPorDia: 60,
    diasPorSemana: 4,
    objetivo: 'hipertrofia',
    equipamento: 'Treino na Academia',
  );

  print('👤 Perfil Criado:');
  print('  Tipo: ${perfilDoUsuario.tipoTreino}');
  print('  Tempo: ${perfilDoUsuario.minutosPorDia}min/dia');
  print('  Frequência: ${perfilDoUsuario.diasPorSemana}x/semana');
  print('  Objetivo: ${perfilDoUsuario.objetivo}');
  print('  Equipamento: ${perfilDoUsuario.equipamento}');
  print('');

  // 2. Simular 1786 exercícios do banco de dados
  final exerciciosBanco = _gerarExerciciosMock(1786);
  print('📚 Carregados ${exerciciosBanco.length} exercícios do banco de dados');

  // 3. Motor gera sugestões usando exercícios REAIS do banco
  final sugestoes = WorkFitMotor.gerarSugestoes(perfilDoUsuario, exerciciosBanco);

  print('🤖 Motor Gerou ${sugestoes.length} Sugestões com exercícios reais:');
  for (int i = 0; i < sugestoes.length; i++) {
    final sug = sugestoes[i];
    print('\n  ${i + 1}. ${sug.nomeTreino}');
    print('     ${sug.descricao}');
    print('     ${sug.exercicios.length} exercícios • ~${sug.tempoEstimadoMinutos}min');
    
    for (final ex in sug.exercicios) {
      print('       • ${ex.nomeExercicio}: ${ex.series}x${ex.repeticoes} @ ${ex.cargaKgPadrao}kg');
    }
  }
  print('');

  // 4. Converter para modelos do app
  final dados = WorkFitAdapter.converterSugestoes(sugestoes);

  print('💾 Convertidos para modelos do app:');
  print('  • ${dados['treinos']!.length} Treinos');
  print('  • ${dados['exercicios']!.length} Exercícios únicos');
  print('  • ${dados['itensTreino']!.length} Itens treino');
  print('');

  print('✅ Pronto para salvar em SQLite!');
}

void exemploRecuperarPerfil() {
  print('Exemplo de recuperação de perfil...');
  
  const jsonRecuperado = {
    'tipoTreino': 'crossfit',
    'minutosPorDia': 60,
    'diasPorSemana': 5,
    'objetivo': 'amador',
    'equipamento': 'Treino em Estúdio de CrossFit',
  };

  final perfil = WorkFitPerfil.fromJson(jsonRecuperado as Map<String, dynamic>);
  print('✅ Perfil recuperado: ${perfil.tipoTreino}');
}
