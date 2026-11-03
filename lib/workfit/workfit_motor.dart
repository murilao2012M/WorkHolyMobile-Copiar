import 'dart:math';

import '../exercicios/biblioteca_exercicios.dart';
import 'workfit_aprendizado.dart';
import 'workfit_perfil.dart';

class ExercicioBanco {
  final String id;
  final String nome;
  final String grupo;
  final int seriesPadrao;
  final int repeticoesPadrao;
  final String detalhes;
  final String equipamento;
  final String categoria;
  final String nivel;
  final String mecanica;
  final List<String> instrucoes;
  final List<String> instrucoesOriginais;
  final List<String> musculosPrimarios;

  const ExercicioBanco({
    required this.id,
    required this.nome,
    required this.grupo,
    this.seriesPadrao = 3,
    this.repeticoesPadrao = 12,
    this.detalhes = '',
    this.equipamento = '',
    this.categoria = '',
    this.nivel = '',
    this.mecanica = '',
    this.instrucoes = const [],
    this.instrucoesOriginais = const [],
    this.musculosPrimarios = const [],
  });

  factory ExercicioBanco.doCatalogo(ExercicioPredefinido ex) => ExercicioBanco(
    id: ex.id,
    nome: ex.nome,
    grupo: ex.grupo,
    seriesPadrao: ex.series,
    repeticoesPadrao: ex.repeticoes,
    detalhes: [...ex.musculosPrimarios, ex.categoria].join(' '),
    equipamento: ex.equipamentoOriginal,
    categoria: ex.categoriaOriginal,
    nivel: ex.nivelOriginal,
    mecanica: ex.mecanicaOriginal,
    instrucoes: ex.instrucoes,
    instrucoesOriginais: ex.instrucoesOriginais,
    musculosPrimarios: ex.musculosPrimariosOriginais,
  );
}

class _Candidato {
  const _Candidato(this.exercicio, this.pontos, this.motivo);
  final ExercicioBanco exercicio;
  final int pontos;
  final String motivo;
}

class _Atributos {
  const _Atributos(this.descricao, this.texto, this.grupo, this.equipamentos);
  final String descricao;
  final String texto;
  final String grupo;
  final Set<String> equipamentos;
}

/// Recomendação local baseada em metadados e sinais nas instruções.
/// Não é um modelo de linguagem nem uma avaliação profissional.
class WorkFitMotor {
  static const equipamentos = <String, Set<String>>{
    'halteres': {'dumbbell'},
    'barra': {'barbell', 'olympic barbell', 'ez barbell', 'e-z curl bar'},
    'maquinas': {
      'machine',
      'leverage machine',
      'smith machine',
      'sled machine',
      'stationary bike',
      'elliptical machine',
      'stepmill machine',
      'upper body ergometer',
      'skierg machine',
    },
    'polia': {'cable'},
    'kettlebell': {'kettlebell', 'kettlebells'},
    'elastico': {'bands', 'resistance band'},
    'bola': {'medicine ball', 'stability ball', 'exercise ball', 'bosu ball'},
    'corda': {'rope'},
    'rolo': {'foam roll', 'roller', 'wheel roller'},
  };

  static const _sinaisEquipamento = <String, List<String>>{
    'halteres': ['dumbbell', 'dumbbells'],
    'barra': ['barbell', 'barbells', 'olympic bar', 'ez bar', 'e-z bar'],
    'maquinas': ['smith machine', 'leg press machine', 'exercise machine'],
    'polia': ['cable machine', 'cable pulley', 'cable station'],
    'kettlebell': ['kettlebell', 'kettlebells'],
    'elastico': ['resistance band', 'exercise band', 'elastic band'],
    'bola': ['medicine ball', 'stability ball', 'exercise ball', 'swiss ball'],
    'corda': ['jump rope', 'skipping rope'],
    'rolo': ['foam roller', 'ab wheel'],
    'banco': ['bench', 'banco'],
    'barra_fixa': ['pull-up', 'pullup', 'chin-up', 'chinup', 'barra fixa'],
    'caixa': ['box', 'plyo box', 'caixa'],
    'cadeira': ['chair', 'cadeira'],
    'paralelas': ['parallel bars', 'dip bars', 'barras paralelas'],
    'argolas': ['gymnastic rings', 'gymnastics rings', 'argolas'],
  };

  static final _padroes = <String, RegExp>{};
  static final _cache = Expando<_Atributos>();

  static bool _temTermo(String texto, String termo) =>
      (_padroes[termo] ??= RegExp(
        '(^|[^a-z0-9])${RegExp.escape(termo)}([^a-z0-9]|\$)',
      )).hasMatch(texto);

  static String _normalizar(String texto) => texto
      .toLowerCase()
      .replaceAll(RegExp('[áàâãä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[íìîï]'), 'i')
      .replaceAll(RegExp('[óòôõö]'), 'o')
      .replaceAll(RegExp('[úùûü]'), 'u')
      .replaceAll('ç', 'c');

  static _Atributos _atributos(ExercicioBanco ex) {
    final existente = _cache[ex];
    if (existente != null) return existente;
    final descricao = _normalizar(
      [...ex.instrucoesOriginais, ...ex.instrucoes].join(' '),
    );
    final texto =
        '${_normalizar(ex.id.replaceAll('_', ' '))} '
        '${_normalizar(ex.nome)} $descricao';
    final grupos = _normalizar(
      '${ex.grupo} ${ex.detalhes} ${ex.musculosPrimarios.join(' ')}',
    );
    final equipamentos = _sinaisEquipamento.entries
        .where(
          (entrada) => entrada.value.any((termo) => _temTermo(texto, termo)),
        )
        .map((entrada) => entrada.key)
        .toSet();
    return _cache[ex] = _Atributos(descricao, texto, grupos, equipamentos);
  }

  static bool _possuiEquipamento(WorkFitPerfil perfil, String equipamento) {
    if (perfil.equipamentosDisponiveis != null) {
      return perfil.equipamentosDisponiveis!.contains(equipamento);
    }
    final local = _normalizar(perfil.equipamento);
    return !(local.contains('casa') ||
        local.contains('condominio') ||
        local.contains('rua'));
  }

  static bool _compativel(WorkFitPerfil perfil, ExercicioBanco ex) {
    final equipamento = ex.equipamento.toLowerCase();
    if (equipamento != 'body only' &&
        equipamento != 'body weight' &&
        equipamento.isNotEmpty) {
      final grupos = equipamentos.entries.where(
        (entrada) => entrada.value.contains(equipamento),
      );
      if (grupos.isEmpty ||
          !grupos.any((e) => _possuiEquipamento(perfil, e.key))) {
        return false;
      }
    } else if (equipamento.isEmpty) {
      // Sem metadado de equipamento não é possível garantir compatibilidade.
      return false;
    }
    final atributos = _atributos(ex);
    for (final equipamento in atributos.equipamentos) {
      if (!_possuiEquipamento(perfil, equipamento)) {
        return false;
      }
    }
    if ([
      'partner',
      'spotter',
      'parceiro',
      'ajuda de um colega',
    ].any((termo) => _temTermo(atributos.texto, termo))) {
      return false;
    }
    final nivel = ex.nivel.toLowerCase();
    if (perfil.experiencia == 'iniciante' && nivel != 'beginner') {
      return false;
    }
    if (perfil.experiencia == 'intermediario' && nivel == 'expert') {
      return false;
    }
    if (perfil.experiencia != 'avancado' &&
        ['olympic weightlifting', 'strongman'].contains(ex.categoria)) {
      return false;
    }
    return true;
  }

  static bool _grupo(ExercicioBanco ex, String grupo) {
    const musculos = <String, List<String>>{
      'Peito': ['chest', 'peito', 'pectorais'],
      'Costas': [
        'lats',
        'middle back',
        'lower back',
        'traps',
        'costas',
        'back',
        'dorso',
      ],
      'Pernas': [
        'quadriceps',
        'hamstrings',
        'glutes',
        'calves',
        'adductors',
        'abductors',
        'perna',
        'pernas',
        'leg',
        'gluteo',
      ],
      'Ombros': ['shoulders', 'ombro', 'ombros', 'shoulder', 'deltoides'],
      'Braços': ['biceps', 'triceps', 'forearms', 'braco', 'bracos'],
      'Abdômen': ['abdominals', 'abdomen', 'waist'],
    };
    final texto = _atributos(ex).grupo;
    return musculos[grupo]!.any((termo) => _temTermo(texto, termo));
  }

  static _Candidato _avaliar(
    WorkFitPerfil perfil,
    ExercicioBanco ex,
    AprendizadoWorkFit aprendizado,
  ) {
    final atributos = _atributos(ex);
    final instrucoes = atributos.descricao;
    final termos = atributos.texto;
    var pontos = 0;
    final motivos = <String>[];
    if (ex.nivel.toLowerCase() == 'beginner') {
      pontos += perfil.experiencia == 'iniciante' ? 8 : 2;
      motivos.add('nível iniciante');
    } else if (ex.nivel.isEmpty) {
      pontos -= 2;
    }
    if (ex.mecanica == 'compound') {
      pontos += perfil.objetivo == 'hipertrofia' ? 6 : 3;
      motivos.add('movimento composto');
    }
    if ([
      'controlled',
      'slowly',
      'controlado',
      'devagar',
    ].any((termo) => _temTermo(instrucoes, termo))) {
      pontos += perfil.experiencia == 'iniciante' ? 4 : 1;
      motivos.add('instruções de movimento controlado');
    }
    if (perfil.tipoTreino == 'crossfit' &&
        [
          'squat',
          'agachamento',
          'burpee',
          'deadlift',
          'clean',
          'thruster',
        ].any((termo) => _temTermo(termos, termo))) {
      pontos += 6;
      motivos.add('movimento funcional');
    }
    if (perfil.objetivo == 'emagrecimento' &&
        ['plyometrics', 'cardio'].contains(ex.categoria)) {
      pontos += 2;
    }
    if (ex.instrucoes.isNotEmpty || ex.instrucoesOriginais.isNotEmpty) {
      pontos += 1;
    }
    final ajuste = aprendizado.bonusPara(ex);
    if (ajuste != 0) {
      pontos += ajuste;
      final porSemelhanca = aprendizado.somenteModelo(ex);
      motivos.add(
        ajuste > 0
            ? (porSemelhanca
                  ? 'parecido com o que você costuma concluir'
                  : 'boa adesão no seu histórico')
            : (porSemelhanca
                  ? 'parecido com o que você costuma abandonar'
                  : 'menor adesão no seu histórico'),
      );
    }
    return _Candidato(
      ex,
      pontos,
      motivos.isEmpty ? 'grupo muscular compatível' : motivos.join(', '),
    );
  }

  static List<_Candidato> _ordenar(
    WorkFitPerfil perfil,
    Iterable<ExercicioBanco> exercicios,
    AprendizadoWorkFit aprendizado,
  ) {
    final resultado = exercicios
        .where((ex) => _compativel(perfil, ex) && !aprendizado.evitar(ex.id))
        .map((ex) => _avaliar(perfil, ex, aprendizado))
        .toList();
    resultado.sort((a, b) {
      final porPontos = b.pontos.compareTo(a.pontos);
      return porPontos != 0
          ? porPontos
          : a.exercicio.id.compareTo(b.exercicio.id);
    });
    return resultado;
  }

  static List<WorkFitSugestao> gerarSugestoes(
    WorkFitPerfil perfil,
    List<ExercicioBanco> exercicios, {
    AprendizadoWorkFit? aprendizado,
  }) {
    final aprendido = aprendizado ?? AprendizadoWorkFit.vazio;
    if (![
      'musculacao',
      'crossfit',
      'corrida',
      'personal',
    ].contains(perfil.tipoTreino)) {
      throw ArgumentError.value(perfil.tipoTreino, 'tipoTreino');
    }
    if (![
          'iniciante',
          'intermediario',
          'avancado',
        ].contains(perfil.experiencia) ||
        perfil.minutosPorDia < 10 ||
        perfil.diasPorSemana < 1 ||
        perfil.diasPorSemana > 7) {
      throw ArgumentError('Perfil de treino inválido.');
    }
    if (perfil.tipoTreino == 'corrida') {
      final corrida = exercicios.where(
        (ex) => ex.id == 'Trail_Running_Walking',
      );
      if (corrida.isEmpty) return [];
      final ex = corrida.first;
      return [
        WorkFitSugestao(
          nomeTreino: 'Corrida e Resistência',
          perfil: perfil,
          descricao:
              'Caminhe ou corra em ritmo confortável por até ${perfil.minutosPorDia} minutos. Registre a atividade na aba Corrida.',
          tempoEstimadoMinutos: perfil.minutosPorDia,
          exercicios: [
            WorkFitItemExercicio(
              exercicioId: ex.id,
              nomeExercicio: ex.nome,
              grupo: 'Cardio',
              series: 1,
              repeticoes: 1,
              cargaKgPadrao: 0,
              descansoSegundos: 0,
              justificativa: 'Corrida ou caminhada ao ar livre',
            ),
          ],
        ),
      ];
    }

    final disponiveis = exercicios.where((ex) {
      if (['stretching', 'cardio', 'strongman'].contains(ex.categoria)) {
        return false;
      }
      if (perfil.tipoTreino != 'crossfit') return true;
      final nome = _normalizar('${ex.nome} ${ex.id.replaceAll('_', ' ')}');
      return [
        'squat',
        'push-up',
        'pushup',
        'burpee',
        'lunge',
        'deadlift',
        'clean',
        'snatch',
        'thruster',
        'swing',
        'plank',
        'agachamento',
        'flexao',
        'prancha',
        'afundo',
        'levantamento terra',
      ].any((termo) => _temTermo(nome, termo));
    });
    final ordenados = _ordenar(perfil, disponiveis, aprendido);
    if (ordenados.isEmpty) return [];
    final tresDiasMusculacao =
        perfil.tipoTreino == 'musculacao' && perfil.diasPorSemana == 3;
    final grupos = perfil.tipoTreino == 'personal' || perfil.diasPorSemana <= 2
        ? [
            ['Peito', 'Pernas', 'Costas', 'Ombros', 'Braços', 'Abdômen'],
          ]
        : tresDiasMusculacao
        ? [
            ['Pernas', 'Peito', 'Costas', 'Abdômen', 'Ombros', 'Braços'],
            ['Costas', 'Pernas', 'Ombros', 'Braços', 'Peito', 'Abdômen'],
            ['Abdômen', 'Ombros', 'Braços', 'Pernas', 'Costas', 'Peito'],
          ]
        : perfil.diasPorSemana == 3
        ? [
            ['Peito', 'Pernas', 'Braços'],
            ['Costas', 'Pernas', 'Ombros'],
          ]
        : [
            ['Peito', 'Braços'],
            ['Costas', 'Ombros'],
            ['Pernas', 'Abdômen'],
          ];
    final series = perfil.experiencia == 'iniciante' ? 2 : 3;
    final repeticoes = switch (perfil.objetivo) {
      'forca' => 6,
      'hipertrofia' => 8,
      'resistencia' => 15,
      _ => 12,
    };
    final descanso = perfil.objetivo == 'forca' ? 120 : 60;
    // Estimativa: execução a 3 s por repetição, pausas e 45 s de transição.
    final segundosExercicio =
        series * repeticoes * 3 + (series - 1) * descanso + 45;
    final capacidade = max(
      1,
      (perfil.minutosPorDia * 60 - 180) ~/ segundosExercicio,
    );
    final usados = <String>{};
    final gruposCobertos = <String>{};
    final resultado = <WorkFitSugestao>[];
    for (var i = 0; i < grupos.length; i++) {
      final escolhidos = <_Candidato>[];
      final gruposEscolhidos = <String>[];
      for (final grupo in grupos[i]) {
        if (escolhidos.length >= capacidade) break;
        final candidatos = ordenados
            .where(
              (c) =>
                  _grupo(c.exercicio, grupo) &&
                  !escolhidos.any(
                    (outro) => outro.exercicio.id == c.exercicio.id,
                  ),
            )
            .toList();
        if (candidatos.isNotEmpty) {
          final novos = candidatos.where(
            (c) => !usados.contains(c.exercicio.id),
          );
          if (novos.isNotEmpty) {
            escolhidos.add(novos.first);
          } else if (tresDiasMusculacao) {
            escolhidos.add(candidatos.first);
          } else {
            continue;
          }
          gruposEscolhidos.add(grupo);
          gruposCobertos.add(grupo);
        }
      }
      if (escolhidos.isEmpty) continue;
      usados.addAll(escolhidos.map((c) => c.exercicio.id));
      final nome = switch (perfil.tipoTreino) {
        'crossfit' => 'CrossFit ${i + 1}',
        'personal' => 'Treino com Personal Trainer',
        _ => 'Treino ${i + 1}: ${gruposEscolhidos.join(' e ')}',
      };
      resultado.add(
        WorkFitSugestao(
          nomeTreino: nome,
          perfil: perfil,
          descricao: 'Sugestão baseada no nível, objetivo, equipamentos e instruções do catálogo. Ajuste com um profissional de educação física.',
          tempoEstimadoMinutos: min(
            perfil.minutosPorDia,
            ((180 + escolhidos.length * segundosExercicio) / 60).ceil(),
          ),
          exercicios: escolhidos
              .map(
                (c) => WorkFitItemExercicio(
                  exercicioId: c.exercicio.id,
                  nomeExercicio: c.exercicio.nome,
                  grupo: c.exercicio.grupo,
                  series: series,
                  repeticoes: repeticoes,
                  cargaKgPadrao: 0,
                  descansoSegundos: descanso,
                  justificativa: c.motivo,
                ),
              )
              .toList(),
        ),
      );
    }
    if (tresDiasMusculacao) {
      final faltantes = [
        'Peito',
        'Costas',
        'Pernas',
        'Ombros',
        'Braços',
        'Abdômen',
      ].where((grupo) => !gruposCobertos.contains(grupo)).toList();
      if (faltantes.isNotEmpty || resultado.length < perfil.diasPorSemana) {
        final avisos = <String>[
          if (resultado.length < perfil.diasPorSemana)
            'Não foi possível montar ${perfil.diasPorSemana} treinos distintos.',
          if (faltantes.isNotEmpty)
            'Não foi possível incluir ${faltantes.join(', ')} no plano '
                'com as opções e o tempo informados.',
        ];
        return resultado
            .map(
              (sugestao) => WorkFitSugestao(
                nomeTreino: sugestao.nomeTreino,
                perfil: sugestao.perfil,
                descricao:
                    '${sugestao.descricao} Atenção: ${avisos.join(' ')} '
                    'Revise com um profissional.',
                tempoEstimadoMinutos: sugestao.tempoEstimadoMinutos,
                exercicios: sugestao.exercicios,
              ),
            )
            .toList();
      }
    }
    return resultado;
  }
}
