import 'dart:math';

import 'workfit_aprendizado.dart';
import 'workfit_motor.dart';

/// Vetores TF-IDF calculados no aparelho a partir do texto de cada exercício
/// (nome, grupo, equipamento, músculos e instruções). Não é um modelo de
/// linguagem: mede semelhança por vocabulário compartilhado.
class VetoresExercicios {
  VetoresExercicios._(this._vetores);

  final Map<String, Map<String, double>> _vetores;

  static const _semAcento = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
  };

  static const _irrelevantes = {
    'para',
    'com',
    'sem',
    'uma',
    'uns',
    'umas',
    'por',
    'dos',
    'das',
    'que',
    'seu',
    'sua',
    'seus',
    'suas',
    'ate',
    'como',
    'mais',
    'entre',
    'sobre',
    'the',
    'and',
    'with',
    'your',
    'then',
    'from',
    'that',
    'this',
    'into',
    'repita',
    'volte',
    'posicao',
    'inicial',
  };

  static String normalizar(String texto) {
    final buffer = StringBuffer();
    for (final c in texto.toLowerCase().split('')) {
      buffer.write(_semAcento[c] ?? c);
    }
    return buffer.toString();
  }

  static List<String> _tokens(String texto) =>
      normalizar(texto)
          .split(RegExp(r'[^a-z0-9]+'))
          .where((t) => t.length >= 3 && !_irrelevantes.contains(t))
          .toList();

  factory VetoresExercicios.construir(Iterable<ExercicioBanco> exercicios) {
    final frequencias = <String, Map<String, int>>{};
    final documentos = <String, int>{};
    for (final ex in exercicios) {
      final texto = [
        ex.nome,
        ex.nome,
        ex.grupo,
        ex.equipamento,
        ex.categoria,
        ...ex.musculosPrimarios,
        ...ex.instrucoes.take(6),
      ].join(' ');
      final tf = <String, int>{};
      for (final t in _tokens(texto)) {
        tf[t] = (tf[t] ?? 0) + 1;
      }
      frequencias[ex.id] = tf;
    }
    for (final tf in frequencias.values) {
      for (final t in tf.keys) {
        documentos[t] = (documentos[t] ?? 0) + 1;
      }
    }
    final n = frequencias.length;
    final vetores = <String, Map<String, double>>{};
    frequencias.forEach((id, tf) {
      final vetor = <String, double>{};
      var soma = 0.0;
      tf.forEach((termo, c) {
        final peso =
            (1 + log(c)) * (log((1 + n) / (1 + documentos[termo]!)) + 1);
        vetor[termo] = peso;
        soma += peso * peso;
      });
      final norma = sqrt(soma);
      if (norma > 0) vetor.updateAll((_, v) => v / norma);
      vetores[id] = vetor;
    });
    return VetoresExercicios._(vetores);
  }

  int get total => _vetores.length;

  /// Similaridade de cosseno entre 0 e 1; 0 se algum exercício for desconhecido.
  double similaridade(String a, String b) {
    final va = _vetores[a];
    final vb = _vetores[b];
    if (va == null || vb == null) return 0;
    final menor = va.length <= vb.length ? va : vb;
    final maior = identical(menor, va) ? vb : va;
    var soma = 0.0;
    menor.forEach((t, v) {
      final o = maior[t];
      if (o != null) soma += v * o;
    });
    return soma.clamp(0.0, 1.0);
  }
}

/// Regressão logística treinada no aparelho com o histórico do próprio cliente.
/// Prevê a chance de ele concluir um exercício, usando categorias (grupo,
/// equipamento, mecânica, nível) e a conclusão de exercícios parecidos.
class ModeloConclusao {
  ModeloConclusao._(
    this._pesos,
    this._vies,
    this._vetores,
    this._taxaPorId,
    this.amostras,
  );

  static const int minimoAmostras = 20;
  static const int minimoSessoes = 5;
  static const double _prior = 0.7;
  static const int _vizinhos = 5;
  static const double _similaridadeMinima = 0.15;

  final Map<String, double> _pesos;
  final double _vies;
  final VetoresExercicios _vetores;
  final Map<String, double> _taxaPorId;
  final int amostras;

  bool get treinado => amostras >= minimoAmostras;

  static double _sigmoide(double z) => 1 / (1 + exp(-z));

  static Map<String, double> _caracteristicas(
    ExercicioBanco ex,
    VetoresExercicios vetores,
    Map<String, double> taxaPorId,
  ) {
    final f = <String, double>{};
    void categoria(String prefixo, String valor) {
      final v = VetoresExercicios.normalizar(valor.trim());
      if (v.isNotEmpty) f['$prefixo:$v'] = 1;
    }

    categoria('g', ex.grupo);
    categoria('e', ex.equipamento);
    categoria('m', ex.mecanica);
    categoria('n', ex.nivel);

    final vizinhos = <MapEntry<String, double>>[];
    taxaPorId.forEach((id, _) {
      if (id == ex.id) return;
      final s = vetores.similaridade(ex.id, id);
      if (s >= _similaridadeMinima) vizinhos.add(MapEntry(id, s));
    });
    if (vizinhos.isNotEmpty) {
      vizinhos.sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
      var soma = 0.0;
      var pesos = 0.0;
      for (final v in vizinhos.take(_vizinhos)) {
        soma += taxaPorId[v.key]! * v.value;
        pesos += v.value;
      }
      f['vizinhos'] = soma / pesos - _prior;
    }
    return f;
  }

  factory ModeloConclusao.treinar({
    required List<SessaoAprendizado> sessoes,
    required Map<String, ExercicioBanco> catalogo,
    required VetoresExercicios vetores,
  }) {
    final totais = <String, int>{};
    final feitas = <String, int>{};
    final amostras = <(String, double)>[];
    for (final sessao in sessoes) {
      final plan = <String, int>{};
      final conc = <String, int>{};
      for (final s in sessao.series) {
        final id = s.catalogoId;
        if (id == null || !catalogo.containsKey(id)) continue;
        plan[id] = (plan[id] ?? 0) + 1;
        if (s.concluida) conc[id] = (conc[id] ?? 0) + 1;
      }
      plan.forEach((id, p) {
        amostras.add((id, (conc[id] ?? 0) / p));
        totais[id] = (totais[id] ?? 0) + p;
        feitas[id] = (feitas[id] ?? 0) + (conc[id] ?? 0);
      });
    }
    final taxas = {
      for (final e in totais.entries) e.key: feitas[e.key]! / e.value,
    };

    final pesos = <String, double>{};
    var vies = log(_prior / (1 - _prior));
    if (amostras.length >= minimoAmostras && sessoes.length >= minimoSessoes) {
      final entradas = [
        for (final a in amostras)
          (_caracteristicas(catalogo[a.$1]!, vetores, taxas), a.$2),
      ];
      const epocas = 60;
      const regularizacao = 0.02;
      for (var epoca = 0; epoca < epocas; epoca++) {
        final taxa = 0.3 / (1 + epoca * 0.1);
        for (final (f, y) in entradas) {
          var z = vies;
          f.forEach((k, x) => z += (pesos[k] ?? 0) * x);
          final erro = _sigmoide(z) - y;
          vies -= taxa * erro;
          f.forEach((k, x) {
            final w = pesos[k] ?? 0;
            pesos[k] = w - taxa * (erro * x + regularizacao * w);
          });
        }
      }
    }
    final valido =
        amostras.length >= minimoAmostras && sessoes.length >= minimoSessoes;
    return ModeloConclusao._(
      pesos,
      vies,
      vetores,
      taxas,
      valido ? amostras.length : 0,
    );
  }

  /// Chance prevista de concluir o exercício (0 a 1), ou nula sem treino.
  double? prever(ExercicioBanco ex) {
    if (!treinado) return null;
    final f = _caracteristicas(ex, _vetores, _taxaPorId);
    var z = _vies;
    f.forEach((k, x) => z += (_pesos[k] ?? 0) * x);
    return _sigmoide(z);
  }
}
