import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workholy_mobile/dados/workholy_banco.dart';
import 'package:workholy_mobile/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('vínculo da demonstração permanece após reabrir o banco', () async {
    SharedPreferences.setMockInitialValues({});
    final diretorio = await Directory.systemTemp.createTemp('workholy_demo_');
    final caminho = p.join(diretorio.path, 'dados.db');
    final banco = WorkHolyBanco.paraTestes(caminho: caminho);
    var bancoFechado = false;
    final sessao = SessaoTreino(
      id: 'sessao',
      treinoId: 'treino',
      nomeTreino: 'Meu treino',
      inicio: DateTime(2026, 1, 1),
      fim: null,
      series: const [
        SerieExecutada(
          id: 'serie',
          exercicioId: 'exercicio',
          nomeExercicio: 'Exercício',
          numeroSerie: 1,
          repeticoesPlanejadas: 10,
          repeticoesRealizadas: 10,
          cargaKg: 0,
          concluida: false,
          descansoSegundos: 30,
          catalogoId: '3_4_Sit-Up',
        ),
      ],
    );
    try {
      await banco.salvarDadosTreino(
        treinos: const [],
        exercicios: const [],
        itensTreino: const [],
        sessoesTreino: [sessao.toJson()],
      );
      await (await banco.database).close();
      bancoFechado = true;
      final reaberto = WorkHolyBanco.paraTestes(caminho: caminho);
      try {
        final dados = await reaberto.carregarDadosTreino();
        final recuperada = SessaoTreino.fromJson(dados.sessoesTreino.single);
        expect(recuperada.series.single.catalogoId, '3_4_Sit-Up');
      } finally {
        await (await reaberto.database).close();
      }
    } finally {
      if (!bancoFechado) await (await banco.database).close();
      await diretorio.delete(recursive: true);
    }
  });
}
