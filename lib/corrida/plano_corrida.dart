enum TipoBlocoCorrida { aquecimento, corrida, caminhada, desaquecimento }

extension TipoBlocoCorridaTexto on TipoBlocoCorrida {
  String get rotulo => switch (this) {
    TipoBlocoCorrida.aquecimento => 'Aquecimento',
    TipoBlocoCorrida.corrida => 'Corrida',
    TipoBlocoCorrida.caminhada => 'Caminhada',
    TipoBlocoCorrida.desaquecimento => 'Desaquecimento',
  };

  String get orientacao => switch (this) {
    TipoBlocoCorrida.aquecimento =>
      'Caminhe em passo firme para elevar a frequência cardíaca aos poucos.',
    TipoBlocoCorrida.corrida =>
      'Corra em ritmo confortável: você deve conseguir falar frases curtas.',
    TipoBlocoCorrida.caminhada =>
      'Caminhe para recuperar o fôlego, sem parar de se mover.',
    TipoBlocoCorrida.desaquecimento =>
      'Caminhe devagar até a respiração e os batimentos baixarem.',
  };
}

class BlocoCorrida {
  const BlocoCorrida(this.tipo, this.segundos);

  final TipoBlocoCorrida tipo;
  final int segundos;
}

/// Onde o cliente está dentro do plano, a partir do tempo decorrido.
class PosicaoPlanoCorrida {
  const PosicaoPlanoCorrida({
    required this.indice,
    required this.bloco,
    required this.restanteNoBloco,
    required this.restanteTotal,
    required this.concluido,
  });

  final int indice;
  final BlocoCorrida bloco;
  final int restanteNoBloco;
  final int restanteTotal;
  final bool concluido;
}

/// Plano de corrida por tempo (intervalos corrida/caminhada). É uma
/// estrutura geral e conservadora, não uma prescrição individual: não avalia
/// condição de saúde e não define ritmo, apenas esforço percebido.
class PlanoCorrida {
  const PlanoCorrida(this.blocos);

  final List<BlocoCorrida> blocos;

  int get duracaoTotal => blocos.fold(0, (t, b) => t + b.segundos);

  static const int _aquecimento = 300;
  static const int _desaquecimento = 300;

  /// [semanaCiclo] (1 a 4) só altera o nível iniciante: a proporção de
  /// corrida sobe a cada semana. Fora de um ciclo, usa a semana 1.
  static PlanoCorrida gerar({
    required String experiencia,
    required int minutos,
    int? semanaCiclo,
  }) {
    final total = minutos.clamp(15, 90) * 60;
    final principal = total - _aquecimento - _desaquecimento;
    final nivel = _normalizar(experiencia);

    final (corrida, caminhada) = switch (nivel) {
      'avancado' => (600, 60),
      'intermediario' => (300, 60),
      _ => switch ((semanaCiclo ?? 1).clamp(1, 4)) {
        1 => (60, 120),
        2 => (120, 120),
        3 => (180, 90),
        _ => (240, 60),
      },
    };

    final blocos = <BlocoCorrida>[
      const BlocoCorrida(TipoBlocoCorrida.aquecimento, _aquecimento),
    ];
    var restante = principal;
    var correr = true;
    while (restante > 0) {
      final tipo = correr
          ? TipoBlocoCorrida.corrida
          : TipoBlocoCorrida.caminhada;
      final duracao = (correr ? corrida : caminhada).clamp(1, restante);
      // Evita um bloco final de corrida curto demais: soma ao anterior.
      if (restante - duracao > 0 && restante - duracao < 30) {
        blocos.add(BlocoCorrida(tipo, restante));
        restante = 0;
      } else {
        blocos.add(BlocoCorrida(tipo, duracao));
        restante -= duracao;
      }
      correr = !correr;
    }
    blocos.add(
      const BlocoCorrida(TipoBlocoCorrida.desaquecimento, _desaquecimento),
    );
    return PlanoCorrida(blocos);
  }

  static String _normalizar(String texto) => texto
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ç', 'c')
      .trim();

  PosicaoPlanoCorrida posicao(int segundosDecorridos) {
    final decorrido = segundosDecorridos < 0 ? 0 : segundosDecorridos;
    var acumulado = 0;
    for (var i = 0; i < blocos.length; i++) {
      final fim = acumulado + blocos[i].segundos;
      if (decorrido < fim) {
        return PosicaoPlanoCorrida(
          indice: i,
          bloco: blocos[i],
          restanteNoBloco: fim - decorrido,
          restanteTotal: duracaoTotal - decorrido,
          concluido: false,
        );
      }
      acumulado = fim;
    }
    return PosicaoPlanoCorrida(
      indice: blocos.length - 1,
      bloco: blocos.last,
      restanteNoBloco: 0,
      restanteTotal: 0,
      concluido: true,
    );
  }

  BlocoCorrida? proximoBloco(int indiceAtual) =>
      indiceAtual + 1 < blocos.length ? blocos[indiceAtual + 1] : null;
}
