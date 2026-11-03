import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/workfit/workfit_aprendizado.dart';
import 'package:workholy_mobile/workfit/workfit_modelo.dart';
import 'package:workholy_mobile/workfit/workfit_motor.dart';

ExercicioBanco ex(
  String id,
  String nome,
  String grupo,
  String equip, [
  List<String> instrucoes = const [],
]) => ExercicioBanco(
  id: id,
  nome: nome,
  grupo: grupo,
  equipamento: equip,
  instrucoes: instrucoes,
);

void main() {
  final catalogo = [
    ex('a1', 'Agachamento com halteres', 'Pernas', 'halteres', [
      'Agache mantendo a coluna reta',
    ]),
    ex('a2', 'Agachamento goblet com halteres', 'Pernas', 'halteres', [
      'Agache segurando o halter junto ao peito',
    ]),
    ex('b1', 'Remada curvada com barra', 'Costas', 'barra', [
      'Puxe a barra em direção ao abdômen',
    ]),
    ex('b2', 'Remada alta com barra', 'Costas', 'barra', [
      'Puxe a barra em direção ao queixo',
    ]),
  ];

  test('vetores: exercícios parecidos têm similaridade maior', () {
    final v = VetoresExercicios.construir(catalogo);
    expect(v.similaridade('a1', 'a2'), greaterThan(v.similaridade('a1', 'b1')));
    expect(v.similaridade('a1', 'a1'), closeTo(1, 1e-9));
    expect(v.similaridade('a1', 'x'), 0);
  });

  test('modelo não treina com poucos dados', () {
    final m = ModeloConclusao.treinar(
      sessoes: const [],
      catalogo: {for (final e in catalogo) e.id: e},
      vetores: VetoresExercicios.construir(catalogo),
    );
    expect(m.treinado, isFalse);
    expect(m.prever(catalogo.first), isNull);
  });

  test('modelo generaliza por semelhança e é determinístico', () {
    final agora = DateTime(2025, 6, 30);
    final sessoes = [
      for (var i = 0; i < 12; i++)
        SessaoAprendizado(
          fim: agora.subtract(Duration(days: i * 3)),
          series: [
            for (var s = 0; s < 3; s++)
              SerieAprendizado(catalogoId: 'a1', nome: 'a1', concluida: true),
            for (var s = 0; s < 3; s++)
              SerieAprendizado(catalogoId: 'b1', nome: 'b1', concluida: false),
          ],
        ),
    ];
    // a2 e b2 nunca foram feitos pelo cliente.
    AprendizadoWorkFit montar() => AprendizadoWorkFit.construir(
      sessoes: sessoes,
      agora: agora,
      catalogo: catalogo,
    );
    final a = montar();
    expect(a.usaModelo, isTrue);
    expect(a.somenteModelo(catalogo[1]), isTrue);
    expect(a.bonusPara(catalogo[1]), greaterThan(a.bonusPara(catalogo[3])));
    expect(a.bonusPara(catalogo[1]), montar().bonusPara(catalogo[1]));
  });

  test('sem catálogo o comportamento é o das regras', () {
    final a = AprendizadoWorkFit.construir(sessoes: const []);
    expect(a.usaModelo, isFalse);
    expect(a.bonusPara(catalogo.first), 0);
  });
}
