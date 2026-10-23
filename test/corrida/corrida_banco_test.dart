import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:workholy_mobile/corrida/corrida_banco.dart';

void main() {
  late Directory diretorioTemporario;
  late CorridaBanco banco;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    diretorioTemporario =
        await Directory.systemTemp.createTemp('workholy_corrida_test_');

    banco = CorridaBanco.paraTestes(
      caminhoBanco: p.join(diretorioTemporario.path, 'teste.db'),
    );
  });

  tearDown(() async {
    await banco.fechar();

    if (await diretorioTemporario.exists()) {
      await diretorioTemporario.delete(recursive: true);
    }
  });

  test('cria e consulta uma corrida', () async {
    final inicioMs = DateTime.now().millisecondsSinceEpoch;

    await banco.criar('corrida-1', inicioMs);

    final registro = await banco.buscar('corrida-1');

    expect(registro, isNotNull);
    expect(registro!['id'], 'corrida-1');
    expect(registro['inicio_ms'], inicioMs);
    expect(registro['estado'], 'em_andamento');
    expect(registro['fim_ms'], isNull);
  });

  test('atualiza duração, distância, estado e rota', () async {
    await banco.criar('corrida-2', 1000);

    final rota = <Map<String, double>>[
      {'lat': -23.18, 'lon': -45.88},
      {'lat': -23.19, 'lon': -45.89},
    ];

    await banco.atualizar(
      id: 'corrida-2',
      duracaoSegundos: 120,
      distanciaMetros: 850.5,
      estado: 'pausada',
      rota: rota,
    );

    final registro = (await banco.buscar('corrida-2'))!;

    expect(registro['duracao_segundos'], 120);
    expect((registro['distancia_metros'] as num).toDouble(), 850.5);
    expect(registro['estado'], 'pausada');

    final rotaSalva = banco.decodificarRota(registro['rota_json']);

    expect(rotaSalva, hasLength(2));
    expect(rotaSalva.first['lat'], -23.18);
    expect(rotaSalva.first['lon'], -45.88);
  });

  test('finalização registra fim_ms', () async {
    await banco.criar('corrida-3', 1000);

    const fimMs = 5000;

    await banco.atualizar(
      id: 'corrida-3',
      duracaoSegundos: 4,
      distanciaMetros: 25,
      estado: 'finalizada',
      rota: const [],
      fimMs: fimMs,
    );

    final registro = (await banco.buscar('corrida-3'))!;

    expect(registro['estado'], 'finalizada');
    expect(registro['fim_ms'], fimMs);
  });

  test('atualização sem fimMs preserva a data de finalização', () async {
    await banco.criar('corrida-4', 1000);

    await banco.atualizar(
      id: 'corrida-4',
      duracaoSegundos: 60,
      distanciaMetros: 500,
      estado: 'finalizada',
      rota: const [],
      fimMs: 9000,
    );

    await banco.atualizar(
      id: 'corrida-4',
      duracaoSegundos: 61,
      distanciaMetros: 510,
      estado: 'finalizada',
      rota: const [],
    );

    final registro = (await banco.buscar('corrida-4'))!;

    expect(registro['fim_ms'], 9000);
    expect(registro['duracao_segundos'], 61);
    expect((registro['distancia_metros'] as num).toDouble(), 510);
  });

  test('lista somente corridas finalizadas no histórico concluído', () async {
    await banco.criar('corrida-aberta', 1000);
    await banco.criar('corrida-finalizada', 2000);

    await banco.atualizar(
      id: 'corrida-finalizada',
      duracaoSegundos: 180,
      distanciaMetros: 1000,
      estado: 'finalizada',
      rota: const [],
      fimMs: 3000,
    );

    final finalizadas = await banco.listarFinalizadas();

    expect(finalizadas, hasLength(1));
    expect(finalizadas.single.id, 'corrida-finalizada');
    expect(finalizadas.single.fim.millisecondsSinceEpoch, 3000);
  });
}
