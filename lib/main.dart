import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'dados/workholy_banco.dart';
import 'perfil_praticante_page.dart';
import 'aparencia/workholy_aparencia.dart';
import 'aparencia/aparencia_page.dart';
import 'preferencias/preferencias_treino_page.dart';
import 'tutorial_primeiro_acesso_page.dart';
import 'exercicios/biblioteca_exercicios.dart';
import 'corrida/corrida_banco.dart';
import 'corrida/corrida_page.dart';
import 'assinatura/assinatura_workholy.dart';
import 'assinatura/plano_premium_page.dart';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'tela_boas_vindas_page.dart';
import 'firebase_options.dart';
import 'autenticacao/autenticacao_page.dart';

const Color verde = Color(0xFFB7F34A);
const Color fundo = Color(0xFF10120F);
const Color superficie = Color(0xFF1B1E19);
const Color textoSecundario = Color(0xFFA4AAA0);

int _contadorIds = 0;

String novoId(String prefixo) {
  _contadorIds++;
  return '$prefixo-${DateTime.now().microsecondsSinceEpoch}-$_contadorIds';
}

// ============================================================
// MODELOS
// ============================================================

class Treino {
  final String id;
  final String nome;
  final String objetivo;

  // Campo mantido para compatibilidade com os dados antigos.
  final int exercicios;

  Treino({
    String? id,
    required this.nome,
    required this.objetivo,
    this.exercicios = 0,
  }) : id = id ?? novoId('treino');

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'objetivo': objetivo,
    'exercicios': exercicios,
  };

  factory Treino.fromJson(Map<String, dynamic> json) {
    return Treino(
      id: json['id'] is String ? json['id'] as String : null,
      nome: json['nome']?.toString() ?? 'Treino sem nome',
      objetivo: json['objetivo']?.toString() ?? '',
      exercicios: (json['exercicios'] as num?)?.toInt() ?? 0,
    );
  }
}

class Exercicio {
  final String id;
  final String nome;
  final String grupo;
  final int series;
  final int repeticoes;

  Exercicio({
    String? id,
    required this.nome,
    required this.grupo,
    required this.series,
    required this.repeticoes,
  }) : id = id ?? novoId('exercicio');

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'grupo': grupo,
    'series': series,
    'repeticoes': repeticoes,
  };

  factory Exercicio.fromJson(Map<String, dynamic> json) {
    return Exercicio(
      id: json['id'] is String ? json['id'] as String : null,
      nome: json['nome']?.toString() ?? 'Exercício sem nome',
      grupo: json['grupo']?.toString() ?? 'Outros',
      series: (json['series'] as num?)?.toInt() ?? 3,
      repeticoes: (json['repeticoes'] as num?)?.toInt() ?? 12,
    );
  }
}

/// Representa um exercício associado a um treino específico.
/// A configuração é independente da configuração do cadastro geral.
class ItemTreino {
  final String id;
  final String treinoId;
  final String exercicioId;
  final int series;
  final int repeticoes;
  final double cargaKg;
  final int descansoSegundos;

  ItemTreino({
    String? id,
    required this.treinoId,
    required this.exercicioId,
    required this.series,
    required this.repeticoes,
    required this.cargaKg,
    required this.descansoSegundos,
  }) : id = id ?? novoId('item');

  Map<String, dynamic> toJson() => {
    'id': id,
    'treinoId': treinoId,
    'exercicioId': exercicioId,
    'series': series,
    'repeticoes': repeticoes,
    'cargaKg': cargaKg,
    'descansoSegundos': descansoSegundos,
  };

  factory ItemTreino.fromJson(Map<String, dynamic> json) {
    return ItemTreino(
      id: json['id'] is String ? json['id'] as String : null,
      treinoId: json['treinoId']?.toString() ?? '',
      exercicioId: json['exercicioId']?.toString() ?? '',
      series: (json['series'] as num?)?.toInt() ?? 3,
      repeticoes: (json['repeticoes'] as num?)?.toInt() ?? 12,
      cargaKg: (json['cargaKg'] as num?)?.toDouble() ?? 0,
      descansoSegundos: (json['descansoSegundos'] as num?)?.toInt() ?? 90,
    );
  }
}

class SerieExecutada {
  final String id;
  final String exercicioId;
  final String nomeExercicio;
  final int numeroSerie;
  final int repeticoesPlanejadas;
  final int repeticoesRealizadas;
  final double cargaKg;
  final bool concluida;
  final int descansoSegundos;

  const SerieExecutada({
    required this.id,
    required this.exercicioId,
    required this.nomeExercicio,
    required this.numeroSerie,
    required this.repeticoesPlanejadas,
    required this.repeticoesRealizadas,
    required this.cargaKg,
    required this.concluida,
    required this.descansoSegundos,
  });

  SerieExecutada copiar({
    int? repeticoesRealizadas,
    double? cargaKg,
    bool? concluida,
  }) {
    return SerieExecutada(
      id: id,
      exercicioId: exercicioId,
      nomeExercicio: nomeExercicio,
      numeroSerie: numeroSerie,
      repeticoesPlanejadas: repeticoesPlanejadas,
      repeticoesRealizadas: repeticoesRealizadas ?? this.repeticoesRealizadas,
      cargaKg: cargaKg ?? this.cargaKg,
      concluida: concluida ?? this.concluida,
      descansoSegundos: descansoSegundos,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'exercicioId': exercicioId,
    'nomeExercicio': nomeExercicio,
    'numeroSerie': numeroSerie,
    'repeticoesPlanejadas': repeticoesPlanejadas,
    'repeticoesRealizadas': repeticoesRealizadas,
    'cargaKg': cargaKg,
    'concluida': concluida,
    'descansoSegundos': descansoSegundos,
  };

  factory SerieExecutada.fromJson(Map<String, dynamic> json) {
    return SerieExecutada(
      id: json['id']?.toString() ?? novoId('serie'),
      exercicioId: json['exercicioId']?.toString() ?? '',
      nomeExercicio: json['nomeExercicio']?.toString() ?? 'Exercício',
      numeroSerie: (json['numeroSerie'] as num?)?.toInt() ?? 1,
      repeticoesPlanejadas:
          (json['repeticoesPlanejadas'] as num?)?.toInt() ?? 0,
      repeticoesRealizadas:
          (json['repeticoesRealizadas'] as num?)?.toInt() ?? 0,
      cargaKg: (json['cargaKg'] as num?)?.toDouble() ?? 0,
      concluida: json['concluida'] == true,
      descansoSegundos: (json['descansoSegundos'] as num?)?.toInt() ?? 90,
    );
  }
}

class SessaoTreino {
  final String id;
  final String treinoId;
  final String nomeTreino;
  final DateTime inicio;
  final DateTime? fim;
  final List<SerieExecutada> series;

  const SessaoTreino({
    required this.id,
    required this.treinoId,
    required this.nomeTreino,
    required this.inicio,
    required this.fim,
    required this.series,
  });

  bool get finalizada => fim != null;

  int get seriesConcluidas => series.where((serie) => serie.concluida).length;

  SessaoTreino copiar({
    DateTime? fim,
    bool limparFim = false,
    List<SerieExecutada>? series,
  }) {
    return SessaoTreino(
      id: id,
      treinoId: treinoId,
      nomeTreino: nomeTreino,
      inicio: inicio,
      fim: limparFim ? null : (fim ?? this.fim),
      series: series ?? List<SerieExecutada>.from(this.series),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'treinoId': treinoId,
    'nomeTreino': nomeTreino,
    'inicio': inicio.toIso8601String(),
    'fim': fim?.toIso8601String(),
    'series': series.map((serie) => serie.toJson()).toList(),
  };

  factory SessaoTreino.fromJson(Map<String, dynamic> json) {
    final dadosSeries = json['series'] as List<dynamic>? ?? [];

    return SessaoTreino(
      id: json['id']?.toString() ?? novoId('sessao'),
      treinoId: json['treinoId']?.toString() ?? '',
      nomeTreino: json['nomeTreino']?.toString() ?? 'Treino',
      inicio:
          DateTime.tryParse(json['inicio']?.toString() ?? '') ?? DateTime.now(),
      fim: DateTime.tryParse(json['fim']?.toString() ?? ''),
      series: dadosSeries
          .map(
            (item) =>
                SerieExecutada.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
    );
  }
}

enum _TipoAtividadePainel { musculacao, corrida }

/// Representa uma atividade finalizada que deve aparecer consolidada no
/// painel. A corrida continua no próprio banco e histórico, mas participa dos
/// indicadores sem ser duplicada como uma sessão de musculação.
class _AtividadePainel {
  const _AtividadePainel({
    required this.tipo,
    required this.inicio,
    required this.duracaoSegundos,
    required this.titulo,
    this.seriesConcluidas = 0,
    this.distanciaMetros,
  });

  final _TipoAtividadePainel tipo;
  final DateTime inicio;
  final int duracaoSegundos;
  final String titulo;
  final int seriesConcluidas;
  final double? distanciaMetros;
}

class _DestinoNavegacao {
  const _DestinoNavegacao({
    required this.rotulo,
    required this.icone,
    required this.iconeSelecionado,
  });

  final String rotulo;
  final IconData icone;
  final IconData iconeSelecionado;
}

// ============================================================
// APLICATIVO
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FlutterForegroundTask.initCommunicationPort();

  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'workholy_corrida',
      channelName: 'Corrida WorkHoly',
      channelDescription:
          'Notificação exibida enquanto o GPS da corrida está ativo.',
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(1000),
      allowWakeLock: true,
      allowWifiLock: false,
    ),
  );

  runApp(const WorkHolyApp());
}

class WorkHolyApp extends StatefulWidget {
  const WorkHolyApp({super.key});

  @override
  State<WorkHolyApp> createState() => _WorkHolyAppState();
}

class _WorkHolyAppState extends State<WorkHolyApp> {
  late final WorkHolyAparencia aparencia;

  @override
  void initState() {
    super.initState();
    aparencia = WorkHolyAparencia();
    aparencia.carregar();
  }

  @override
  void dispose() {
    aparencia.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: aparencia,
      builder: (context, _) {
        final modo = aparencia.modo;

        return MaterialApp(
          title: 'WorkHoly Mobile',
          debugShowCheckedModeBanner: false,
          theme: aparencia.criarTema(Brightness.light),
          darkTheme: aparencia.criarTema(Brightness.dark),
          themeMode: switch (modo) {
            ModoAparencia.escuro => ThemeMode.dark,
            ModoAparencia.claro => ThemeMode.light,
            ModoAparencia.automatico => ThemeMode.system,
          },
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.userChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final usuario = snapshot.data;
              debugPrint("Diagnóstico de Autenticação");
              debugPrint('Estado do stream: ${snapshot.connectionState}');
              debugPrint('Existe usuário: ${usuario != null}');
              debugPrint('Email verificado: ${usuario?.emailVerified}');
              debugPrint('Email: ${usuario?.email ?? "(nenhum)"}');

              if (usuario == null) return const AutenticacaoPage();
              if (!usuario.emailVerified) return const ConfirmarEmailPage();
              return WorkHolyHome(aparencia: aparencia);
            },
          ),
        );
      },
    );
  }
}

class WorkHolyHome extends StatefulWidget {
  const WorkHolyHome({super.key, required this.aparencia});

  final WorkHolyAparencia aparencia;
  @override
  State<WorkHolyHome> createState() => _WorkHolyHomeState();
}

class _WorkHolyHomeState extends State<WorkHolyHome> {
  static const String chaveTutorialConcluido =
      'workholy_tutorial_primeiro_acesso_v1';

  static const String chaveBoasVindasConcluida =
      'workholy_boas_vindas_concluida_v1';

  bool _verificacaoTutorialIniciada = false;

  List<SessaoTreino> sessoesTreino = [];
  List<CorridaConcluida> corridasFinalizadas = [];

  int _ultimaLeituraCorridas = 0;

  int abaSelecionada = 0;
  bool carregando = true;

  List<Treino> treinos = [];

  List<Exercicio> exercicios = [];

  List<ItemTreino> itensTreino = [];

  final TextEditingController _buscaExerciciosController =
      TextEditingController();
  String _termoBuscaExercicios = '';
  final Set<String> _idsExerciciosSelecionados = <String>{};

  // O histórico de sessões será desenvolvido na próxima etapa.
  final List<String> historico = [];

  @override
  void initState() {
    super.initState();
    carregarDados();
    unawaited(carregarCorridasDoPainel());
  }

  @override
  void dispose() {
    _buscaExerciciosController.dispose();
    super.dispose();
  }

  Future<void> carregarCorridasDoPainel() async {
    final leitura = ++_ultimaLeituraCorridas;

    try {
      final corridas = await CorridaBanco.instancia.listarFinalizadas();

      if (!mounted || leitura != _ultimaLeituraCorridas) return;

      setState(() => corridasFinalizadas = corridas);
    } catch (erro) {
      debugPrint('Erro ao carregar corridas no painel: $erro');
    }
  }

  Future<void> verificarTutorialPrimeiroAcesso() async {
    if (_verificacaoTutorialIniciada || !mounted) return;

    _verificacaoTutorialIniciada = true;

    try {
      final banco = WorkHolyBanco.instancia;

      if (!mounted) return;

      // Primeira etapa: tela de boas-vindas.
      if (await banco.lerBooleano(chaveBoasVindasConcluida) != true) {
        if (!mounted) return;

        final resultadoBoasVindas = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (paginaContext) => TelaBoasVindasPage(
              onComecar: () {
                Navigator.of(paginaContext).pop(true);
              },
            ),
          ),
        );

        if (!mounted || resultadoBoasVindas != true) return;

        await banco.salvarBooleano(chaveBoasVindasConcluida, true);
      }

      if (!mounted) return;

      // Segunda etapa: tutorial, caso ainda não tenha sido concluído.
      if (await banco.lerBooleano(chaveTutorialConcluido) == true) return;
      if (!mounted) return;

      final resultadoTutorial = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => const TutorialPrimeiroAcessoPage(),
        ),
      );

      if (resultadoTutorial == true) {
        await banco.salvarBooleano(chaveTutorialConcluido, true);
      }
    } catch (erro) {
      debugPrint('Erro na apresentação inicial do WorkHoly: $erro');
    }
  }

  Future<void> carregarDados() async {
    try {
      final dados = await WorkHolyBanco.instancia.carregarDadosTreino();

      // A leitura é concluída antes de alterar o estado da tela.
      final treinosCarregados = dados.treinos.map(Treino.fromJson).toList();
      final exerciciosCarregados = dados.exercicios
          .map(Exercicio.fromJson)
          .toList();
      final itensCarregados = dados.itensTreino
          .map(ItemTreino.fromJson)
          .toList();
      final sessoesCarregadas = dados.sessoesTreino
          .map(SessaoTreino.fromJson)
          .toList();

      // Aplica as listas somente após todas as leituras concluírem.
      treinos = treinosCarregados;
      exercicios = exerciciosCarregados;
      itensTreino = itensCarregados;
      sessoesTreino = sessoesCarregadas;

      // Remove associações que apontem para registros inexistentes.
      final idsTreinos = treinos.map((t) => t.id).toSet();
      final idsExercicios = exercicios.map((e) => e.id).toSet();

      itensTreino.removeWhere(
        (item) =>
            !idsTreinos.contains(item.treinoId) ||
            !idsExercicios.contains(item.exercicioId),
      );
    } catch (erro, stackTrace) {
      debugPrint('Erro ao carregar dados do WorkHoly: $erro');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível carregar os dados salvos. '
              'Evite salvar alterações até verificar os dados.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => carregando = false);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            verificarTutorialPrimeiroAcesso();
          }
        });
      }
    }
  }

  Future<void> salvarDados() async {
    try {
      await WorkHolyBanco.instancia.salvarDadosTreino(
        treinos: treinos.map((treino) => treino.toJson()).toList(),
        exercicios: exercicios.map((exercicio) => exercicio.toJson()).toList(),
        itensTreino: itensTreino.map((item) => item.toJson()).toList(),
        sessoesTreino: sessoesTreino.map((sessao) => sessao.toJson()).toList(),
      );
    } catch (erro) {
      debugPrint('Erro ao salvar dados do WorkHoly: $erro');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao salvar os dados no aparelho.')),
        );
      }
    }
  }

  int quantidadeExercicios(String treinoId) {
    return itensTreino.where((item) => item.treinoId == treinoId).length;
  }

  Future<void> abrirDetalhesTreino(String treinoId) async {
    final indice = treinos.indexWhere((t) => t.id == treinoId);
    if (indice < 0) return;

    final treino = treinos[indice];

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DetalheTreinoPage(
          treino: treino,
          exerciciosDisponiveis: List<Exercicio>.from(exercicios),
          itensIniciais: itensTreino
              .where((item) => item.treinoId == treinoId)
              .toList(),
          onSalvar: (novosItens) => salvarItensDoTreino(treinoId, novosItens),
          onIniciarTreino: () => iniciarSessaoTreino(treinoId),
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  Future<void> iniciarSessaoTreino(String treinoId) async {
    final indiceTreino = treinos.indexWhere((t) => t.id == treinoId);
    if (indiceTreino < 0) return;

    final treino = treinos[indiceTreino];
    final itens = itensTreino
        .where((item) => item.treinoId == treinoId)
        .toList();

    if (itens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adicione exercícios ao treino antes de iniciar.'),
        ),
      );
      return;
    }

    final series = <SerieExecutada>[];

    for (final item in itens) {
      final indice = exercicios.indexWhere((e) => e.id == item.exercicioId);

      final nome = indice >= 0
          ? exercicios[indice].nome
          : 'Exercício indisponível';

      for (var numero = 1; numero <= item.series; numero++) {
        series.add(
          SerieExecutada(
            id: novoId('serie'),
            exercicioId: item.exercicioId,
            nomeExercicio: nome,
            numeroSerie: numero,
            repeticoesPlanejadas: item.repeticoes,
            repeticoesRealizadas: item.repeticoes,
            cargaKg: item.cargaKg,
            descansoSegundos: item.descansoSegundos,
            concluida: false,
          ),
        );
      }
    }

    final sessao = SessaoTreino(
      id: novoId('sessao'),
      treinoId: treino.id,
      nomeTreino: treino.nome,
      inicio: DateTime.now(),
      fim: null,
      series: series,
    );

    setState(() => sessoesTreino.add(sessao));
    await salvarDados();

    if (!mounted) return;

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ExecucaoTreinoPage(sessaoInicial: sessao, onSalvar: salvarSessao),
      ),
    );

    if (mounted) setState(() {});
  }

  Future<void> salvarSessao(SessaoTreino sessao) async {
    final indice = sessoesTreino.indexWhere((s) => s.id == sessao.id);

    if (indice < 0) {
      sessoesTreino.add(sessao);
    } else {
      sessoesTreino[indice] = sessao;
    }

    await salvarDados();

    if (mounted) setState(() {});
  }

  Future<void> limparHistorico() async {
    final quantidade = sessoesTreino.where((s) => s.finalizada).length;

    if (quantidade == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não há treinos concluídos para limpar.')),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Limpar histórico de musculação?'),
        content: Text(
          'Serão removidos $quantidade registro(s) de treinos concluídos. '
          'As sessões em andamento e os treinos cadastrados serão preservados. '
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Limpar histórico'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() {
      sessoesTreino.removeWhere((sessao) => sessao.finalizada);
    });

    await salvarDados();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Histórico de musculação limpo com sucesso.'),
      ),
    );
  }

Future<void> retomarSessaoTreino(SessaoTreino sessao) async {
  if (sessao.finalizada) return;

  await Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => ExecucaoTreinoPage(
        sessaoInicial: sessao,
        onSalvar: salvarSessao,
      ),
    ),
  );

  if (mounted) {
    setState(() {});
  }
}

  Future<void> excluirSessaoDoHistorico(SessaoTreino sessao) async {
    if (!sessao.finalizada) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir treino do histórico?'),
        content: Text(
          'O registro "${sessao.nomeTreino}" será removido do histórico. '
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() {
      sessoesTreino.removeWhere((item) => item.id == sessao.id);
    });
    await salvarDados();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Treino removido do histórico.')),
      );
    }
  }

  Future<void> salvarItensDoTreino(
    String treinoId,
    List<ItemTreino> novosItens,
  ) async {
    itensTreino.removeWhere((item) => item.treinoId == treinoId);
    itensTreino.addAll(novosItens);

    final indice = treinos.indexWhere((t) => t.id == treinoId);
    if (indice >= 0) {
      final antigo = treinos[indice];
      treinos[indice] = Treino(
        id: antigo.id,
        nome: antigo.nome,
        objetivo: antigo.objetivo,
        exercicios: novosItens.length,
      );
    }

    if (mounted) setState(() {});
    await salvarDados();
  }

  Future<void> criarOuEditarTreino([Treino? existente]) async {
    final resultado = await showDialog<Treino>(
      context: context,
      builder: (_) => FormularioTreinoDialog(existente: existente),
    );

    if (resultado == null || !mounted) return;

    setState(() {
      if (existente == null) {
        treinos.add(resultado);
      } else {
        final indice = treinos.indexWhere((t) => t.id == existente.id);

        if (indice >= 0) {
          treinos[indice] = resultado;
        }
      }
    });

    await salvarDados();
  }

  Future<void> excluirTreino(Treino treino) async {
    final confirmar = await confirmarExclusao(
      titulo: 'Excluir treino?',
      mensagem:
          'O treino "${treino.nome}" e os exercícios associados a ele serão removidos.',
    );

    if (confirmar != true || !mounted) return;

    setState(() {
      treinos.removeWhere((t) => t.id == treino.id);
      itensTreino.removeWhere((item) => item.treinoId == treino.id);
    });

    await salvarDados();
  }

  Future<bool> adicionarExercicioPredefinido(
    ExercicioPredefinido predefinido,
  ) async {
    final nomeNormalizado = predefinido.nome.trim().toLowerCase();
    final grupoNormalizado = predefinido.grupo.trim().toLowerCase();

    final jaExiste = exercicios.any(
      (exercicio) =>
          exercicio.nome.trim().toLowerCase() == nomeNormalizado &&
          exercicio.grupo.trim().toLowerCase() == grupoNormalizado,
    );

    if (jaExiste) {
      return false;
    }

    final novoExercicio = Exercicio(
      nome: predefinido.nome,
      grupo: predefinido.grupo,
      series: predefinido.series,
      repeticoes: predefinido.repeticoes,
    );

    setState(() {
      exercicios.add(novoExercicio);
    });

    await salvarDados();

    return true;
  }

  Future<void> criarOuEditarExercicio([Exercicio? existente]) async {
    final resultado = await showDialog<Exercicio>(
      context: context,
      builder: (_) => FormularioExercicioDialog(existente: existente),
    );

    if (resultado == null || !mounted) return;

    setState(() {
      if (existente == null) {
        exercicios.add(resultado);
      } else {
        final indice = exercicios.indexWhere((e) => e.id == existente.id);

        if (indice >= 0) {
          exercicios[indice] = resultado;
        }
      }
    });

    await salvarDados();
  }

  Future<void> excluirExercicio(Exercicio exercicio) async {
    await excluirExerciciosPorIds({exercicio.id});
  }

  Future<void> excluirExerciciosSelecionados() async {
    await excluirExerciciosPorIds(Set<String>.from(_idsExerciciosSelecionados));
  }

  Future<void> excluirExerciciosPorIds(Set<String> ids) async {
    final selecionados = exercicios.where((exercicio) {
      return ids.contains(exercicio.id);
    }).toList();

    if (selecionados.isEmpty) return;

    final idsValidos = selecionados.map((exercicio) => exercicio.id).toSet();
    final associacoesRemovidas = itensTreino
        .where((item) => idsValidos.contains(item.exercicioId))
        .length;

    final quantidade = selecionados.length;
    final mensagem = quantidade == 1
        ? 'O exercício "${selecionados.single.nome}" também será retirado de '
              '$associacoesRemovidas associação(ões) em treinos. Esta ação não '
              'pode ser desfeita.'
        : '$quantidade exercícios serão removidos, junto com '
              '$associacoesRemovidas associação(ões) em treinos. Esta ação não '
              'pode ser desfeita.';

    final confirmar = await confirmarExclusao(
      titulo: quantidade == 1
          ? 'Excluir exercício?'
          : 'Excluir $quantidade exercícios?',
      mensagem: mensagem,
    );

    if (confirmar != true || !mounted) return;

    setState(() {
      exercicios.removeWhere((exercicio) => idsValidos.contains(exercicio.id));
      itensTreino.removeWhere((item) => idsValidos.contains(item.exercicioId));
      _idsExerciciosSelecionados.removeAll(idsValidos);
    });

    await salvarDados();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            quantidade == 1
                ? 'Exercício excluído com sucesso.'
                : '$quantidade exercícios excluídos com sucesso.',
          ),
        ),
      );
    }
  }

  List<Exercicio> get exerciciosFiltrados {
    final termo = _termoBuscaExercicios.trim().toLowerCase();
    if (termo.isEmpty) return List<Exercicio>.from(exercicios);

    return exercicios.where((exercicio) {
      final texto = '${exercicio.nome} ${exercicio.grupo}'.toLowerCase();
      return texto.contains(termo);
    }).toList();
  }

  bool get emModoSelecaoExercicios => _idsExerciciosSelecionados.isNotEmpty;

  void alternarSelecaoExercicio(Exercicio exercicio) {
    setState(() {
      if (!_idsExerciciosSelecionados.add(exercicio.id)) {
        _idsExerciciosSelecionados.remove(exercicio.id);
      }
    });
  }

  void selecionarTodosExerciciosFiltrados(List<Exercicio> filtrados) {
    final idsFiltrados = filtrados.map((exercicio) => exercicio.id).toSet();
    final todosSelecionados =
        idsFiltrados.isNotEmpty &&
        idsFiltrados.every(_idsExerciciosSelecionados.contains);

    setState(() {
      if (todosSelecionados) {
        _idsExerciciosSelecionados.removeAll(idsFiltrados);
      } else {
        _idsExerciciosSelecionados.addAll(idsFiltrados);
      }
    });
  }

  void cancelarSelecaoExercicios() {
    setState(_idsExerciciosSelecionados.clear);
  }

  Future<bool?> confirmarExclusao({
    required String titulo,
    required String mensagem,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(titulo),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void selecionarAba(int indice) {
    if (indice != abaSelecionada) {
      setState(() => abaSelecionada = indice);
    }

    if (indice == 0) {
      unawaited(carregarCorridasDoPainel());
    }
  }

  Widget construirBarraDeNavegacao() {
    const destinos = [
      _DestinoNavegacao(
        rotulo: 'Painel',
        icone: Icons.dashboard_outlined,
        iconeSelecionado: Icons.dashboard,
      ),
      _DestinoNavegacao(
        rotulo: 'Treinos',
        icone: Icons.view_list_outlined,
        iconeSelecionado: Icons.view_list,
      ),
      _DestinoNavegacao(
        rotulo: 'Exercícios',
        icone: Icons.fitness_center_outlined,
        iconeSelecionado: Icons.fitness_center,
      ),
      _DestinoNavegacao(
        rotulo: 'Corrida',
        icone: Icons.directions_run_outlined,
        iconeSelecionado: Icons.directions_run,
      ),
      _DestinoNavegacao(
        rotulo: 'Histórico',
        icone: Icons.history_outlined,
        iconeSelecionado: Icons.history,
      ),
    ];

    final tema = Theme.of(context);
    final corDestaque = widget.aparencia.corDestaque;

    return Material(
      color: tema.colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            itemCount: destinos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, indice) {
              final destino = destinos[indice];
              final selecionado = indice == abaSelecionada;
              final cor = selecionado
                  ? corDestaque
                  : tema.colorScheme.onSurfaceVariant;

              return Semantics(
                button: true,
                selected: selecionado,
                label: destino.rotulo,
                child: Tooltip(
                  message: destino.rotulo,
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () => selecionarAba(indice),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        constraints: const BoxConstraints(minWidth: 120),
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: selecionado
                              ? corDestaque.withValues(alpha: 0.18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              selecionado
                                  ? destino.iconeSelecionado
                                  : destino.icone,
                              color: cor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              destino.rotulo,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: tema.textTheme.labelLarge?.copyWith(
                                color: cor,
                                fontWeight: selecionado
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final paginas = [
      construirPainel(),
      construirPaginaTreinos(),
      construirPaginaExercicios(),
      CorridaPage(onHistoricoAtualizado: carregarCorridasDoPainel),
      construirPaginaHistorico(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.fitness_center, color: verde),
            SizedBox(width: 10),
            Text('WorkHoly', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ConfiguracoesPage(aparencia: widget.aparencia),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator(color: verde))
          : SafeArea(
              child: IndexedStack(index: abaSelecionada, children: paginas),
            ),
      bottomNavigationBar: construirBarraDeNavegacao(),
    );
  }

  Widget construirPainel() {
    final agora = DateTime.now();
    final sessoesFinalizadas =
        sessoesTreino.where((sessao) => sessao.finalizada).toList()
          ..sort((a, b) => b.inicio.compareTo(a.inicio));

    final atividadesFinalizadas = <_AtividadePainel>[
      ...sessoesFinalizadas.map((sessao) {
        final duracao = sessao.fim!.difference(sessao.inicio).inSeconds;
        return _AtividadePainel(
          tipo: _TipoAtividadePainel.musculacao,
          inicio: sessao.inicio,
          duracaoSegundos: duracao > 0 ? duracao : 0,
          titulo: sessao.nomeTreino,
          seriesConcluidas: sessao.seriesConcluidas,
        );
      }),
      ...corridasFinalizadas.map(
        (corrida) => _AtividadePainel(
          tipo: _TipoAtividadePainel.corrida,
          inicio: corrida.inicio,
          duracaoSegundos: corrida.duracaoSegundos,
          titulo: 'Corrida',
          distanciaMetros: corrida.distanciaMetros,
        ),
      ),
    ]..sort((a, b) => b.inicio.compareTo(a.inicio));

    final inicioSemana = DateTime(
      agora.year,
      agora.month,
      agora.day,
    ).subtract(Duration(days: agora.weekday - 1));

    final atividadesSemana = atividadesFinalizadas.where((atividade) {
      return !atividade.inicio.isBefore(inicioSemana) &&
          atividade.inicio.isBefore(inicioSemana.add(const Duration(days: 7)));
    }).toList();

    final duracaoTotal = atividadesFinalizadas.fold<int>(
      0,
      (total, atividade) => total + atividade.duracaoSegundos,
    );

    final seriesConcluidas = sessoesFinalizadas.fold<int>(
      0,
      (total, sessao) => total + sessao.seriesConcluidas,
    );

    const dias = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

    final valoresSemana = List<int>.generate(7, (indice) {
      final dia = inicioSemana.add(Duration(days: indice));
      return atividadesFinalizadas.where((atividade) {
        return atividade.inicio.year == dia.year &&
            atividade.inicio.month == dia.month &&
            atividade.inicio.day == dia.day;
      }).length;
    });

    const meses = [
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];

    final valoresMeses = List<int>.generate(6, (indice) {
      final mes = DateTime(agora.year, agora.month - 5 + indice, 1);
      return atividadesFinalizadas.where((atividade) {
        return atividade.inicio.year == mes.year &&
            atividade.inicio.month == mes.month;
      }).length;
    });

    final rotulosMeses = List<String>.generate(6, (indice) {
      final mes = DateTime(agora.year, agora.month - 5 + indice, 1);
      return meses[mes.month - 1];
    });

    final ultimaAtividade = atividadesFinalizadas.isEmpty
        ? null
        : atividadesFinalizadas.first;

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Seu progresso',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Acompanhe sua rotina e sua evolução.',
          style: TextStyle(color: textoSecundario),
        ),
        const SizedBox(height: 20),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            cartaoResumo(
              'Treinos cadastrados',
              '${treinos.length}',
              Icons.fitness_center,
            ),
            cartaoResumo(
              'Exercícios',
              '${exercicios.length}',
              Icons.sports_gymnastics,
            ),
            cartaoResumo(
              'Atividades nesta semana',
              '${atividadesSemana.length}',
              Icons.calendar_month,
            ),
            cartaoResumo(
              'Séries concluídas',
              '$seriesConcluidas',
              Icons.check_circle_outline,
            ),
          ],
        ),

        const SizedBox(height: 24),

        _cartaoGrafico(
          titulo: 'Atividades por dia da semana',
          rotulos: dias,
          valores: valoresSemana,
        ),

        const SizedBox(height: 16),

        _cartaoGrafico(
          titulo: 'Atividades nos últimos 6 meses',
          rotulos: rotulosMeses,
          valores: valoresMeses,
        ),

        const SizedBox(height: 16),

        Card(
          color: superficie,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tempo total de treino',
                  style: TextStyle(color: textoSecundario, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatarDuracao(duracaoTotal),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${atividadesFinalizadas.length} atividades finalizadas',
                  style: const TextStyle(color: textoSecundario),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        Card(
          color: superficie,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Última atividade concluída',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (ultimaAtividade == null)
                  const Text(
                    'Você ainda não concluiu uma atividade. '
                    'Seu histórico aparecerá aqui.',
                    style: TextStyle(color: textoSecundario),
                  )
                else ...[
                  Text(
                    ultimaAtividade.titulo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${ultimaAtividade.inicio.day.toString().padLeft(2, '0')}/'
                    '${ultimaAtividade.inicio.month.toString().padLeft(2, '0')}/'
                    '${ultimaAtividade.inicio.year}',
                    style: const TextStyle(color: textoSecundario),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ultimaAtividade.tipo == _TipoAtividadePainel.corrida
                        ? '${((ultimaAtividade.distanciaMetros ?? 0) / 1000).toStringAsFixed(2).replaceAll('.', ',')} km'
                              ' • ${_formatarDuracao(ultimaAtividade.duracaoSegundos)}'
                        : '${ultimaAtividade.seriesConcluidas} séries concluídas',
                    style: const TextStyle(color: textoSecundario),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        tituloSecao('Meus treinos'),
        const SizedBox(height: 10),

        if (treinos.isEmpty)
          const Text(
            'Nenhum treino cadastrado. Crie seu primeiro treino.',
            style: TextStyle(color: textoSecundario),
          ),

        ...treinos.map((treino) => cartaoTreino(treino)),

        const SizedBox(height: 16),

        OutlinedButton.icon(
          onPressed: () => criarOuEditarTreino(),
          icon: const Icon(Icons.add),
          label: const Text('Criar treino'),
        ),
      ],
    );
  }

  String _formatarDuracao(int segundos) {
    final duracao = Duration(seconds: segundos);
    final horas = duracao.inHours;
    final minutos = duracao.inMinutes.remainder(60);

    if (horas > 0) {
      return '$horas h $minutos min';
    }

    return '${duracao.inMinutes} min';
  }

  Widget _cartaoGrafico({
    required String titulo,
    required List<String> rotulos,
    required List<int> valores,
  }) {
    final maximo = valores.isEmpty
        ? 0
        : valores.reduce((a, b) => a > b ? a : b);

    return Card(
      color: superficie,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 132,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(rotulos.length, (indice) {
                  final valor = valores[indice];
                  final altura = maximo == 0
                      ? 4.0
                      : (valor / maximo * 88).clamp(4.0, 88.0).toDouble();

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '$valor',
                            style: const TextStyle(
                              fontSize: 11,
                              color: textoSecundario,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            height: altura,
                            decoration: BoxDecoration(
                              color: verde.withValues(
                                alpha: valor == 0 ? 0.20 : 0.90,
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            rotulos[indice],
                            style: const TextStyle(
                              fontSize: 10,
                              color: textoSecundario,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            if (maximo == 0) ...[
              const SizedBox(height: 8),
              const Text(
                'Ainda não há sessões concluídas neste período.',
                style: TextStyle(fontSize: 12, color: textoSecundario),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget cartaoResumo(String titulo, String valor, IconData icone) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: superficie,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: verde, size: 24),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            titulo,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: textoSecundario),
          ),
        ],
      ),
    );
  }

  Widget tituloSecao(String titulo) {
    return Text(
      titulo,
      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
    );
  }

  Widget cartaoTreino(Treino treino) {
    final quantidade = quantidadeExercicios(treino.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => abrirDetalhesTreino(treino.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: verde.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.fitness_center, color: verde),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      treino.nome,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      treino.objetivo.isEmpty
                          ? 'Sem objetivo definido'
                          : treino.objetivo,
                      style: const TextStyle(color: textoSecundario),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$quantidade ${quantidade == 1 ? 'exercício associado' : 'exercícios associados'}',
                      style: const TextStyle(color: verde, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Editar treino',
                onPressed: () => criarOuEditarTreino(treino),
                icon: const Icon(Icons.edit_outlined),
              ),
              PopupMenuButton<String>(
                onSelected: (opcao) {
                  if (opcao == 'excluir') excluirTreino(treino);
                  if (opcao == 'abrir') abrirDetalhesTreino(treino.id);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'abrir', child: Text('Montar treino')),
                  PopupMenuItem(
                    value: 'excluir',
                    child: Text('Excluir treino'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget construirPaginaTreinos() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Meus treinos',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton.filled(
              onPressed: () => criarOuEditarTreino(),
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                backgroundColor: verde,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (treinos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Text(
              'Você ainda não cadastrou treinos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textoSecundario),
            ),
          ),
        ...treinos.map((treino) => cartaoTreino(treino)),
      ],
    );
  }

  Widget construirPaginaExercicios() {
    final filtrados = exerciciosFiltrados;
    final todosResultadosSelecionados =
        filtrados.isNotEmpty &&
        filtrados.every(
          (exercicio) => _idsExerciciosSelecionados.contains(exercicio.id),
        );

    return ListView.builder(
      padding: const EdgeInsets.all(18),
      itemCount: 1 + (filtrados.isEmpty ? 1 : filtrados.length),
      itemBuilder: (context, indice) {
        if (indice == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      emModoSelecaoExercicios
                          ? '${_idsExerciciosSelecionados.length} selecionado(s)'
                          : 'Exercícios',
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (emModoSelecaoExercicios) ...[
                    IconButton(
                      tooltip: todosResultadosSelecionados
                          ? 'Desmarcar resultados da busca'
                          : 'Selecionar todos os resultados da busca',
                      onPressed: filtrados.isEmpty
                          ? null
                          : () => selecionarTodosExerciciosFiltrados(filtrados),
                      icon: Icon(
                        todosResultadosSelecionados
                            ? Icons.deselect
                            : Icons.select_all,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Excluir selecionados',
                      onPressed: excluirExerciciosSelecionados,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cancelar seleção',
                      onPressed: cancelarSelecaoExercicios,
                      icon: const Icon(Icons.close),
                    ),
                  ] else ...[
                    IconButton(
                      tooltip: 'Biblioteca de exercícios',
                      onPressed: () async {
                        final possuiPremium = await AssinaturaWorkHoly.instancia
                            .possuiPremium();
                        if (!context.mounted) return;
                        if (!possuiPremium) {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PlanoPremiumPage(
                                recurso: 'Biblioteca de exercícios',
                              ),
                            ),
                          );
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BibliotecaExerciciosPage(
                              exerciciosCadastrados: List<Exercicio>.from(
                                exercicios,
                              ),
                              onAdicionar: adicionarExercicioPredefinido,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.library_books_outlined),
                    ),
                    const SizedBox(width: 4),
                    IconButton.filled(
                      tooltip: 'Criar exercício personalizado',
                      onPressed: () => criarOuEditarExercicio(),
                      icon: const Icon(Icons.add),
                      style: IconButton.styleFrom(
                        backgroundColor: verde,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                emModoSelecaoExercicios
                    ? 'Toque nos exercícios para selecionar ou desmarcar.'
                    : 'Cadastre exercícios para utilizá-los na montagem dos treinos.',
                style: const TextStyle(color: textoSecundario),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _buscaExerciciosController,
                onChanged: (texto) {
                  setState(() => _termoBuscaExercicios = texto);
                },
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Buscar por nome ou grupo',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _termoBuscaExercicios.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpar busca',
                          onPressed: () {
                            _buscaExerciciosController.clear();
                            setState(() => _termoBuscaExercicios = '');
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${filtrados.length} ${filtrados.length == 1 ? 'exercício encontrado' : 'exercícios encontrados'}'
                '${emModoSelecaoExercicios ? ' • toque longo para continuar a seleção' : ' • toque longo para selecionar vários'}',
                style: const TextStyle(color: textoSecundario, fontSize: 12),
              ),
              const SizedBox(height: 10),
            ],
          );
        }

        if (filtrados.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              exercicios.isEmpty
                  ? 'Nenhum exercício cadastrado.'
                  : 'Nenhum exercício encontrado para esta busca.',
              textAlign: TextAlign.center,
            ),
          );
        }

        final exercicio = filtrados[indice - 1];
        final selecionado = _idsExerciciosSelecionados.contains(exercicio.id);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: selecionado ? verde.withValues(alpha: 0.12) : null,
          child: ListTile(
            onTap: emModoSelecaoExercicios
                ? () => alternarSelecaoExercicio(exercicio)
                : null,
            onLongPress: () => alternarSelecaoExercicio(exercicio),
            leading: emModoSelecaoExercicios
                ? Checkbox(
                    value: selecionado,
                    onChanged: (_) => alternarSelecaoExercicio(exercicio),
                  )
                : const CircleAvatar(
                    backgroundColor: superficie,
                    child: Icon(Icons.fitness_center, color: verde),
                  ),
            title: Text(
              exercicio.nome,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${exercicio.grupo} • ${exercicio.series} séries • ${exercicio.repeticoes} repetições',
              style: const TextStyle(color: textoSecundario),
            ),
            trailing: emModoSelecaoExercicios
                ? null
                : PopupMenuButton<String>(
                    onSelected: (opcao) {
                      if (opcao == 'editar') {
                        criarOuEditarExercicio(exercicio);
                      }
                      if (opcao == 'excluir') {
                        excluirExercicio(exercicio);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'editar', child: Text('Editar')),
                      PopupMenuItem(value: 'excluir', child: Text('Excluir')),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget construirPaginaHistorico() {
    final ordenadas = List<SessaoTreino>.from(sessoesTreino)
      ..sort((a, b) => b.inicio.compareTo(a.inicio));

    String dataFormatada(DateTime data) {
      final d = data.toLocal();
      String dois(int n) => n.toString().padLeft(2, '0');
      return '${dois(d.day)}/${dois(d.month)}/${d.year} '
          '${dois(d.hour)}:${dois(d.minute)}';
    }

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Histórico',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
              ),
            ),
            if (sessoesTreino.any((sessao) => sessao.finalizada))
              IconButton(
                tooltip: 'Limpar histórico',
                onPressed: limparHistorico,
                icon: const Icon(
                  Icons.delete_sweep_outlined,
                  color: Colors.redAccent,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (ordenadas.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(22),
              child: Column(
                children: [
                  Icon(Icons.history, size: 44, color: verde),
                  SizedBox(height: 12),
                  Text(
                    'Nenhuma sessão registrada',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Inicie um treino para registrar sua primeira sessão.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textoSecundario),
                  ),
                ],
              ),
            ),
          )
        else
          ...ordenadas.map((sessao) {
            final total = sessao.series.length;
            final feitas = sessao.seriesConcluidas;
            final progresso = total == 0 ? 0.0 : feitas / total;
            final fim = sessao.fim ?? DateTime.now();
            final minutos = fim.difference(sessao.inicio).inMinutes;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sessao.nomeTreino,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!sessao.finalizada)
                          IconButton(
                            tooltip: 'Retomar treino',
                            onPressed: () => retomarSessaoTreino(sessao),
                            icon: const Icon(
                              Icons.play_circle_outline,
                              color: verde,
                            ),
                          ),
                        if (sessao.finalizada &&
                            treinos.any((t) => t.id == sessao.treinoId))
                          IconButton(
                            tooltip: 'Refazer treino',
                            onPressed: () {
                              iniciarSessaoTreino(sessao.treinoId);
                            },
                            icon: const Icon(Icons.replay, color: verde),
                          ),
                        if (sessao.finalizada)
                          IconButton(
                            tooltip: 'Excluir do histórico',
                            onPressed: () => excluirSessaoDoHistorico(sessao),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dataFormatada(sessao.inicio),
                      style: const TextStyle(color: textoSecundario),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${sessao.finalizada ? "Finalizado" : "Em andamento"}'
                      ' • $feitas/$total séries'
                      ' • $minutos min',
                      style: const TextStyle(color: textoSecundario),
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: progresso.clamp(0.0, 1.0),
                      color: verde,
                      backgroundColor: Colors.white12,
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class ConfiguracoesPage extends StatelessWidget {
  const ConfiguracoesPage({super.key, required this.aparencia});

  final WorkHolyAparencia aparencia;

  void mostrarEmBreve(BuildContext context, String recurso) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$recurso estará disponível em uma próxima atualização.'),
      ),
    );
  }

  Future<void> abrirTutorial(BuildContext context) async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const TutorialPrimeiroAcessoPage(),
      ),
    );

    if (resultado == true) {
      await WorkHolyBanco.instancia.salvarBooleano(
        'workholy_tutorial_primeiro_acesso_v1',
        true,
      );
    }
  }

  void mostrarSobre(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SobreWorkHolyPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Personalize sua experiência',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Gerencie as preferências do WorkHoly Mobile.',
            style: TextStyle(color: textoSecundario),
          ),
          const SizedBox(height: 24),

          const Text(
            'PREFERÊNCIAS',
            style: TextStyle(
              color: verde,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline, color: verde),
                  title: const Text('Perfil do treinador'),
                  subtitle: const Text('Nome e informações profissionais'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PerfilPraticantePage(),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.palette_outlined, color: verde),
                  title: const Text('Aparência'),
                  subtitle: const Text('Personalização visual'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AparenciaPage(aparencia: aparencia),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: verde),
                  title: const Text('Preferências de treino'),
                  subtitle: const Text('Opções de execução e descanso'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PreferenciasTreinoPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            'APLICATIVO',
            style: TextStyle(
              color: verde,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.school_outlined, color: verde),
                  title: const Text('Ver tutorial novamente'),
                  subtitle: const Text(
                    'Revise as principais funções do aplicativo',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => abrirTutorial(context),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: verde),
                  title: const Text('Sobre o WorkHoly'),
                  subtitle: const Text('Informações e versão do aplicativo'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => mostrarSobre(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SobreWorkHolyPage extends StatelessWidget {
  const SobreWorkHolyPage({super.key});

  static const String direitosAutorais =
      '© 2026 Murilo da Silva Machado. Todos os direitos reservados.';

  static const String termosDeUso = '''
TERMOS DE USO — WORKHOLY MOBILE

1. FINALIDADE
O WorkHoly é um aplicativo destinado à organização e ao acompanhamento de
treinamentos físicos.

2. PROPRIEDADE INTELECTUAL
O software original e os elementos de autoria própria são protegidos pela
legislação aplicável. Os direitos sobre componentes de terceiros permanecem
sujeitos às respectivas licenças.

3. USO NÃO AUTORIZADO
Não é permitida a reprodução, redistribuição, comercialização ou modificação
não autorizada dos elementos protegidos, salvo quando houver autorização
do titular ou permissão legal.

4. MEDIDAS LEGAIS
Violações poderão resultar nas medidas legais cabíveis, conforme a legislação
aplicável e as circunstâncias do caso.

5. RESPONSABILIDADE
O aplicativo é uma ferramenta de apoio à organização dos treinos e não substitui
a orientação de profissionais de saúde ou de educação física.

6. ATUALIZAÇÕES
Estes termos poderão ser revisados conforme a evolução do aplicativo.
''';

  static const String politicaPrivacidade = '''
POLÍTICA DE PRIVACIDADE — WORKHOLY MOBILE

1. DADOS
O aplicativo pode tratar dados de conta, autenticação e informações inseridas
pelo usuário, conforme os recursos utilizados e os serviços integrados.

2. FINALIDADE
Os dados devem ser utilizados para disponibilizar as funcionalidades do
aplicativo, manter a conta e garantir seu funcionamento e segurança.

3. SERVIÇOS DE TERCEIROS
O aplicativo utiliza serviços integrados, incluindo Firebase. O tratamento
realizado por esses serviços depende da configuração efetiva do projeto e
das políticas aplicáveis.

4. SEGURANÇA
São necessárias medidas técnicas e administrativas adequadas para proteger
os dados contra acessos não autorizados e situações indevidas.

5. DIREITOS DO TITULAR
Os titulares podem exercer os direitos previstos na legislação aplicável,
incluindo a Lei Geral de Proteção de Dados (LGPD), quando pertinente.

6. CONTATO
O canal de contato para solicitações de privacidade deverá ser informado
pelo responsável pelo aplicativo antes da distribuição pública.
''';

  void abrirDocumento(BuildContext context, String titulo, String conteudo) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DocumentoLegalPage(titulo: titulo, conteudo: conteudo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sobre o WorkHoly')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 12),
          const Center(
            child: CircleAvatar(
              radius: 42,
              child: Icon(Icons.fitness_center, size: 42),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'WorkHoly Mobile',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Treinamento, organização e evolução.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DESENVOLVEDOR',
                    style: TextStyle(
                      color: verde,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Murilo da Silva Machado',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text('Versão 1.0.0'),
                  const SizedBox(height: 12),
                  const Text(
                    direitosAutorais,
                    style: TextStyle(color: textoSecundario, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'INFORMAÇÕES LEGAIS',
            style: TextStyle(
              color: verde,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.gavel_outlined),
                  title: const Text('Termos de uso'),
                  subtitle: const Text(
                    'Regras de utilização e propriedade intelectual',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      abrirDocumento(context, 'Termos de uso', termosDeUso),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Política de privacidade'),
                  subtitle: const Text('Dados pessoais, utilização e proteção'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => abrirDocumento(
                    context,
                    'Política de privacidade',
                    politicaPrivacidade,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'O uso e a distribuição do aplicativo estão sujeitos à legislação '
            'aplicável e às licenças dos componentes utilizados.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textoSecundario, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class DocumentoLegalPage extends StatelessWidget {
  const DocumentoLegalPage({
    super.key,
    required this.titulo,
    required this.conteudo,
  });

  final String titulo;
  final String conteudo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: SelectionArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Text(
            conteudo,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7),
          ),
        ),
      ),
    );
  }
}

class FormularioTreinoDialog extends StatefulWidget {
  final Treino? existente;

  const FormularioTreinoDialog({super.key, this.existente});

  @override
  State<FormularioTreinoDialog> createState() => _FormularioTreinoDialogState();
}

class _FormularioTreinoDialogState extends State<FormularioTreinoDialog> {
  late final TextEditingController nomeController;
  late final TextEditingController objetivoController;

  @override
  void initState() {
    super.initState();
    nomeController = TextEditingController(text: widget.existente?.nome ?? '');
    objetivoController = TextEditingController(
      text: widget.existente?.objetivo ?? '',
    );
  }

  @override
  void dispose() {
    nomeController.dispose();
    objetivoController.dispose();
    super.dispose();
  }

  void salvar() {
    final nome = nomeController.text.trim();
    final objetivo = objetivoController.text.trim();

    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome do treino.')),
      );
      return;
    }

    final existente = widget.existente;

    Navigator.of(context).pop(
      Treino(
        id: existente?.id,
        nome: nome,
        objetivo: objetivo,
        exercicios: existente?.exercicios ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existente == null ? 'Criar treino' : 'Editar treino'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nome do treino',
                hintText: 'Ex.: Treino A',
              ),
              onSubmitted: (_) => salvar(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: objetivoController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Objetivo',
                hintText: 'Ex.: Peito e tríceps',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: salvar, child: const Text('Salvar')),
      ],
    );
  }
}

class FormularioExercicioDialog extends StatefulWidget {
  final Exercicio? existente;

  const FormularioExercicioDialog({super.key, this.existente});

  @override
  State<FormularioExercicioDialog> createState() =>
      _FormularioExercicioDialogState();
}

class _FormularioExercicioDialogState extends State<FormularioExercicioDialog> {
  late final TextEditingController nomeController;
  late final TextEditingController grupoController;
  late final TextEditingController seriesController;
  late final TextEditingController repeticoesController;

  @override
  void initState() {
    super.initState();

    final exercicio = widget.existente;

    nomeController = TextEditingController(text: exercicio?.nome ?? '');
    grupoController = TextEditingController(text: exercicio?.grupo ?? '');
    seriesController = TextEditingController(text: '${exercicio?.series ?? 3}');
    repeticoesController = TextEditingController(
      text: '${exercicio?.repeticoes ?? 12}',
    );
  }

  @override
  void dispose() {
    nomeController.dispose();
    grupoController.dispose();
    seriesController.dispose();
    repeticoesController.dispose();
    super.dispose();
  }

  void salvar() {
    final nome = nomeController.text.trim();
    final grupo = grupoController.text.trim();
    final series = int.tryParse(seriesController.text.trim());
    final repeticoes = int.tryParse(repeticoesController.text.trim());

    if (nome.isEmpty ||
        grupo.isEmpty ||
        series == null ||
        repeticoes == null ||
        series < 1 ||
        repeticoes < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Informe o nome, o grupo e valores válidos para séries e repetições.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      Exercicio(
        id: widget.existente?.id,
        nome: nome,
        grupo: grupo,
        series: series,
        repeticoes: repeticoes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existente == null ? 'Cadastrar exercício' : 'Editar exercício',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nome do exercício'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: grupoController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Grupo muscular',
                hintText: 'Ex.: Peito, Costas, Pernas',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: seriesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Séries'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: repeticoesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Repetições'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: salvar, child: const Text('Salvar')),
      ],
    );
  }
}

// ============================================================
// DETALHES E MONTAGEM DO TREINO
// ============================================================

class DetalheTreinoPage extends StatefulWidget {
  final Treino treino;
  final List<Exercicio> exerciciosDisponiveis;
  final List<ItemTreino> itensIniciais;
  final Future<void> Function(List<ItemTreino>) onSalvar;
  final Future<void> Function() onIniciarTreino;

  const DetalheTreinoPage({
    super.key,
    required this.treino,
    required this.exerciciosDisponiveis,
    required this.itensIniciais,
    required this.onSalvar,
    required this.onIniciarTreino,
  });

  @override
  State<DetalheTreinoPage> createState() => _DetalheTreinoPageState();
}

class _DetalheTreinoPageState extends State<DetalheTreinoPage> {
  late List<ItemTreino> itens;
  bool salvando = false;

  static const String _chaveDescanso = 'workholy_pref_treino_descanso_v1';

  int descansoPreferido = 90;

  static const String chaveTutorialConcluido =
      'workholy_tutorial_primeiro_acesso_v1';

  bool _verificacaoTutorialIniciada = false;

  @override
  void initState() {
    super.initState();

    itens = List<ItemTreino>.from(widget.itensIniciais);

    _carregarDescansoPreferido();
  }

  Future<void> verificarTutorialPrimeiroAcesso() async {
    if (_verificacaoTutorialIniciada || !mounted) return;

    _verificacaoTutorialIniciada = true;

    try {
      final banco = WorkHolyBanco.instancia;
      final tutorialConcluido = await banco.lerBooleano(chaveTutorialConcluido);

      if (!mounted || tutorialConcluido == true) {
        return;
      }

      final resultado = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => const TutorialPrimeiroAcessoPage(),
        ),
      );

      if (resultado == true) {
        await banco.salvarBooleano(chaveTutorialConcluido, true);
      }
    } catch (erro) {
      debugPrint('Erro ao abrir o tutorial inicial: $erro');
    }
  }

  Future<void> _carregarDescansoPreferido() async {
    final valor =
        await WorkHolyBanco.instancia.lerInteiro(_chaveDescanso) ?? 90;

    if (!mounted) return;

    setState(() {
      descansoPreferido = valor;
    });
  }

  Exercicio? encontrarExercicio(String id) {
    for (final exercicio in widget.exerciciosDisponiveis) {
      if (exercicio.id == id) return exercicio;
    }
    return null;
  }

  Future<void> persistir() async {
    setState(() => salvando = true);

    try {
      await widget.onSalvar(List<ItemTreino>.from(itens));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Treino salvo com sucesso.')),
      );
    } catch (erro) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar o treino: $erro')));
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  Future<void> adicionarExercicio() async {
    final jaAdicionados = itens.map((item) => item.exercicioId).toSet();

    final disponiveis = widget.exerciciosDisponiveis
        .where((e) => !jaAdicionados.contains(e.id))
        .toList();

    if (disponiveis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.exerciciosDisponiveis.isEmpty
                ? 'Cadastre exercícios na aba Exercícios primeiro.'
                : 'Todos os exercícios cadastrados já estão neste treino.',
          ),
        ),
      );
      return;
    }

    final selecionado = await showDialog<Exercicio>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Adicionar exercício'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: disponiveis.length,
            separatorBuilder: (_, indiceSeparador) => const Divider(height: 1),
            itemBuilder: (_, indice) {
              final exercicio = disponiveis[indice];

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.fitness_center, color: verde),
                title: Text(exercicio.nome),
                subtitle: Text(exercicio.grupo),
                onTap: () => Navigator.pop(dialogContext, exercicio),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (selecionado == null || !mounted) return;

    // Aguarda o fechamento da janela de seleção antes de abrir outra.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    final novoItem = ItemTreino(
      treinoId: widget.treino.id,
      exercicioId: selecionado.id,
      series: selecionado.series,
      repeticoes: selecionado.repeticoes,
      cargaKg: 0,
      descansoSegundos: descansoPreferido,
    );

    final configurado = await abrirConfiguracao(
      item: novoItem,
      nomeExercicio: selecionado.nome,
    );

    if (configurado == null || !mounted) return;

    setState(() => itens.add(configurado));
    await persistir();
  }

  Future<void> editarExercicio(ItemTreino item) async {
    final exercicio = encontrarExercicio(item.exercicioId);
    if (exercicio == null) return;

    final atualizado = await abrirConfiguracao(
      item: item,
      nomeExercicio: exercicio.nome,
    );

    if (atualizado == null || !mounted) return;

    setState(() {
      final indice = itens.indexWhere((i) => i.id == item.id);
      if (indice >= 0) itens[indice] = atualizado;
    });

    await persistir();
  }

  Future<ItemTreino?> abrirConfiguracao({
    required ItemTreino item,
    required String nomeExercicio,
  }) {
    return showDialog<ItemTreino>(
      context: context,
      builder: (_) =>
          ConfiguracaoExercicioDialog(item: item, nomeExercicio: nomeExercicio),
    );
  }

  Future<void> removerExercicio(ItemTreino item) async {
    final exercicio = encontrarExercicio(item.exercicioId);
    final nome = exercicio?.nome ?? 'este exercício';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover do treino?'),
        content: Text('$nome será removido de ${widget.treino.nome}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => itens.removeWhere((i) => i.id == item.id));
    await persistir();
  }

  String formatarCarga(double carga) {
    if (carga == 0) return 'Carga não informada';
    final numero = carga % 1 == 0
        ? carga.toStringAsFixed(0)
        : carga.toStringAsFixed(1);
    return '$numero kg';
  }

  String formatarDescanso(int segundos) {
    if (segundos < 60) return '$segundos s';
    final minutos = segundos ~/ 60;
    final resto = segundos % 60;
    if (resto == 0) return '$minutos min';
    return '$minutos min $resto s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.treino.nome),
        actions: [
          IconButton(
            tooltip: 'Iniciar treino',
            onPressed: salvando || itens.isEmpty
                ? null
                : widget.onIniciarTreino,
            icon: const Icon(Icons.play_arrow),
          ),
          IconButton(
            tooltip: 'Adicionar exercício',
            onPressed: salvando ? null : adicionarExercicio,
            icon: const Icon(Icons.add, color: verde),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: salvando ? null : adicionarExercicio,
        backgroundColor: verde,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar exercício'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: superficie,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.treino.objetivo.isEmpty
                          ? 'Objetivo não definido'
                          : widget.treino.objetivo,
                      style: const TextStyle(
                        color: textoSecundario,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${itens.length} ${itens.length == 1 ? 'exercício configurado' : 'exercícios configurados'}',
                      style: const TextStyle(
                        color: verde,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: itens.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.playlist_add,
                              size: 58,
                              color: verde,
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Seu treino ainda está vazio',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Adicione exercícios cadastrados e configure séries, repetições, carga e descanso.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textoSecundario),
                            ),
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                              onPressed: adicionarExercicio,
                              icon: const Icon(Icons.add),
                              label: const Text('Adicionar exercício'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
                      itemCount: itens.length,
                      separatorBuilder: (_, indiceSeparador) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, indice) {
                        final item = itens[indice];
                        final exercicio = encontrarExercicio(item.exercicioId);

                        return Card(
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => editarExercicio(item),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: verde.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${indice + 1}',
                                        style: const TextStyle(
                                          color: verde,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          exercicio?.nome ??
                                              'Exercício indisponível',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (exercicio != null) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            exercicio.grupo,
                                            style: const TextStyle(
                                              color: textoSecundario,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 10),
                                        Text(
                                          '${item.series} séries × ${item.repeticoes} repetições',
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${formatarCarga(item.cargaKg)} • Descanso: ${formatarDescanso(item.descansoSegundos)}',
                                          style: const TextStyle(
                                            color: textoSecundario,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Toque para editar',
                                          style: TextStyle(
                                            color: verde,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (opcao) {
                                      if (opcao == 'editar') {
                                        editarExercicio(item);
                                      } else if (opcao == 'remover') {
                                        removerExercicio(item);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'editar',
                                        child: Text('Editar configuração'),
                                      ),
                                      PopupMenuItem(
                                        value: 'remover',
                                        child: Text('Remover do treino'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (salvando)
              const LinearProgressIndicator(color: verde, minHeight: 3),
          ],
        ),
      ),
    );
  }
}

class ConfiguracaoExercicioDialog extends StatefulWidget {
  final ItemTreino item;
  final String nomeExercicio;

  const ConfiguracaoExercicioDialog({
    super.key,
    required this.item,
    required this.nomeExercicio,
  });

  @override
  State<ConfiguracaoExercicioDialog> createState() =>
      _ConfiguracaoExercicioDialogState();
}

class _ConfiguracaoExercicioDialogState
    extends State<ConfiguracaoExercicioDialog> {
  late final TextEditingController seriesController;
  late final TextEditingController repeticoesController;
  late final TextEditingController cargaController;
  late final TextEditingController descansoController;

  String? erroValidacao;

  @override
  void initState() {
    super.initState();

    final item = widget.item;

    seriesController = TextEditingController(text: '${item.series}');
    repeticoesController = TextEditingController(text: '${item.repeticoes}');
    cargaController = TextEditingController(
      text: item.cargaKg.toStringAsFixed(item.cargaKg % 1 == 0 ? 0 : 1),
    );
    descansoController = TextEditingController(
      text: '${item.descansoSegundos}',
    );
  }

  @override
  void dispose() {
    seriesController.dispose();
    repeticoesController.dispose();
    cargaController.dispose();
    descansoController.dispose();
    super.dispose();
  }

  void salvar() {
    final series = int.tryParse(seriesController.text.trim());
    final repeticoes = int.tryParse(repeticoesController.text.trim());
    final cargaTexto = cargaController.text.trim().replaceAll(',', '.');
    final carga = double.tryParse(cargaTexto);
    final descanso = int.tryParse(descansoController.text.trim());

    if (series == null ||
        repeticoes == null ||
        carga == null ||
        descanso == null ||
        series < 1 ||
        repeticoes < 1 ||
        !carga.isFinite ||
        carga < 0 ||
        descanso < 0) {
      setState(() {
        erroValidacao = 'Confira os valores. Séries e repetições devem ser maiores que zero; carga e descanso não podem ser negativos.';
      });
      return;
    }

    final item = widget.item;

    Navigator.of(context).pop(
      ItemTreino(
        id: item.id,
        treinoId: item.treinoId,
        exercicioId: item.exercicioId,
        series: series,
        repeticoes: repeticoes,
        cargaKg: carga,
        descansoSegundos: descanso,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configurar exercício'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.nomeExercicio,
              style: const TextStyle(
                color: verde,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: seriesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Séries'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: repeticoesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Repetições'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cargaController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: false,
              ),
              decoration: const InputDecoration(
                labelText: 'Carga (kg)',
                hintText: '0 para peso corporal ou não informado',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descansoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Descanso entre séries (segundos)',
              ),
            ),
            if (erroValidacao != null) ...[
              const SizedBox(height: 10),
              Text(
                erroValidacao!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: salvar, child: const Text('Salvar')),
      ],
    );
  }
}

// ============================================================
// EXECUÇÃO DO TREINO
// ============================================================

class ExecucaoTreinoPage extends StatefulWidget {
  final SessaoTreino sessaoInicial;
  final Future<void> Function(SessaoTreino) onSalvar;

  const ExecucaoTreinoPage({
    super.key,
    required this.sessaoInicial,
    required this.onSalvar,
  });

  @override
  State<ExecucaoTreinoPage> createState() => _ExecucaoTreinoPageState();
}

class _ExecucaoTreinoPageState extends State<ExecucaoTreinoPage> {
  late SessaoTreino sessao;
  bool salvando = false;
  bool finalizando = false;

  Timer? temporizador;

  int descansoTotal = 60;
  int segundosRestantes = 60;

  bool descansoAtivo = false;
  bool descansoPausado = false;
  @override
  void initState() {
    super.initState();
    sessao = widget.sessaoInicial;
  }

  void iniciarDescanso(int duracaoSegundos) {
    temporizador?.cancel();

    final int duracao = duracaoSegundos.clamp(0, 3600).toInt();

    if (duracao == 0) {
      setState(() {
        descansoTotal = 0;
        segundosRestantes = 0;
        descansoAtivo = false;
        descansoPausado = false;
      });
      return;
    }

    setState(() {
      descansoTotal = duracao;
      segundosRestantes = duracao;
      descansoAtivo = true;
      descansoPausado = false;
    });

    executarContagem();
  }

  void executarContagem() {
    temporizador?.cancel();

    temporizador = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || finalizando || sessao.finalizada) {
        timer.cancel();
        return;
      }

      if (segundosRestantes <= 1) {
        timer.cancel();

        setState(() {
          segundosRestantes = 0;
          descansoAtivo = false;
          descansoPausado = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Descanso finalizado! Próxima série.'),
            duration: Duration(seconds: 3),
          ),
        );

        return;
      }

      setState(() {
        segundosRestantes--;
      });
    });
  }

  void pausarDescanso() {
    if (!descansoAtivo || descansoPausado) return;

    temporizador?.cancel();

    setState(() {
      descansoPausado = true;
    });
  }

  void retomarDescanso() {
    if (!descansoAtivo || !descansoPausado) return;

    setState(() {
      descansoPausado = false;
    });

    executarContagem();
  }

  void encerrarDescanso() {
    temporizador?.cancel();

    if (!mounted) return;

    setState(() {
      descansoAtivo = false;
      descansoPausado = false;
      segundosRestantes = descansoTotal;
    });
  }

  String formatarTempo(int segundos) {
    final minutos = segundos ~/ 60;
    final resto = segundos % 60;

    return '${minutos.toString().padLeft(2, '0')}:'
        '${resto.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    temporizador?.cancel();
    super.dispose();
  }

  String formatarCarga(double carga) {
    if (carga == 0) return 'Peso corporal / não informado';
    return '${carga.toStringAsFixed(carga % 1 == 0 ? 0 : 1)} kg';
  }

  String formatarData(DateTime data) {
    final d = data.toLocal();
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)} '
        '${d.year} às ${dois(d.hour)}:${dois(d.minute)}';
  }

  Future<void> atualizarSerie(SerieExecutada atualizada) async {
    if (salvando || finalizando || sessao.finalizada) return;

    final anteriores = sessao;
    final novasSeries = sessao.series.map((serie) {
      return serie.id == atualizada.id ? atualizada : serie;
    }).toList();

    final novaSessao = sessao.copiar(series: novasSeries);

    setState(() {
      salvando = true;
      sessao = novaSessao;
    });

    try {
      await widget.onSalvar(novaSessao);
    } catch (erro) {
      if (!mounted) return;

      setState(() => sessao = anteriores);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar a série: $erro')));
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  Future<void> finalizarAutomaticamente() async {
    if (finalizando || salvando || sessao.finalizada) return;

    temporizador?.cancel();

    final sessaoAnterior = sessao;
    final encerrada = sessao.copiar(fim: DateTime.now());

    setState(() {
      finalizando = true;
      sessao = encerrada;
      descansoAtivo = false;
      descansoPausado = false;
    });

    try {
      await widget.onSalvar(encerrada);

      if (!mounted) return;

      await Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute(
          builder: (_) => ResumoTreinoPage(sessao: encerrada),
        ),
      );

    } catch (erro) {
      if (!mounted) return;

      setState(() {
        sessao = sessaoAnterior;
        finalizando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao concluir o treino: $erro'),
        ),
      );
    }
  }

  Future<void> alternarSerie(SerieExecutada serie) async {
    if (salvando || finalizando || sessao.finalizada) return;

    final vaiConcluir = !serie.concluida;

    await atualizarSerie(serie.copiar(concluida: vaiConcluir));

    if (!mounted) return;

    if (!vaiConcluir) {
      encerrarDescanso();
      return;
    }

    final todasConcluidas =
        sessao.series.isNotEmpty && sessao.series.every((s) => s.concluida);

    if (todasConcluidas) {
      await finalizarAutomaticamente();
      return;
    }

    iniciarDescanso(serie.descansoSegundos);
  }

  Future<void> editarSerie(SerieExecutada serie) async {
    if (salvando || finalizando || sessao.finalizada) return;

    final resultado = await showDialog<SerieExecutada>(
      context: context,
      builder: (_) => EditarSerieDialog(serie: serie),
    );

    if (resultado == null || !mounted) return;

    await atualizarSerie(resultado);
  }


Future<void> finalizarTreino() async {
  if (finalizando || salvando || sessao.finalizada) return;

  final confirmar = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Finalizar treino?'),
      content: Text(
        'Você concluiu ${sessao.seriesConcluidas} de '
        '${sessao.series.length} séries.\n\n'
        'Deseja encerrar esta sessão?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Continuar treino'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Finalizar'),
        ),
      ],
    ),
  );

  if (confirmar != true || !mounted) return;

  final sessaoAnterior = sessao;
  final encerrada = sessao.copiar(fim: DateTime.now());

  setState(() {
    finalizando = true;
    sessao = encerrada;
  });

  try {
    await widget.onSalvar(encerrada);

    if (!mounted) return;

    await Navigator.pushReplacement<void, void>(
      context,
      MaterialPageRoute(
        builder: (_) => ResumoTreinoPage(sessao: encerrada),
      ),
    );
  } catch (erro) {
    if (!mounted) return;

    setState(() {
      sessao = sessaoAnterior;
      finalizando = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Não foi possível finalizar o treino: $erro'),
      ),
    );
  }
}


  Widget construirSerie(SerieExecutada serie) {
    final bloqueada = salvando || finalizando || sessao.finalizada;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 5, 12, 7),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: serie.concluida
            ? verde.withValues(alpha: 0.09)
            : fundo.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: serie.concluida
              ? verde.withValues(alpha: 0.5)
              : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: serie.concluida
                      ? verde
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: serie.concluida
                    ? const Icon(Icons.check, color: Colors.black)
                    : Text(
                        '${serie.numeroSerie}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Série ${serie.numeroSerie}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${serie.repeticoesRealizadas} repetições • '
                      '${formatarCarga(serie.cargaKg)}',
                      style: const TextStyle(color: textoSecundario),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Editar carga e repetições',
                onPressed: bloqueada ? null : () => editarSerie(serie),
                icon: const Icon(Icons.edit_outlined, color: verde),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: bloqueada ? null : () => alternarSerie(serie),
              icon: Icon(
                serie.concluida ? Icons.undo : Icons.check_circle_outline,
              ),
              label: Text(
                serie.concluida ? 'Desmarcar série' : 'Concluir série',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: serie.concluida ? superficie : verde,
                foregroundColor: serie.concluida ? Colors.white : Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget construirPainelDescanso() {
    final progresso = descansoTotal == 0
        ? 0.0
        : segundosRestantes / descansoTotal;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: superficie,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: verde.withValues(alpha: 0.55)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined, color: verde),
              SizedBox(width: 8),
              Text(
                'TEMPO DE DESCANSO',
                style: TextStyle(
                  color: textoSecundario,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatarTempo(segundosRestantes),
            style: const TextStyle(
              color: verde,
              fontSize: 44,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progresso.clamp(0.0, 1.0),
              minHeight: 6,
              color: verde,
              backgroundColor: Colors.white12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: descansoPausado ? retomarDescanso : pausarDescanso,
                  icon: Icon(descansoPausado ? Icons.play_arrow : Icons.pause),
                  label: Text(descansoPausado ? 'Retomar' : 'Pausar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: encerrarDescanso,
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Pular descanso'),
                  style: FilledButton.styleFrom(
                    backgroundColor: verde,
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          if (descansoPausado) ...[
            const SizedBox(height: 8),
            const Text(
              'Descanso pausado',
              style: TextStyle(color: textoSecundario),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final agrupadas = <String, List<SerieExecutada>>{};

    for (final serie in sessao.series) {
      agrupadas.putIfAbsent(serie.exercicioId, () => []).add(serie);
    }

    final total = sessao.series.length;
    final concluidas = sessao.seriesConcluidas;
    final progresso = total == 0 ? 0.0 : concluidas / total;
    final percentual = (progresso * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: Text(sessao.nomeTreino),
        actions: [
          if (salvando)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: verde),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: superficie,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Text(
                          'Seu progresso',
                          style: TextStyle(
                            color: textoSecundario,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        '$percentual%',
                        style: const TextStyle(
                          color: verde,
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progresso,
                      minHeight: 9,
                      color: verde,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: verde,
                        size: 19,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '$concluidas de $total séries concluídas',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Início: ${formatarData(sessao.inicio)}',
                    style: const TextStyle(
                      color: textoSecundario,
                      fontSize: 12,
                    ),
                  ),
                  if (sessao.finalizada) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Sessão finalizada',
                      style: TextStyle(
                        color: verde,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (descansoAtivo) construirPainelDescanso(),
            Expanded(
              child: agrupadas.isEmpty
                  ? const Center(child: Text('Nenhuma série nesta sessão.'))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      children: agrupadas.entries.map((entrada) {
                        final series = entrada.value;
                        final primeira = series.first;
                        final feitas = series.where((s) => s.concluida).length;
                        final totalExercicio = series.length;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: verde.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.fitness_center,
                                        color: verde,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            primeira.nomeExercicio,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$feitas de $totalExercicio séries',
                                            style: const TextStyle(
                                              color: textoSecundario,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: totalExercicio == 0
                                        ? 0
                                        : feitas / totalExercicio,
                                    minHeight: 5,
                                    color: verde,
                                    backgroundColor: Colors.white12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...series.map(construirSerie),
                              const SizedBox(height: 5),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            if (salvando || finalizando)
              const LinearProgressIndicator(color: verde, minHeight: 3),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: finalizando || salvando || sessao.finalizada
                      ? null
                      : finalizarTreino,
                  icon: const Icon(Icons.flag_outlined),
                  label: Text(
                    sessao.finalizada
                        ? 'Treino finalizado'
                        : 'Finalizar treino',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: verde,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ResumoTreinoPage extends StatelessWidget {
  final SessaoTreino sessao;

  const ResumoTreinoPage({
    super.key,
    required this.sessao,
  });

  String formatarData(DateTime data) {
    final d = data.toLocal();
    String dois(int n) => n.toString().padLeft(2, '0');

    return '${dois(d.day)}/${dois(d.month)}/${d.year} '
        '${dois(d.hour)}:${dois(d.minute)}';
  }

  String formatarDuracao(Duration duracao) {
    final horas = duracao.inHours;
    final minutos = duracao.inMinutes.remainder(60);
    final segundos = duracao.inSeconds.remainder(60);

    if (horas > 0) {
      return '${horas}h ${minutos}min';
    }

    if (minutos > 0) {
      return '${minutos}min ${segundos}s';
    }

    return '${segundos}s';
  }

  @override
  Widget build(BuildContext context) {
    final total = sessao.series.length;
    final concluidas = sessao.seriesConcluidas;
    final percentual =
        total == 0 ? 0 : (concluidas * 100 / total).round();

    final fim = sessao.fim ?? DateTime.now();
    final duracao = fim.difference(sessao.inicio);

    final agrupadas = <String, List<SerieExecutada>>{};

    for (final serie in sessao.series) {
      agrupadas
          .putIfAbsent(serie.exercicioId, () => [])
          .add(serie);
    }

    final exerciciosConcluidos = agrupadas.values.where((series) {
      return series.every((serie) => serie.concluida);
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumo do treino'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: verde,
            ),
            const SizedBox(height: 12),
            Text(
              'Treino concluído!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              sessao.nomeTreino,
              textAlign: TextAlign.center,
              style: const TextStyle(color: textoSecundario),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Text(
                      '$percentual%',
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: verde,
                      ),
                    ),
                    const Text('Conclusão do treino'),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: total == 0 ? 0 : concluidas / total,
                      color: verde,
                      backgroundColor: Colors.white12,
                      minHeight: 8,
                    ),
                    const SizedBox(height: 20),
                    _itemResumo('Séries concluídas', '$concluidas de $total'),
                    _itemResumo(
                      'Exercícios concluídos',
                      '$exerciciosConcluidos de ${agrupadas.length}',
                    ),
                    _itemResumo('Duração', formatarDuracao(duracao)),
                    _itemResumo('Início', formatarData(sessao.inicio)),
                    _itemResumo('Término', formatarData(fim)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Detalhamento por exercício',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...agrupadas.entries.map((entrada) {
              final series = entrada.value;
              final feitas =
                  series.where((serie) => serie.concluida).length;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        series.first.nomeExercicio,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text('$feitas de ${series.length} séries concluídas'),
                      const Divider(),
                      ...series.map((serie) {
                        final carga = serie.cargaKg == 0
                            ? 'Peso corporal / não informado'
                            : '${serie.cargaKg.toStringAsFixed(
                                serie.cargaKg % 1 == 0 ? 0 : 1,
                              )} kg';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                serie.concluida
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: serie.concluida
                                    ? verde
                                    : textoSecundario,
                                size: 19,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Série ${serie.numeroSerie} • '
                                  '${serie.repeticoesRealizadas} rep. • $carga',
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check),
              label: const Text('Voltar ao aplicativo'),
              style: FilledButton.styleFrom(
                backgroundColor: verde,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemResumo(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              titulo,
              style: const TextStyle(color: textoSecundario),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class EditarSerieDialog extends StatefulWidget {
  final SerieExecutada serie;

  const EditarSerieDialog({super.key, required this.serie});

  @override
  State<EditarSerieDialog> createState() => _EditarSerieDialogState();
}

class _EditarSerieDialogState extends State<EditarSerieDialog> {
  late final TextEditingController repeticoesController;
  late final TextEditingController cargaController;
  String? erro;

  @override
  void initState() {
    super.initState();
    repeticoesController = TextEditingController(
      text: '${widget.serie.repeticoesRealizadas}',
    );
    cargaController = TextEditingController(
      text: widget.serie.cargaKg.toStringAsFixed(
        widget.serie.cargaKg % 1 == 0 ? 0 : 1,
      ),
    );
  }

  @override
  void dispose() {
    repeticoesController.dispose();
    cargaController.dispose();
    super.dispose();
  }

  void salvar() {
    final repeticoes = int.tryParse(repeticoesController.text.trim());
    final carga = double.tryParse(
      cargaController.text.trim().replaceAll(',', '.'),
    );

    if (repeticoes == null ||
        repeticoes < 0 ||
        carga == null ||
        !carga.isFinite ||
        carga < 0) {
      setState(() {
        erro = 'Informe repetições inteiras e uma carga válida, sem valores negativos.';
      });
      return;
    }

    Navigator.of(context).pop(
      widget.serie.copiar(repeticoesRealizadas: repeticoes, cargaKg: carga),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Série ${widget.serie.numeroSerie}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.serie.nomeExercicio,
              style: const TextStyle(color: verde, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Meta: ${widget.serie.repeticoesPlanejadas} repetições',
              style: const TextStyle(color: textoSecundario),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: repeticoesController,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Repetições realizadas',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cargaController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: false,
              ),
              decoration: const InputDecoration(
                labelText: 'Carga utilizada (kg)',
                hintText: '0 para peso corporal ou não informado',
              ),
            ),
            if (erro != null) ...[
              const SizedBox(height: 12),
              Text(erro!, style: const TextStyle(color: Colors.redAccent)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: salvar, child: const Text('Salvar')),
      ],
    );
  }
}

class BibliotecaExerciciosPage extends StatefulWidget {
  final List<Exercicio> exerciciosCadastrados;
  final Future<bool> Function(ExercicioPredefinido) onAdicionar;

  const BibliotecaExerciciosPage({
    super.key,
    required this.exerciciosCadastrados,
    required this.onAdicionar,
  });

  @override
  State<BibliotecaExerciciosPage> createState() =>
      _BibliotecaExerciciosPageState();
}

class _BibliotecaExerciciosPageState extends State<BibliotecaExerciciosPage> {
  final TextEditingController _buscaController = TextEditingController();
  String _grupoSelecionado = 'Todos';
  final Set<String> _adicionadosNestaSessao = {};
  final Set<String> _processando = {};
  List<ExercicioPredefinido> _catalogo = const [];
  String? _erroCatalogo;

  List<String> get _grupos {
    final grupos =
        _catalogo.map((exercicio) => exercicio.grupo).toSet().toList()..sort();
    return ['Todos', ...grupos];
  }

  @override
  void initState() {
    super.initState();
    _carregarCatalogo();
  }

  Future<void> _carregarCatalogo() async {
    try {
      final catalogo = await CatalogoExercicios.instancia.carregar();
      if (!mounted) return;

      setState(() {
        _catalogo = catalogo;
        _erroCatalogo = null;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() => _erroCatalogo = erro.toString());
    }
  }

  String _chave(ExercicioPredefinido exercicio) =>
      '${exercicio.nome.trim().toLowerCase()}|'
      '${exercicio.grupo.trim().toLowerCase()}';

  bool _jaCadastrado(ExercicioPredefinido exercicio) {
    final chave = _chave(exercicio);

    return _adicionadosNestaSessao.contains(chave) ||
        widget.exerciciosCadastrados.any(
          (item) =>
              item.nome.trim().toLowerCase() ==
                  exercicio.nome.trim().toLowerCase() &&
              item.grupo.trim().toLowerCase() ==
                  exercicio.grupo.trim().toLowerCase(),
        );
  }

  List<ExercicioPredefinido> get _exerciciosFiltrados {
    final busca = _buscaController.text.trim().toLowerCase();

    return _catalogo.where((exercicio) {
      final correspondeGrupo =
          _grupoSelecionado == 'Todos' || exercicio.grupo == _grupoSelecionado;

      final termosBusca = [
        exercicio.nome,
        exercicio.grupo,
        exercicio.equipamento,
        exercicio.categoria,
        ...exercicio.musculosPrimarios,
        ...exercicio.musculosSecundarios,
      ].join(' ').toLowerCase();

      final correspondeBusca = termosBusca.contains(busca);

      return correspondeGrupo && correspondeBusca;
    }).toList();
  }

  Future<void> _adicionar(ExercicioPredefinido exercicio) async {
    final chave = _chave(exercicio);

    if (_jaCadastrado(exercicio) || _processando.contains(chave)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esse exercício já está cadastrado.')),
      );
      return;
    }

    setState(() => _processando.add(chave));

    try {
      final sucesso = await widget.onAdicionar(exercicio);

      if (!mounted) return;

      setState(() {
        _processando.remove(chave);

        if (sucesso) {
          _adicionadosNestaSessao.add(chave);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sucesso
                ? '${exercicio.nome} adicionado ao acervo!'
                : 'Esse exercício já está cadastrado.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => _processando.remove(chave));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível adicionar o exercício.'),
        ),
      );
    }
  }

  void _mostrarDetalhes(ExercicioPredefinido exercicio) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.94,
        builder: (context, controlador) => SafeArea(
          top: false,
          child: ListView(
            controller: controlador,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                exercicio.nome,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(exercicio.grupo)),
                  if (exercicio.equipamento.isNotEmpty)
                    Chip(label: Text(exercicio.equipamento)),
                  if (exercicio.nivel.isNotEmpty)
                    Chip(label: Text(exercicio.nivel)),
                  if (exercicio.categoria.isNotEmpty)
                    Chip(label: Text(exercicio.categoria)),
                ],
              ),
              if (exercicio.caminhosImagensAssets.isNotEmpty) ...[
                const SizedBox(height: 20),
                SizedBox(
                  height: 240,
                  child: PageView.builder(
                    itemCount: exercicio.caminhosImagensAssets.length,
                    itemBuilder: (context, index) {
                      final caminho = exercicio.caminhosImagensAssets[index];

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            alignment: Alignment.center,
                            child: Image.asset(
                              caminho,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              errorBuilder: (context, erro, stackTrace) {
                                return const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.image_not_supported_outlined, size: 42),
                                    SizedBox(height: 8),
                                    Text('Imagem indisponível'),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (exercicio.caminhosImagensAssets.length > 1) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Deslize para ver as '
                    '${exercicio.caminhosImagensAssets.length} imagens do exercício',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: textoSecundario, fontSize: 12),
                  ),
                ],
              ],
              if (exercicio.musculosPrimarios.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'Músculos principais',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(exercicio.musculosPrimarios.join(', ')),
              ],
              if (exercicio.musculosSecundarios.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Músculos secundários',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(exercicio.musculosSecundarios.join(', ')),
              ],
              if (exercicio.instrucoes.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'Instruções originais',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...exercicio.instrucoes.indexed.map(
                  (entrada) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text('${entrada.$1 + 1}. ${entrada.$2}'),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                'Dados: Free Exercise DB (Unlicense/public domain).',
                style: TextStyle(color: textoSecundario, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_erroCatalogo != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Biblioteca de exercícios')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 44),
                const SizedBox(height: 12),
                const Text(
                  'Não foi possível abrir o catálogo de exercícios.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _carregarCatalogo,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_catalogo.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Biblioteca de exercícios')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final filtrados = _exerciciosFiltrados;

    return Scaffold(
      appBar: AppBar(title: const Text('Biblioteca de exercícios')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _buscaController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Pesquisar exercício...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _buscaController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _buscaController.clear();
                          setState(() {});
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _grupos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final grupo = _grupos[index];

                return Center(
                  child: FilterChip(
                    label: Text(grupo),
                    selected: _grupoSelecionado == grupo,
                    onSelected: (_) {
                      setState(() => _grupoSelecionado = grupo);
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${filtrados.length} de ${_catalogo.length} exercícios disponíveis',
                style: const TextStyle(color: textoSecundario),
              ),
            ),
          ),
          Expanded(
            child: filtrados.isEmpty
                ? const Center(child: Text('Nenhum exercício encontrado.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filtrados.length,
                    itemBuilder: (context, index) {
                      final exercicio = filtrados[index];
                      final cadastrado = _jaCadastrado(exercicio);
                      final processando = _processando.contains(
                        _chave(exercicio),
                      );

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () => _mostrarDetalhes(exercicio),
                          leading: const CircleAvatar(
                            child: Icon(Icons.fitness_center),
                          ),
                          title: Text(
                            exercicio.nome,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${exercicio.grupo}'
                            '${exercicio.equipamento.isEmpty ? '' : ' • ${exercicio.equipamento}'}'
                            '${exercicio.nivel.isEmpty ? '' : ' • ${exercicio.nivel}'}',
                          ),
                          trailing: cadastrado
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                )
                              : IconButton(
                                  tooltip: 'Adicionar exercício',
                                  onPressed: processando
                                      ? null
                                      : () => _adicionar(exercicio),
                                  icon: processando
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.add_circle),
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
