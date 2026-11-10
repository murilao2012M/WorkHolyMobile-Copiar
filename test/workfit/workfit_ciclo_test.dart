import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workholy_mobile/dados/workholy_banco.dart';
import 'package:workholy_mobile/main.dart';
import 'package:workholy_mobile/workfit/workfit_adapter.dart';
import 'package:workholy_mobile/workfit/workfit_ciclo.dart';
import 'package:workholy_mobile/workfit/workfit_motor.dart';
import 'package:workholy_mobile/workfit/workfit_perfil.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final ciclo = WorkFitCiclo(
    id: 'plano-a',
    inicio: DateTime(2026, 1, 1, 18),
    diasPorSemana: 3,
    modalidade: 'musculacao',
  );

  test('ciclo tem quatro semanas e não reinicia sozinho', () {
    for (final caso in [(0, 1), (7, 2), (14, 3), (21, 4), (27, 4)]) {
      final estado = avaliarCicloWorkFit(
        ciclo,
        DateTime(2026, 1, 1 + caso.$1),
        [],
      );
      expect(estado.semana, caso.$2);
      expect(estado.encerrado, isFalse);
    }
    final encerrado = avaliarCicloWorkFit(ciclo, DateTime(2026, 1, 29), []);
    expect(encerrado.encerrado, isTrue);
    expect(encerrado.semana, 4);
    expect(encerrado.semanaConcluida, 4);
    final futuro = avaliarCicloWorkFit(ciclo, DateTime(2025, 12, 31), []);
    expect(futuro.naoIniciado, isTrue);
  });

  test('aderência conta dias distintos do plano e exclui datas futuras', () {
    final sessoes = [
      DiaConcluidoWorkFit(planoId: 'plano-a', data: DateTime(2026, 1, 1)),
      DiaConcluidoWorkFit(planoId: 'plano-a', data: DateTime(2026, 1, 1, 23)),
      DiaConcluidoWorkFit(planoId: 'plano-a', data: DateTime(2026, 1, 3)),
      DiaConcluidoWorkFit(planoId: 'outro', data: DateTime(2026, 1, 4)),
      DiaConcluidoWorkFit(planoId: 'plano-a', data: DateTime(2026, 1, 9)),
      DiaConcluidoWorkFit(planoId: 'plano-a', data: DateTime(2026, 1, 10)),
    ];
    final semana1 = avaliarCicloWorkFit(ciclo, DateTime(2026, 1, 5), sessoes);
    expect(semana1.diasConcluidos, 2);
    expect(semana1.semanaConcluida, isNull);
    final semana2 = avaliarCicloWorkFit(ciclo, DateTime(2026, 1, 9), sessoes);
    expect(semana2.diasConcluidos, 1);
    expect(semana2.semanaConcluida, 1);
    expect(semana2.diasSemanaConcluida, 2);
  });

  test('dados de esforço e ciclos são compatíveis com registros antigos', () {
    final antigo = SessaoTreino.fromJson({
      'id': 'antiga',
      'treinoId': 't',
      'nomeTreino': 'Treino',
      'inicio': '2026-01-01T10:00:00',
      'series': [],
    });
    expect(antigo.rpe, isNull);
    expect(antigo.rir, isNull);
    final comEsforco = antigo.copiar(rpe: 8, rir: 2);
    final recuperado = SessaoTreino.fromJson(comEsforco.toJson());
    expect(recuperado.rpe, 8);
    expect(recuperado.rir, 2);
    expect(
      () => SessaoTreino.fromJson({...comEsforco.toJson(), 'rpe': 11}),
      throwsFormatException,
    );
    expect(Treino.fromJson({'id': 't'}).workfitCiclo, isNull);
  });

  test(
    'plano, esforço e marcador de recuperação persistem no SQLite',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      SharedPreferences.setMockInitialValues({});
      final diretorio = await Directory.systemTemp.createTemp('workfit_ciclo_');
      final banco = WorkHolyBanco.paraTestes(
        caminho: p.join(diretorio.path, 'dados.db'),
      );
      addTearDown(() async {
        await (await banco.database).close();
        await diretorio.delete(recursive: true);
      });
      final perfil = WorkFitPerfil(
        tipoTreino: 'musculacao',
        minutosPorDia: 30,
        diasPorSemana: 3,
        objetivo: 'hipertrofia',
        equipamento: 'casa',
        equipamentosDisponiveis: [],
      );
      final sugestoes = WorkFitMotor.gerarSugestoes(perfil, [
        const ExercicioBanco(
          id: 'ex',
          nome: 'Flexão',
          grupo: 'Peito',
          equipamento: 'body only',
          nivel: 'beginner',
        ),
      ]);
      final dados = WorkFitAdapter.converterSugestoes(sugestoes);
      final treinos = dados['treinos']!.map(Treino.fromJson).toList();
      expect(treinos, hasLength(3));
      final plano = treinos.first.workfitCiclo!;
      expect(treinos.every((t) => t.workfitCiclo?.id == plano.id), isTrue);
      expect(plano.diasPorSemana, 3);
      final itemOriginal = ItemTreino.fromJson(dados['itensTreino']!.first);
      final item = ItemTreino(
        id: itemOriginal.id,
        treinoId: itemOriginal.treinoId,
        exercicioId: itemOriginal.exercicioId,
        series: itemOriginal.series,
        repeticoes: itemOriginal.repeticoes,
        cargaKg: itemOriginal.cargaKg,
        descansoSegundos: itemOriginal.descansoSegundos,
        workfitUltimaSessaoAjustada: 'sessao',
        workfitCicloRecuperado: plano.id,
      );
      final sessao = SessaoTreino(
        id: 'sessao',
        treinoId: item.treinoId,
        nomeTreino: 'Treino',
        inicio: DateTime(2026, 1, 1),
        fim: DateTime(2026, 1, 1, 1),
        series: [],
        workfitPlanoId: plano.id,
        rpe: 8,
        rir: 2,
      );
      await banco.salvarDadosTreino(
        treinos: treinos.map((t) => t.toJson()).toList(),
        exercicios: dados['exercicios']!,
        itensTreino: [item.toJson()],
        sessoesTreino: [sessao.toJson()],
      );
      final salvo = await banco.carregarDadosTreino();
      expect(Treino.fromJson(salvo.treinos.first).workfitCiclo!.id, plano.id);
      expect(
        ItemTreino.fromJson(salvo.itensTreino.single).workfitCicloRecuperado,
        plano.id,
      );
      final sessaoSalva = SessaoTreino.fromJson(salvo.sessoesTreino.single);
      expect(sessaoSalva.workfitPlanoId, plano.id);
      expect(sessaoSalva.rpe, 8);
      expect(sessaoSalva.rir, 2);
    },
  );
}
