import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/alunos/resumo_aluno.dart';

SessaoAluno _sessao(DateTime inicio, Map<String, double> cargas, {double vol = 100}) =>
    SessaoAluno(
      nomeTreino: 'A',
      inicio: inicio,
      fim: inicio.add(const Duration(minutes: 50)),
      seriesConcluidas: 5,
      volumeKg: vol,
      cargaMaxima: cargas,
    );

void main() {
  final agora = DateTime(2026, 11, 4, 12);

  test('sem sessões o resumo é vazio', () {
    final r = calcularResumoAluno([], agora);
    expect(r.totalSessoes, 0);
    expect(r.ultimaSessao, isNull);
    expect(r.sessoesPorSemana, [0, 0, 0, 0]);
    expect(r.evolucao, isEmpty);
  });

  test('conta sessões por semana, volume e evolução de carga', () {
    final r = calcularResumoAluno([
      _sessao(agora.subtract(const Duration(days: 1)), {'Supino': 50}),
      _sessao(agora.subtract(const Duration(days: 8)), {'Supino': 40, 'Remada': 30}),
      _sessao(agora.subtract(const Duration(days: 40)), {'Supino': 35}),
    ], agora);
    expect(r.totalSessoes, 3);
    expect(r.sessoesPorSemana, [0, 0, 1, 1]);
    expect(r.volumeTotalKg, 300);
    expect(r.ultimaSessao, agora.subtract(const Duration(days: 1)));
    expect(r.evolucao.length, 1);
    expect(r.evolucao.first.nome, 'Supino');
    expect(r.evolucao.first.cargaInicial, 35);
    expect(r.evolucao.first.cargaAtual, 50);
    expect(r.evolucao.first.diferenca, 15);
  });
}
