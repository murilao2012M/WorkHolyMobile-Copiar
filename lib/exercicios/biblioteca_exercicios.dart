
import 'dart:convert';

import 'package:flutter/services.dart';

/// Exercício do catálogo Free Exercise DB com suporte a pt-BR.
class ExercicioPredefinido {
  const ExercicioPredefinido({
    required this.id,
    required this.nome,
    required this.grupo,
    required this.musculosPrimarios,
    required this.musculosSecundarios,
    required this.instrucoes,
    required this.imagens,
    this.forca = '',
    this.nivel = '',
    this.mecanica = '',
    this.equipamento = '',
    this.categoria = '',
    this.series = 3,
    this.repeticoes = 12,
  });

  final String id;
  final String nome;
  final String grupo;
  final String forca;
  final String nivel;
  final String mecanica;
  final String equipamento;
  final String categoria;
  final List<String> musculosPrimarios;
  final List<String> musculosSecundarios;
  final List<String> instrucoes;
  final List<String> imagens;
  final int series;
  final int repeticoes;

  /// Prefixo dos arquivos de imagem locais.
  static const String prefixoImagensAssets =
      'assets/exercicios/imagens/';

  /// Caminhos completos das imagens incluídas no aplicativo.
  List<String> get caminhosImagensAssets {
    return List.unmodifiable(
      imagens.map(
        (imagem) =>
            '$prefixoImagensAssets${imagem.replaceAll(r'\', '/')}',
      ),
    );
  }

  factory ExercicioPredefinido.fromFreeExerciseDb(
    Map<String, dynamic> dados, {
    Map<String, dynamic> campos = const {},
    Map<String, dynamic> traducaoExercicio = const {},
  }) {
    final idOriginal = dados['id']?.toString().trim() ?? '';
    final id = idOriginal.isEmpty
        ? (dados['name']?.toString().trim() ?? '')
        : idOriginal;

    final nomeOriginal = dados['name']?.toString().trim() ?? id;
    if (nomeOriginal.isEmpty) {
      throw const FormatException('Exercício sem nome no catálogo.');
    }

    final nomeTraduzido =
        traducaoExercicio['nome']?.toString().trim();
    final nome = nomeTraduzido != null && nomeTraduzido.isNotEmpty
        ? nomeTraduzido
        : nomeOriginal;

    // O grupo é calculado usando os músculos originais em inglês.
    // Isso preserva a compatibilidade com os filtros existentes.
    final musculosOriginais =
        _listaDeTextos(dados['primaryMuscles']);

    final musculosPrimarios = _traduzirLista(
      musculosOriginais,
      campos['musculos'],
    );

    final musculosSecundarios = _traduzirLista(
      _listaDeTextos(dados['secondaryMuscles']),
      campos['musculos'],
    );

    final instrucoesTraduzidas =
        traducaoExercicio['instrucoes'];

    final instrucoes = instrucoesTraduzidas is List
        ? _listaDeTextos(instrucoesTraduzidas)
        : _listaDeTextos(dados['instructions']);

    return ExercicioPredefinido(
      id: id,
      nome: nome,
      grupo: _grupoEmPortugues(musculosOriginais),
      forca: dados['force']?.toString() ?? '',
      nivel: _traduzirCampo(campos['nivel'], dados['level']),
      mecanica: _traduzirCampo(
        campos['mecanica'],
        dados['mechanic'],
      ),
      equipamento: _traduzirCampo(
        campos['equipamento'],
        dados['equipment'],
      ),
      categoria: _traduzirCampo(
        campos['categoria'],
        dados['category'],
      ),
      musculosPrimarios: musculosPrimarios,
      musculosSecundarios: musculosSecundarios,
      instrucoes: instrucoes,
      imagens: _listaDeTextos(dados['images']),
    );
  }

  static String _traduzirCampo(
    Object? mapaTraducao,
    Object? valorOriginal,
  ) {
    final original = valorOriginal?.toString() ?? '';
    if (mapaTraducao is! Map) return original;

    final traducao = mapaTraducao[original];
    if (traducao == null) return original;

    final texto = traducao.toString().trim();
    return texto.isEmpty ? original : texto;
  }

  static List<String> _traduzirLista(
    List<String> originais,
    Object? mapaTraducao,
  ) {
    return List.unmodifiable(
      originais.map(
        (original) => _traduzirCampo(mapaTraducao, original),
      ),
    );
  }

  static List<String> _listaDeTextos(Object? valor) {
    if (valor is! List) return const [];

    return List.unmodifiable(
      valor
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty),
    );
  }

  static String _grupoEmPortugues(List<String> musculos) {
    final musculo = musculos.isEmpty
        ? ''
        : musculos.first.toLowerCase();

    return switch (musculo) {
      'chest' => 'Peito',
      'lats' || 'middle back' || 'lower back' || 'traps' =>
        'Costas',
      'shoulders' => 'Ombros',
      'biceps' || 'triceps' || 'forearms' => 'Braços',
      'abdominals' => 'Abdômen',
      'quadriceps' ||
      'hamstrings' ||
      'calves' ||
      'glutes' ||
      'adductors' ||
      'abductors' => 'Pernas',
      'neck' => 'Pescoço',
      'cardiovascular' => 'Cardio',
      _ => 'Outros',
    };
  }
}

/// Carrega o catálogo e as traduções locais uma única vez.
class CatalogoExercicios {
  CatalogoExercicios._();

  static final CatalogoExercicios instancia =
      CatalogoExercicios._();

  static const caminhoAsset =
      'assets/exercicios/free_exercise_db.json';

  static const caminhoTraducoesAsset =
      'assets/exercicios/traducoes_pt_BR.json';

  Future<List<ExercicioPredefinido>>? _carregamento;

  Future<List<ExercicioPredefinido>> carregar() {
    return _carregamento ??= _carregarDoAsset();
  }

  Future<List<ExercicioPredefinido>> _carregarDoAsset() async {
    final conteudos = await Future.wait<String>([
      rootBundle.loadString(caminhoAsset),
      rootBundle.loadString(caminhoTraducoesAsset),
    ]);

    final dados = jsonDecode(conteudos[0]);
    final dadosTraducoes = jsonDecode(conteudos[1]);

    if (dados is! List) {
      throw const FormatException(
        'O catálogo de exercícios não é uma lista.',
      );
    }

    if (dadosTraducoes is! Map) {
      throw const FormatException(
        'O arquivo de traduções não contém um objeto JSON válido.',
      );
    }

    final traducoes = Map<String, dynamic>.from(dadosTraducoes);

    final camposBrutos = traducoes['campos'];
    final campos = camposBrutos is Map
        ? Map<String, dynamic>.from(camposBrutos)
        : <String, dynamic>{};

    final exerciciosBrutos = traducoes['exercicios'];
    final traducoesPorId = exerciciosBrutos is Map
        ? Map<String, dynamic>.from(exerciciosBrutos)
        : <String, dynamic>{};

    final exercicios = <ExercicioPredefinido>[];

    for (final item in dados) {
      if (item is! Map) continue;

      try {
        final dadosExercicio = Map<String, dynamic>.from(item);
        final id = dadosExercicio['id']?.toString() ?? '';
        final traducaoBruta = traducoesPorId[id];

        final traducaoExercicio = traducaoBruta is Map
            ? Map<String, dynamic>.from(traducaoBruta)
            : <String, dynamic>{};

        exercicios.add(
          ExercicioPredefinido.fromFreeExerciseDb(
            dadosExercicio,
            campos: campos,
            traducaoExercicio: traducaoExercicio,
          ),
        );
      } on FormatException {
        // Um exercício inválido não bloqueia o restante do catálogo.
      }
    }

    exercicios.sort(
      (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()),
    );

    return List.unmodifiable(exercicios);
  }
}
