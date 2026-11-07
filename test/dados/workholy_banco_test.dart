import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workholy_mobile/dados/workholy_banco.dart';

void main() {
  late Directory diretorioTemporario;
  late WorkHolyBanco banco;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    diretorioTemporario = await Directory.systemTemp.createTemp(
      'workholy_banco_test_',
    );
    banco = WorkHolyBanco.paraTestes(
      caminho: p.join(diretorioTemporario.path, 'treino.db'),
    );
  });

  tearDown(() async {
    await banco.fechar();
    if (await diretorioTemporario.exists()) {
      await diretorioTemporario.delete(recursive: true);
    }
  });

  test('falha ao salvar sem apagar os dados já persistidos', () async {
    await banco.salvarDadosTreino(
      treinos: [
        {'id': 'treino-existente', 'nome': 'Treino A', 'objetivo': 'Força'},
      ],
      exercicios: const [],
      itensTreino: const [],
      sessoesTreino: const [],
    );

    await expectLater(
      banco.salvarDadosTreino(
        treinos: [
          {'nome': 'Treino inválido', 'objetivo': ''},
        ],
        exercicios: const [],
        itensTreino: const [],
        sessoesTreino: const [],
      ),
      throwsFormatException,
    );

    final dados = await banco.carregarDadosTreino();
    expect(dados.treinos.single['id'], 'treino-existente');
  });
}
