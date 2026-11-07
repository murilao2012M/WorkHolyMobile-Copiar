import 'dart:convert';

import '../alunos/alunos_modelos.dart';
import '../corrida/corrida_banco.dart';
import 'workholy_banco.dart';
import 'workholy_modelos.dart';

class BackupTreino {
  const BackupTreino._();

  static const String _formato = 'workholy_training_backup';
  static const int _versao = 3;

  static Future<String> exportar({
    WorkHolyBanco? bancoTreino,
    CorridaBanco? bancoCorrida,
  }) async {
    final dados = await (bancoTreino ?? WorkHolyBanco.instancia)
        .carregarDadosTreino();
    final corridas = await (bancoCorrida ?? CorridaBanco.instancia)
        .listarRegistrosFinalizados();
    final alunos = await (bancoTreino ?? WorkHolyBanco.instancia)
        .listarAlunosParaBackup();
    final anotacoes = await (bancoTreino ?? WorkHolyBanco.instancia)
        .listarAnotacoesParaBackup();
    return const JsonEncoder.withIndent('  ').convert({
      'formato': _formato,
      'versao': _versao,
      'exportadoEm': DateTime.now().toIso8601String(),
      'dados': {
        'treinos': dados.treinos,
        'exercicios': dados.exercicios,
        'itensTreino': dados.itensTreino,
        'sessoesTreino': dados.sessoesTreino,
        'corridas': corridas,
        'alunos': alunos.map((aluno) => aluno.toJson()).toList(),
        'anotacoesAlunos': anotacoes
            .map((anotacao) => anotacao.toJson())
            .toList(),
      },
    });
  }

  static Future<String> exportarCsv({
    WorkHolyBanco? bancoTreino,
    CorridaBanco? bancoCorrida,
  }) async {
    final treinos = await (bancoTreino ?? WorkHolyBanco.instancia)
        .carregarDadosTreino();
    final corridas = await (bancoCorrida ?? CorridaBanco.instancia)
        .listarFinalizadas();
    final linhas = <List<String>>[
      [
        'tipo',
        'inicio',
        'fim',
        'atividade',
        'duracao_segundos',
        'series_concluidas',
        'distancia_metros',
        'anotacoes',
      ],
      ...treinos.sessoesTreino.map((sessao) {
        final series = sessao['series'];
        final concluidas = series is List
            ? series
                  .whereType<Map>()
                  .where((serie) => serie['concluida'] == true)
                  .length
            : 0;
        final inicio = DateTime.tryParse(sessao['inicio']?.toString() ?? '');
        final fim = DateTime.tryParse(sessao['fim']?.toString() ?? '');
        final duracao = inicio != null && fim != null
            ? fim.difference(inicio).inSeconds
            : '';
        return [
          'musculacao',
          inicio?.toIso8601String() ?? '',
          fim?.toIso8601String() ?? '',
          sessao['nomeTreino']?.toString() ?? '',
          '$duracao',
          '$concluidas',
          '',
          sessao['anotacoes']?.toString() ?? '',
        ];
      }),
      ...corridas.map(
        (corrida) => [
          'corrida',
          corrida.inicio.toIso8601String(),
          corrida.fim.toIso8601String(),
          'Corrida',
          '${corrida.duracaoSegundos}',
          '',
          '${corrida.distanciaMetros}',
          '',
        ],
      ),
    ];
    return linhas.map((linha) => linha.map(_escaparCsv).join(';')).join('\r\n');
  }

  static String _escaparCsv(String valor) {
    final seguro = RegExp(r'^\s*[=+\-@]').hasMatch(valor) ? "'$valor" : valor;
    return '"${seguro.replaceAll('"', '""')}"';
  }

  static Future<void> importar(
    String conteudo, {
    WorkHolyBanco? bancoTreino,
    CorridaBanco? bancoCorrida,
  }) async {
    final Object? decodificado;
    try {
      decodificado = jsonDecode(conteudo);
    } on FormatException catch (erro) {
      throw FormatException('O texto não é um backup JSON válido: $erro');
    }

    final versaoBackup = decodificado is Map ? decodificado['versao'] : null;
    if (decodificado is! Map ||
        decodificado['formato'] != _formato ||
        (versaoBackup != 2 && versaoBackup != _versao) ||
        decodificado['dados'] is! Map) {
      throw const FormatException(
        'O arquivo não é um backup Moveria compatível.',
      );
    }

    final dados = Map<String, dynamic>.from(decodificado['dados'] as Map);
    final treinos = _colecao(dados, 'treinos');
    final exercicios = _colecao(dados, 'exercicios');
    final itensTreino = _colecao(dados, 'itensTreino');
    final sessoesTreino = _colecao(dados, 'sessoesTreino');
    final corridas = _colecao(dados, 'corridas');
    final alunos = versaoBackup == 2
        ? <Map<String, dynamic>>[]
        : _colecao(dados, 'alunos');
    final anotacoesAlunos = versaoBackup == 2
        ? <Map<String, dynamic>>[]
        : _colecao(dados, 'anotacoesAlunos');

    _validarIds(treinos, 'treinos');
    _validarIds(exercicios, 'exercicios');
    _validarIds(itensTreino, 'itensTreino');
    _validarIds(sessoesTreino, 'sessoesTreino');
    _validarIds(alunos, 'alunos');
    _validarIds(anotacoesAlunos, 'anotacoesAlunos');
    final alunosConvertidos = <Aluno>[];
    final anotacoesConvertidas = <AnotacaoAluno>[];
    final idsAlunosBackup = <String>{};
    try {
      alunosConvertidos.addAll(alunos.map(Aluno.fromJson));
      anotacoesConvertidas.addAll(anotacoesAlunos.map(AnotacaoAluno.fromJson));
      idsAlunosBackup.addAll(alunosConvertidos.map((aluno) => aluno.id));
      final idsTreinos = treinos
          .map((treino) => treino['id'] as String)
          .toSet();
      if (alunosConvertidos.any(
        (aluno) => aluno.treinoIds.any((id) => !idsTreinos.contains(id)),
      )) {
        throw const FormatException('Há treino atribuído que não existe.');
      }
      if (anotacoesConvertidas.any(
        (anotacao) => !idsAlunosBackup.contains(anotacao.alunoId),
      )) {
        throw const FormatException('Há anotação sem aluno correspondente.');
      }
    } catch (erro) {
      throw FormatException('O backup contém dados de alunos inválidos: $erro');
    }
    try {
      for (final treino in treinos) {
        Treino.fromJson(treino);
      }
      for (final exercicio in exercicios) {
        Exercicio.fromJson(exercicio);
      }
      for (final item in itensTreino) {
        ItemTreino.fromJson(item);
      }
      for (final sessao in sessoesTreino) {
        SessaoTreino.fromJson(sessao);
        final alunoId = sessao['alunoId'];
        if (alunoId != null &&
            (alunoId is! String || !idsAlunosBackup.contains(alunoId))) {
          throw const FormatException('Há sessão sem aluno correspondente.');
        }
      }
    } catch (erro) {
      throw FormatException('O backup contém dados de treino inválidos: $erro');
    }
    _validarIds(corridas, 'corridas');
    for (final corrida in corridas) {
      final inicio = corrida['inicio_ms'];
      final fim = corrida['fim_ms'];
      final rotaTexto = corrida['rota_json'];
      if (corrida['estado'] != 'finalizada' ||
          inicio is! num ||
          fim is! num ||
          corrida['duracao_segundos'] is! num ||
          corrida['distancia_metros'] is! num ||
          rotaTexto is! String) {
        throw const FormatException(
          'O backup contém uma corrida finalizada com dados inválidos.',
        );
      }
      final rota = jsonDecode(rotaTexto);
      if (rota is! List ||
          rota.any(
            (ponto) =>
                ponto is! Map || ponto['lat'] is! num || ponto['lon'] is! num,
          )) {
        throw const FormatException('O backup contém uma rota inválida.');
      }
    }

    final bancoTreinoEfetivo = bancoTreino ?? WorkHolyBanco.instancia;
    final bancoCorridaEfetivo = bancoCorrida ?? CorridaBanco.instancia;
    final dadosAnteriores = await bancoTreinoEfetivo.carregarDadosTreino();
    final alunosAnteriores = await bancoTreinoEfetivo.listarAlunosParaBackup();
    final anotacoesAnteriores = await bancoTreinoEfetivo
        .listarAnotacoesParaBackup();
    try {
      await bancoTreinoEfetivo.salvarDadosTreino(
        treinos: treinos,
        exercicios: exercicios,
        itensTreino: itensTreino,
        sessoesTreino: sessoesTreino,
      );
      if (versaoBackup == _versao) {
        await bancoTreinoEfetivo.substituirAlunosEAnotacoes(
          alunos: alunosConvertidos,
          anotacoes: anotacoesConvertidas,
        );
      }
      await bancoCorridaEfetivo.substituirFinalizadas(corridas);
    } catch (erro) {
      try {
        await bancoTreinoEfetivo.salvarDadosTreino(
          treinos: dadosAnteriores.treinos,
          exercicios: dadosAnteriores.exercicios,
          itensTreino: dadosAnteriores.itensTreino,
          sessoesTreino: dadosAnteriores.sessoesTreino,
        );
        await bancoTreinoEfetivo.substituirAlunosEAnotacoes(
          alunos: alunosAnteriores,
          anotacoes: anotacoesAnteriores,
        );
      } catch (erroRollback) {
        throw StateError(
          'A restauração falhou ($erro) e não foi possível recuperar os '
          'dados anteriores ($erroRollback).',
        );
      }
      rethrow;
    }
  }

  static List<Map<String, dynamic>> _colecao(
    Map<String, dynamic> dados,
    String chave,
  ) {
    final valor = dados[chave];
    if (valor is! List || valor.any((item) => item is! Map)) {
      throw FormatException('A coleção "$chave" está ausente ou inválida.');
    }
    return valor.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  static void _validarIds(
    List<Map<String, dynamic>> registros,
    String nomeColecao,
  ) {
    final ids = <String>{};
    for (final registro in registros) {
      final id = registro['id'];
      if (id is! String || id.trim().isEmpty || !ids.add(id)) {
        throw FormatException(
          'Há um id inválido ou duplicado em $nomeColecao.',
        );
      }
    }
  }
}
