import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' hide Icon;

import 'painel/w_icone.dart';

import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'dados/workholy_banco.dart';
import 'dados/workholy_modelos.dart';
import 'alunos/alunos_page.dart';
export 'dados/workholy_modelos.dart';
import 'aparencia/workholy_cores.dart';
export 'aparencia/workholy_cores.dart';

import 'preferencias/backup_treino_page.dart';
import 'preferencias/metas_lembretes_page.dart';
import 'perfil_praticante_page.dart';
import 'aparencia/workholy_aparencia.dart';
import 'aparencia/aparencia_page.dart';
import 'painel/componentes_painel.dart';
import 'preferencias/preferencias_treino_page.dart';
import 'preferencias/unidade_carga.dart';
import 'tutorial_primeiro_acesso_page.dart';
import 'exercicios/biblioteca_exercicios.dart';
import 'exercicios/demonstracao_exercicio.dart';
import 'exercicios/aviso_atividade_fisica.dart';
import 'corrida/corrida_banco.dart';
import 'corrida/corrida_page.dart';
import 'assinatura/assinatura_workholy.dart';
import 'assinatura/plano_premium_page.dart';
import 'sincronizacao/sincronizacao_usuario.dart';
import 'sincronizacao/backup_aviso.dart';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'tela_boas_vindas_page.dart';
import 'firebase_options.dart';
import 'autenticacao/autenticacao_page.dart';
import 'autenticacao/nome_pessoa.dart';
import 'recordes/recorde_pessoal.dart';
import 'recordes/recordes_pessoais_page.dart';
import 'workfit/workfit_onboarding_page.dart';
import 'onboarding/dados_pessoais_onboarding_page.dart';
import 'onboarding/perfil_onboarding.dart';
import 'workfit/workfit_perfil.dart';
import 'workfit/workfit_adapter.dart';
import 'workfit/workfit_motor.dart';
import 'workfit/workfit_aprendizado.dart';
import 'workfit/workfit_progressao.dart';
import 'lembretes/lembretes_page.dart';
import 'passos/cartao_passos.dart';
import 'voz/comandos_voz.dart';
import 'voz/escuta_voz.dart';
import 'voz/mensagens_voz.dart';
import 'voz/voz_treinador.dart';
import 'workfit/workfit_leitura.dart';
import 'workfit/workfit_treino_do_dia.dart';
import 'workfit/workfit_ciclo.dart';
import 'workfit/workfit_esforco_dialog.dart';
import 'workfit/workfit_ciclo_card.dart';

const int descansoMaximoSegundos = 3600;
const List<String> _diasTreino = [
  'Seg',
  'Ter',
  'Qua',
  'Qui',
  'Sex',
  'Sáb',
  'Dom',
];

String _formatarDataTreino(DateTime data) =>
    '${data.day.toString().padLeft(2, '0')}/'
    '${data.month.toString().padLeft(2, '0')}/'
    '${data.year.toString().padLeft(4, '0')}';

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

class _SnapshotDadosTreino {
  const _SnapshotDadosTreino({
    required this.treinos,
    required this.exercicios,
    required this.itensTreino,
    required this.sessoes,
    required this.idsExerciciosSelecionados,
  });

  final List<Treino> treinos;
  final List<Exercicio> exercicios;
  final List<ItemTreino> itensTreino;
  final List<SessaoTreino> sessoes;
  final Set<String> idsExerciciosSelecionados;
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
      channelName: 'Corrida Moveria',
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

  runApp(const MoveriaApp());
}

class MoveriaApp extends StatefulWidget {
  const MoveriaApp({super.key});

  @override
  State<MoveriaApp> createState() => _MoveriaAppState();
}

class _MoveriaAppState extends State<MoveriaApp> {
  late final WorkHolyAparencia aparencia;

  @override
  void initState() {
    super.initState();
    aparencia = WorkHolyAparencia();
    aparencia.carregar();
    unawaited(PreferenciaUnidadeCarga.instancia.carregar());
  }

  @override
  void dispose() {
    aparencia.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        aparencia,
        PreferenciaUnidadeCarga.instancia,
      ]),
      builder: (context, _) {
        final modo = aparencia.modo;

        return MaterialApp(
          title: 'Moveria',
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
              if (usuario == null) return const AutenticacaoPage();
              if (!usuario.emailVerified) return const ConfirmarEmailPage();
              return MoveriaHome(aparencia: aparencia, usuario: usuario);
            },
          ),
        );
      },
    );
  }
}

class MoveriaHome extends StatefulWidget {
  const MoveriaHome({
    super.key,
    required this.aparencia,
    required this.usuario,
  });

  final WorkHolyAparencia aparencia;
  final User usuario;
  @override
  State<MoveriaHome> createState() => _MoveriaHomeState();
}

class _MoveriaHomeState extends State<MoveriaHome> {
  static const String chaveTutorialConcluido =
      'workholy_tutorial_primeiro_acesso_v1';

  static const String chaveBoasVindasConcluida =
      'workholy_boas_vindas_concluida_v1';

  bool _verificacaoTutorialIniciada = false;
  bool _avisoTreinoAberto = false;
  bool _contaBloqueada = false;
  String? _nomePerfil;

  List<SessaoTreino> sessoesTreino = [];
  List<CorridaConcluida> corridasFinalizadas = [];
  bool _corridasDisponiveis = false;

  int _ultimaLeituraCorridas = 0;
  int _metaTreinosSemana = 3;

  int abaSelecionada = 0;
  bool carregando = true;
  bool erroCarregamento = false;

  List<Treino> treinos = [];

  List<Exercicio> exercicios = [];

  List<ItemTreino> itensTreino = [];

  final TextEditingController _buscaExerciciosController =
      TextEditingController();
  String _termoBuscaExercicios = '';
  final Set<String> _idsExerciciosSelecionados = <String>{};
  final TextEditingController _buscaTreinosController = TextEditingController();
  String _filtroGrupoTreinos = '';
  int? _filtroDiaTreinos;
  bool _somenteFavoritos = false;

  String? get _nomeCliente {
    return primeiroNome(widget.usuario.displayName) ??
        primeiroNome(_nomePerfil);
  }

  String get _saudacao {
    final hora = DateTime.now().hour;
    final periodo = hora < 12
        ? 'Bom dia'
        : hora < 18
        ? 'Boa tarde'
        : 'Boa noite';
    final nome = _nomeCliente;
    return nome == null ? '$periodo!' : '$periodo, $nome!';
  }

  @override
  void initState() {
    super.initState();
    carregarDados();
    unawaited(carregarCorridasDoPainel());
    unawaited(_carregarMetaTreinosSemana());
  }

  @override
  void dispose() {
    SincronizacaoUsuario.instancia.parar();
    _buscaExerciciosController.dispose();
    _buscaTreinosController.dispose();
    super.dispose();
  }

  Future<void> restaurarBackup(String versao, String? remota) async {
    setState(() => carregando = true);
    Object? falha;
    try {
      await SincronizacaoUsuario.instancia.restaurarVersao(versao, remota);
    } catch (erro, stackTrace) {
      falha = erro;
      debugPrint('Não foi possível restaurar o backup: $erro');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (mounted) await carregarDados();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          falha == null ? 'Backup restaurado.' : 'Não foi possível concluir a restauração. Confira a conexão e finalize corridas abertas.',
        ),
      ),
    );
  }

  Future<void> carregarCorridasDoPainel() async {
    final leitura = ++_ultimaLeituraCorridas;

    try {
      final corridas = await CorridaBanco.instancia.listarFinalizadas();

      if (!mounted || leitura != _ultimaLeituraCorridas) return;

      setState(() {
        corridasFinalizadas = corridas;
        _corridasDisponiveis = true;
      });
    } catch (erro) {
      debugPrint('Erro ao carregar corridas no painel: $erro');
      if (mounted && leitura == _ultimaLeituraCorridas) {
        setState(() => _corridasDisponiveis = false);
      }
    }
  }

  Future<void> _carregarMetaTreinosSemana() async {
    try {
      final meta = await WorkHolyBanco.instancia.lerInteiro(
        'workholy_meta_treinos_semana_v1',
      );
      if (!mounted || meta == null) return;
      setState(() => _metaTreinosSemana = meta.clamp(1, 7).toInt());
    } catch (erro, stackTrace) {
      debugPrint('Erro ao carregar a meta semanal: $erro');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> verificarTutorialPrimeiroAcesso() async {
    if (_verificacaoTutorialIniciada || !mounted) return;

    _verificacaoTutorialIniciada = true;

    var concluido = false;
    try {
      final banco = WorkHolyBanco.instancia;

      // 1. Boas-vindas.
      if (await banco.lerBooleano(chaveBoasVindasConcluida) != true) {
        if (!mounted) return;
        final seguiu = await _abrirEtapaObrigatoria(
          (paginaContext) => TelaBoasVindasPage(
            nome: _nomeCliente,
            onComecar: () => Navigator.of(paginaContext).pop(true),
          ),
        );
        if (!seguiu) return;
        await banco.salvarBooleano(chaveBoasVindasConcluida, true);
      }

      // 2. Dados pessoais, exigidos também de contas antigas incompletas.
      if (!await _perfilPraticanteCompleto()) {
        if (!mounted) return;
        final salvou = await _abrirEtapaObrigatoria(
          (_) => DadosPessoaisOnboardingPage(nomeInicial: _nomeCliente),
        );
        if (!salvou) return;
        await _atualizarNomeDoPerfil();
      }

      // 3. Primeiro treino, criado pelo WorkFit ou manualmente.
      while (mounted && treinos.isEmpty) {
        await _executarEtapaTreinoObrigatoria();
      }
      if (!mounted) return;

      // 4. Tutorial.
      if (await banco.lerBooleano(chaveTutorialConcluido) != true) {
        final viu = await _abrirEtapaObrigatoria(
          (_) => const TutorialPrimeiroAcessoPage(),
        );
        if (!viu) return;
        await banco.salvarBooleano(chaveTutorialConcluido, true);
      }
      concluido = true;
    } catch (erro, stackTrace) {
      debugPrint('Erro na apresentação inicial do WorkHoly: $erro');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível concluir a configuração inicial. '
              'Ela será retomada na próxima abertura do app.',
            ),
          ),
        );
      }
    } finally {
      // Etapas pendentes são retomadas na próxima carga de dados.
      if (!concluido) _verificacaoTutorialIniciada = false;
    }
  }

  Future<bool> _abrirEtapaObrigatoria(WidgetBuilder construtor) async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (contexto) =>
            PopScope(canPop: false, child: construtor(contexto)),
      ),
    );
    return resultado == true;
  }

  Future<Map<String, dynamic>?> _lerPerfilPraticante() async {
    final texto = await WorkHolyBanco.instancia.lerTexto(chavePerfilPraticante);
    if (texto == null) return null;
    try {
      final dados = jsonDecode(texto);
      return dados is Map ? Map<String, dynamic>.from(dados) : null;
    } on FormatException {
      return null;
    }
  }

  static const String _chaveRemocoesWorkFit = 'workfit_remocoes_v1';
  List<RemocaoAprendizado> _remocoesWorkFit = [];

  Future<void> _carregarRemocoesWorkFit() async {
    final texto = await WorkHolyBanco.instancia.lerTexto(_chaveRemocoesWorkFit);
    if (texto == null) return;
    try {
      final dados = jsonDecode(texto);
      if (dados is List) {
        _remocoesWorkFit = dados
            .map(RemocaoAprendizado.tentarLer)
            .whereType<RemocaoAprendizado>()
            .toList();
      }
    } on FormatException {
      _remocoesWorkFit = [];
    }
  }

  Future<void> _registrarRemocoesWorkFit(
    String treinoId,
    List<ItemTreino> novosItens,
  ) async {
    final treino = treinos.where((t) => t.id == treinoId).firstOrNull;
    if (treino?.workfitCiclo == null) return;
    final mantidos = novosItens.map((i) => i.exercicioId).toSet();
    final agora = DateTime.now();
    final novas = <RemocaoAprendizado>[];
    for (final item in itensTreino.where((i) => i.treinoId == treinoId)) {
      if (mantidos.contains(item.exercicioId)) continue;
      final id = exercicios
          .where((e) => e.id == item.exercicioId)
          .firstOrNull
          ?.catalogoId;
      if (id != null) novas.add(RemocaoAprendizado(catalogoId: id, em: agora));
    }
    if (novas.isEmpty) return;
    _remocoesWorkFit = [..._remocoesWorkFit, ...novas];
    await WorkHolyBanco.instancia.salvarTexto(
      _chaveRemocoesWorkFit,
      jsonEncode(_remocoesWorkFit.map((r) => r.toJson()).toList()),
    );
  }

  AprendizadoWorkFit _aprendizadoWorkFit({List<ExercicioBanco>? catalogo}) {
    final catalogoPorExercicio = {
      for (final e in exercicios)
        if (e.catalogoId != null) e.id: e.catalogoId!,
    };
    final sessoes = sessoesTreino
        .where((s) => s.finalizada)
        .map(
          (s) => SessaoAprendizado(
            fim: s.fim!,
            rpe: s.rpe,
            series: s.series
                .map(
                  (serie) => SerieAprendizado(
                    catalogoId:
                        serie.catalogoId ??
                        catalogoPorExercicio[serie.exercicioId],
                    nome: serie.nomeExercicio,
                    concluida: serie.concluida,
                  ),
                )
                .toList(),
          ),
        )
        .toList();
    return AprendizadoWorkFit.construir(
      sessoes: sessoes,
      remocoes: _remocoesWorkFit,
      agora: DateTime.now(),
      catalogo: catalogo,
    );
  }

  Widget _cartaoAprendizadoWorkFit() {
    final ciclo = treinos
        .map((t) => t.workfitCiclo)
        .whereType<WorkFitCiclo>()
        .firstOrNull;
    final insights = _aprendizadoWorkFit().insights(
      diasPlanejadosPorSemana: ciclo?.diasPorSemana,
    );
    if (insights.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'O que o WorkFit aprendeu',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            for (final i in insights)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${i.titulo}: ${i.texto}',
                  style: const TextStyle(color: painelTextoSuave),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<bool> _perfilPraticanteCompleto() async =>
      PerfilOnboarding.perfilCompleto(await _lerPerfilPraticante());

  Future<void> _atualizarNomeDoPerfil() async {
    final nome = (await _lerPerfilPraticante())?['nome']?.toString();
    if (mounted && nome != null) setState(() => _nomePerfil = nome);
  }

  /// Retorna quando o usuário criou ao menos um treino ou precisa tentar de novo.
  Future<void> _executarEtapaTreinoObrigatoria() async {
    List<ExercicioBanco> exerciciosBanco = const [];
    try {
      final catalogo = await CatalogoExercicios.instancia.carregar();
      exerciciosBanco = catalogo.map(ExercicioBanco.doCatalogo).toList();
    } catch (erro) {
      debugPrint('Catálogo indisponível no primeiro acesso: $erro');
    }
    if (!mounted) return;

    final sugestoes = await showDialog<List<WorkFitSugestao>?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Dialog(
          child: WorkFitOnboardingPage(
            onConfirm: (lista) => Navigator.pop(dialogContext, lista),
            onSkip: () => Navigator.pop(dialogContext, null),
            exercicios: exerciciosBanco,
            aprendizado: _aprendizadoWorkFit(catalogo: exerciciosBanco),
          ),
        ),
      ),
    );
    if (!mounted) return;

    if (sugestoes != null && sugestoes.isNotEmpty) {
      try {
        await _procesarSugestoesWorkFit(sugestoes);
        await WorkHolyBanco.instancia.salvarBooleano(
          'workfit_onboarding_concluido_v1',
          true,
        );
      } catch (erro, stackTrace) {
        debugPrint('Erro ao salvar o plano WorkFit: $erro');
        debugPrintStack(stackTrace: stackTrace);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não foi possível salvar o plano WorkFit. Tente novamente.',
              ),
            ),
          );
        }
      }
      return;
    }

    await criarOuEditarTreino();
    if (mounted && treinos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Crie ao menos um treino para continuar.'),
        ),
      );
    }
  }

  Future<void> _procesarSugestoesWorkFit(
    List<WorkFitSugestao> sugestoes,
  ) async {
    final convertidos = WorkFitAdapter.converterSugestoes(sugestoes);
    final treinosNovos = convertidos['treinos']!.map(Treino.fromJson).toList();
    final exerciciosNovos = convertidos['exercicios']!
        .map(Exercicio.fromJson)
        .toList();
    final itensNovos = convertidos['itensTreino']!
        .map(ItemTreino.fromJson)
        .toList();

    await WorkHolyBanco.instancia.salvarDadosTreino(
      treinos: [
        ...treinos.map((treino) => treino.toJson()),
        ...convertidos['treinos']!,
      ],
      exercicios: [
        ...exercicios.map((exercicio) => exercicio.toJson()),
        ...convertidos['exercicios']!,
      ],
      itensTreino: [
        ...itensTreino.map((item) => item.toJson()),
        ...convertidos['itensTreino']!,
      ],
      sessoesTreino: sessoesTreino.map((sessao) => sessao.toJson()).toList(),
    );

    if (!mounted) return;
    setState(() {
      treinos.addAll(treinosNovos);
      exercicios.addAll(exerciciosNovos);
      itensTreino.addAll(itensNovos);
    });
    SincronizacaoUsuario.instancia.agendarEnvio();
  }

  Future<void> verificarWorkFitPrimeiroAcesso({
    bool abrirNovamente = false,
  }) async {
    if (!mounted) return;

    try {
      final banco = WorkHolyBanco.instancia;
      const chaveWorkFitConcluido = 'workfit_onboarding_concluido_v1';

      // Verifica se o onboarding do WorkFit já foi feito
      if (!abrirNovamente &&
          await banco.lerBooleano(chaveWorkFitConcluido) == true) {
        return; // Já foi feito, não mostra novamente
      }

      if (!mounted) return;

      // Preserva metadados e instruções para a avaliação local.
      final catalogo = await CatalogoExercicios.instancia.carregar();
      final exerciciosBanco = catalogo.map(ExercicioBanco.doCatalogo).toList();

      if (!mounted) return;

      // Mostra o onboarding do WorkFit com os exercícios reais do banco
      final resultadoWorkFit = await showDialog<List<WorkFitSugestao>?>(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          child: WorkFitOnboardingPage(
            onConfirm: (sugestoes) {
              Navigator.pop(context, sugestoes);
            },
            onSkip: () {
              Navigator.pop(context, null);
            },
            exercicios: exerciciosBanco,
            aprendizado: _aprendizadoWorkFit(catalogo: exerciciosBanco),
          ),
        ),
      );

      if (!mounted) return;

      // Se o usuário confirmou, salva os treinos gerados
      if (resultadoWorkFit != null && resultadoWorkFit.isNotEmpty) {
        await _procesarSugestoesWorkFit(resultadoWorkFit);
      }
    } catch (erro) {
      debugPrint('Erro na apresentação inicial do Moveria: $erro');
    }
  }

  Future<void> carregarDados() async {
    try {
      await SincronizacaoUsuario.instancia.prepararConta(widget.usuario);
      if (!mounted) return;
      if (primeiroNome(widget.usuario.displayName) == null) {
        final perfil = await WorkHolyBanco.instancia.lerTexto(
          chavePerfilPraticante,
        );
        if (perfil != null) {
          try {
            final dadosPerfil = jsonDecode(perfil);
            if (dadosPerfil is Map && dadosPerfil['nome'] is String) {
              _nomePerfil = dadosPerfil['nome'] as String;
            }
          } on FormatException catch (erro) {
            debugPrint('Não foi possível ler o nome salvo no perfil: $erro');
          }
        }
      }
      final dados = await WorkHolyBanco.instancia.carregarDadosTreino();

      // A leitura é concluída antes de alterar o estado da tela.
      final treinosCarregados = dados.treinos.map(Treino.fromJson).toList();
      final exerciciosCarregados = dados.exercicios
          .map(Exercicio.fromJson)
          .toList();
      final itensCarregados = dados.itensTreino
          .map(ItemTreino.fromJson)
          .toList();
      final sessoesCarregadas = <SessaoTreino>[];
      for (final registro in dados.sessoesTreino) {
        try {
          sessoesCarregadas.add(SessaoTreino.fromJson(registro));
        } on FormatException catch (erro, stackTrace) {
          debugPrint('Sessão inválida ignorada: $erro');
          debugPrintStack(stackTrace: stackTrace);
        } on TypeError catch (erro, stackTrace) {
          debugPrint('Sessão inválida ignorada: $erro');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

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
      erroCarregamento = false;
    } catch (erro, stackTrace) {
      debugPrint('Erro ao carregar dados do Moveria: $erro');
      debugPrintStack(stackTrace: stackTrace);
      erroCarregamento = true;

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
          if (mounted && !erroCarregamento) {
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
      SincronizacaoUsuario.instancia.agendarEnvio();
    } catch (erro) {
      debugPrint('Erro ao salvar dados do Moveria: $erro');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao salvar os dados no aparelho.')),
        );
      }
      rethrow;
    }
  }

  _SnapshotDadosTreino _capturarDadosTreino() {
    return _SnapshotDadosTreino(
      treinos: List<Treino>.from(treinos),
      exercicios: List<Exercicio>.from(exercicios),
      itensTreino: List<ItemTreino>.from(itensTreino),
      sessoes: List<SessaoTreino>.from(sessoesTreino),
      idsExerciciosSelecionados: Set<String>.from(_idsExerciciosSelecionados),
    );
  }

  Future<bool> _salvarComRollback(_SnapshotDadosTreino anterior) async {
    try {
      await salvarDados();
      return true;
    } catch (_) {
      treinos
        ..clear()
        ..addAll(anterior.treinos);
      exercicios
        ..clear()
        ..addAll(anterior.exercicios);
      itensTreino
        ..clear()
        ..addAll(anterior.itensTreino);
      sessoesTreino
        ..clear()
        ..addAll(anterior.sessoes);
      _idsExerciciosSelecionados
        ..clear()
        ..addAll(anterior.idsExerciciosSelecionados);
      if (mounted) setState(() {});
      return false;
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
          sessoesTreino: sessoesTreino,
          corridasConcluidas: corridasFinalizadas,
          corridasDisponiveis: _corridasDisponiveis,
          onSalvar: (novosItens) => salvarItensDoTreino(treinoId, novosItens),
          onIniciarTreino: () => iniciarSessaoTreino(treinoId),
          sessoesAnteriores: List<SessaoTreino>.from(sessoesTreino),
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  Future<void> iniciarSessaoTreino(String treinoId, {String? alunoId}) async {
    final sessoesEmAndamento = sessoesTreino
        .where((sessao) => !sessao.finalizada)
        .toList();
    final sessaoEmAndamento = sessoesEmAndamento
        .where((sessao) => sessao.alunoId == alunoId)
        .firstOrNull;
    if (sessaoEmAndamento != null) {
      final retomar = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Treino em andamento'),
          content: Text(
            'Você já tem uma sessão de "${sessaoEmAndamento.nomeTreino}" '
            'em andamento. Deseja retomá-la?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Retomar'),
            ),
          ],
        ),
      );
      if (retomar == true && mounted) {
        await retomarSessaoTreino(sessaoEmAndamento);
      }
      return;
    }
    if (sessoesEmAndamento.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Finalize ou retome o treino em andamento antes de iniciar outro.',
          ),
        ),
      );
      return;
    }

    final indiceTreino = treinos.indexWhere((t) => t.id == treinoId);
    if (indiceTreino < 0) return;

    // Um toque em play n\u00e3o pode criar uma segunda sess\u00e3o para o mesmo
    // treino enquanto a anterior ainda est\u00e1 em andamento. Isso tamb\u00e9m faz
    // com que, ao voltar ao app, o usu\u00e1rio retome exatamente o progresso
    // que deixou salvo.
    final sessoesAbertas =
        sessoesTreino
            .where(
              (sessao) => !sessao.finalizada && sessao.treinoId == treinoId,
            )
            .toList()
          ..sort((a, b) => b.inicio.compareTo(a.inicio));

    if (sessoesAbertas.isNotEmpty) {
      await retomarSessaoTreino(sessoesAbertas.first);
      return;
    }

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

    if (_avisoTreinoAberto) return;
    _avisoTreinoAberto = true;
    final bool continuar;
    try {
      continuar = await mostrarAvisoAtividadeFisica(context);
    } finally {
      _avisoTreinoAberto = false;
    }
    if (!mounted || !continuar) return;

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
            pesoCorporal: item.pesoCorporal,
            instrucoes: item.instrucoes,
            metaCargaKg: item.metaCargaKg,
            metaRepeticoes: item.metaRepeticoes,
            concluida: false,
            catalogoId: indice >= 0 ? exercicios[indice].catalogoId : null,
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
      alunoId: alunoId,
    );

    final anterior = _capturarDadosTreino();
    setState(() => sessoesTreino.add(sessao));
    if (!await _salvarComRollback(anterior)) return;

    if (!mounted) return;

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ExecucaoTreinoPage(
          sessaoInicial: sessao,
          onSalvar: salvarSessao,
          cargasMaximasAnteriores: _cargasMaximasAnteriores(sessao),
          exercicios: List<Exercicio>.from(exercicios),
          carregarCatalogo: CatalogoExercicios.instancia.carregar,
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  Future<void> salvarSessao(SessaoTreino sessao) async {
    final indice = sessoesTreino.indexWhere((s) => s.id == sessao.id);
    final sessoesAnteriores = List<SessaoTreino>.from(sessoesTreino);
    final atualizadas = List<SessaoTreino>.from(sessoesTreino);

    if (indice < 0) {
      atualizadas.add(sessao);
    } else {
      atualizadas[indice] = sessao;
    }
    sessoesTreino
      ..clear()
      ..addAll(atualizadas);

    try {
      await salvarDados();
    } catch (_) {
      sessoesTreino
        ..clear()
        ..addAll(sessoesAnteriores);
      rethrow;
    }

    if (mounted) setState(() {});
  }

  Map<String, double> _cargasMaximasAnteriores(SessaoTreino atual) {
    final cargas = <String, double>{};
    for (final sessao in sessoesTreino.where(
      (item) =>
          item.finalizada &&
          item.id != atual.id &&
          item.alunoId == atual.alunoId,
    )) {
      for (final serie in sessao.series.where((item) => item.concluida)) {
        final anterior = cargas[serie.exercicioId] ?? 0;
        if (serie.cargaKg > anterior) {
          cargas[serie.exercicioId] = serie.cargaKg;
        }
      }
    }
    return cargas;
  }

  Future<void> editarAnotacoes(SessaoTreino sessao) async {
    final controller = TextEditingController(text: sessao.anotacoes);
    try {
      final texto = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Anotações da sessão'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 8,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Como foi o treino? Registre observações.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Salvar'),
            ),
          ],
        ),
      );
      if (texto == null || !mounted) return;
      try {
        await salvarSessao(sessao.copiar(anotacoes: texto.trim()));
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Anotações salvas.')));
      } catch (erro) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível salvar as anotações: $erro'),
          ),
        );
      }
    } finally {
      controller.dispose();
    }
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

    final anterior = _capturarDadosTreino();
    setState(() {
      sessoesTreino.removeWhere((sessao) => sessao.finalizada);
    });

    if (!await _salvarComRollback(anterior)) return;

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
          cargasMaximasAnteriores: _cargasMaximasAnteriores(sessao),
          exercicios: List<Exercicio>.from(exercicios),
          carregarCatalogo: CatalogoExercicios.instancia.carregar,
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

    final anterior = _capturarDadosTreino();
    setState(() {
      sessoesTreino.removeWhere((item) => item.id == sessao.id);
    });
    if (!await _salvarComRollback(anterior)) return;

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
    final anterior = _capturarDadosTreino();
    itensTreino.removeWhere((item) => item.treinoId == treinoId);
    itensTreino.addAll(novosItens);

    final indice = treinos.indexWhere((t) => t.id == treinoId);
    final treinosAtualizados = List<Treino>.from(treinos);
    if (indice >= 0) {
      final antigo = treinos[indice];
      treinosAtualizados[indice] = Treino(
        id: antigo.id,
        nome: antigo.nome,
        objetivo: antigo.objetivo,
        grupo: antigo.grupo,
        favorito: antigo.favorito,
        diasSemana: antigo.diasSemana,
        anotacoes: antigo.anotacoes,
        exercicios: novosItens.length,
        workfitCiclo: antigo.workfitCiclo,
      );
    }
    final itensAtualizados = [
      ...itensTreino.where((item) => item.treinoId != treinoId),
      ...novosItens,
    ];
    await WorkHolyBanco.instancia.salvarDadosTreino(
      treinos: treinosAtualizados.map((item) => item.toJson()).toList(),
      exercicios: exercicios.map((item) => item.toJson()).toList(),
      itensTreino: itensAtualizados.map((item) => item.toJson()).toList(),
      sessoesTreino: sessoesTreino.map((item) => item.toJson()).toList(),
    );
    treinos = treinosAtualizados;
    itensTreino = itensAtualizados;
    SincronizacaoUsuario.instancia.agendarEnvio();
    if (mounted) setState(() {});
    if (!await _salvarComRollback(anterior)) {
      throw StateError('Não foi possível salvar as alterações do treino.');
    }
  }

  Future<void> criarOuEditarTreino([Treino? existente]) async {
    final resultado = await showDialog<Treino>(
      context: context,
      builder: (_) => FormularioTreinoDialog(existente: existente),
    );

    if (resultado == null || !mounted) return;

    final anterior = _capturarDadosTreino();
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

    await _salvarComRollback(anterior);
  }

  Future<void> alternarFavorito(Treino treino) async {
    final anterior = _capturarDadosTreino();
    final indice = treinos.indexWhere((item) => item.id == treino.id);
    if (indice < 0) return;
    setState(() {
      treinos[indice] = treino.copiar(favorito: !treino.favorito);
    });
    await _salvarComRollback(anterior);
  }

  Future<void> duplicarTreino(Treino treino) async {
    final novoTreinoId = novoId('treino');
    final novosItens = itensTreino
        .where((item) => item.treinoId == treino.id)
        .map(
          (item) => ItemTreino(
            id: novoId('item'),
            treinoId: novoTreinoId,
            exercicioId: item.exercicioId,
            series: item.series,
            repeticoes: item.repeticoes,
            cargaKg: item.cargaKg,
            descansoSegundos: item.descansoSegundos,
            pesoCorporal: item.pesoCorporal,
            instrucoes: item.instrucoes,
            metaCargaKg: item.metaCargaKg,
            metaRepeticoes: item.metaRepeticoes,
          ),
        )
        .toList();
    final novoTreino = treino.copiar(
      id: novoTreinoId,
      nome: '${treino.nome} (cópia)',
      favorito: false,
      exercicios: novosItens.length,
    );
    final anterior = _capturarDadosTreino();
    setState(() {
      treinos.add(novoTreino);
      itensTreino.addAll(novosItens);
    });
    if (!await _salvarComRollback(anterior)) return;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cópia de "${treino.nome}" criada.')),
      );
    }
  }

  Future<void> excluirTreino(Treino treino) async {
    final confirmar = await confirmarExclusao(
      titulo: 'Excluir treino?',
      mensagem:
          'O treino "${treino.nome}" e os exercícios associados a ele serão removidos.',
    );

    if (confirmar != true || !mounted) return;

    final anterior = _capturarDadosTreino();
    setState(() {
      treinos.removeWhere((t) => t.id == treino.id);
      itensTreino.removeWhere((item) => item.treinoId == treino.id);
    });

    await _salvarComRollback(anterior);
  }

  Future<int> adicionarExerciciosPredefinidos(
    List<ExercicioPredefinido> predefinidos,
  ) async {
    final novosExercicios = <Exercicio>[];
    final idsCatalogoExistentes = exercicios
        .map((exercicio) => exercicio.catalogoId)
        .whereType<String>()
        .toSet();

    for (final predefinido in predefinidos) {
      if (idsCatalogoExistentes.contains(predefinido.id)) continue;

      final nomeNormalizado = predefinido.nome.trim().toLowerCase();
      final grupoNormalizado = predefinido.grupo.trim().toLowerCase();
      final jaExiste = [...exercicios, ...novosExercicios].any((exercicio) {
        final nomeExistente = exercicio.nome.trim().toLowerCase();
        return (nomeExistente == nomeNormalizado ||
                nomeExistente.startsWith('$nomeNormalizado (')) &&
            exercicio.grupo.trim().toLowerCase() == grupoNormalizado;
      });
      if (jaExiste) continue;

      novosExercicios.add(
        Exercicio(
          nome: predefinido.nomeComNomeOriginal,
          grupo: predefinido.grupo,
          series: predefinido.series,
          repeticoes: predefinido.repeticoes,
          catalogoId: predefinido.id,
        ),
      );
      idsCatalogoExistentes.add(predefinido.id);
    }

    if (novosExercicios.isEmpty) return 0;

    final anterior = _capturarDadosTreino();
    setState(() {
      exercicios.addAll(novosExercicios);
    });

    if (!await _salvarComRollback(anterior)) {
      throw StateError('Não foi possível salvar os exercícios do catálogo.');
    }

    return novosExercicios.length;
  }

  Future<void> criarOuEditarExercicio([Exercicio? existente]) async {
    final resultado = await showDialog<Exercicio>(
      context: context,
      builder: (_) => FormularioExercicioDialog(existente: existente),
    );

    if (resultado == null || !mounted) return;

    final anterior = _capturarDadosTreino();
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

    await _salvarComRollback(anterior);
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

    final anterior = _capturarDadosTreino();
    final exerciciosRestantes = exercicios
        .where((exercicio) => !idsValidos.contains(exercicio.id))
        .toList();
    final itensRestantes = itensTreino
        .where((item) => !idsValidos.contains(item.exercicioId))
        .toList();
    setState(() {
      exercicios = exerciciosRestantes;
      itensTreino = itensRestantes;
      _idsExerciciosSelecionados.removeAll(idsValidos);
    });

    if (!await _salvarComRollback(anterior)) return;

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
      _DestinoNavegacao(
        rotulo: 'Alunos',
        icone: Icons.groups_outlined,
        iconeSelecionado: Icons.groups,
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0C0E13),
        border: Border(top: BorderSide(color: painelBorda)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              for (var indice = 0; indice < destinos.length; indice++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final destino = destinos[indice];
                      final selecionado = indice == abaSelecionada;
                      final cor = selecionado ? painelLima : painelTextoSuave;
                      return Semantics(
                        button: true,
                        selected: selecionado,
                        label: destino.rotulo,
                        child: InkWell(
                          onTap: () => selecionarAba(indice),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                selecionado
                                    ? destino.iconeSelecionado
                                    : destino.icone,
                                color: cor,
                                size: 24,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                destino.rotulo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: cor,
                                  fontWeight: selecionado
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_contaBloqueada) {
      return Scaffold(
        appBar: AppBar(title: const Text('WorkHoly')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Este aparelho contém dados de outra conta. '
                  'Para protegê-los, a troca está bloqueada. Saia e entre '
                  'novamente na conta anterior; não desinstale o aplicativo.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  child: const Text('Sair desta conta'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (carregando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: verde)),
      );
    }
    final paginas = [
      construirPainel(),
      construirPaginaTreinos(),
      construirPaginaExercicios(),
      CorridaPage(
        onHistoricoAtualizado: carregarCorridasDoPainel,
        ciclosWorkFit: {
          for (final ciclo
              in treinos
                  .map((treino) => treino.workfitCiclo)
                  .whereType<WorkFitCiclo>())
            ciclo.id: ciclo,
        }.values.toList(),
      ),
      construirPaginaHistorico(),
      AlunosPage(
        treinos: treinos,
        exercicios: exercicios,
        itensTreino: itensTreino,
        sessoes: sessoesTreino,
        onIniciarTreino: (treinoId, alunoId) =>
            iniciarSessaoTreino(treinoId, alunoId: alunoId),
        onDadosAlterados: carregarDados,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.fitness_center, color: verde),
            SizedBox(width: 10),
            Text('Moveria', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ConfiguracoesPage(
                    aparencia: widget.aparencia,
                    exercicios: List<Exercicio>.from(exercicios),
                    onBackupRestaurado: carregarDados,
                    onMetaAtualizada: _carregarMetaTreinosSemana,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator(color: verde))
          : erroCarregamento
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storage_outlined, size: 48, color: verde),
                    const SizedBox(height: 12),
                    const Text(
                      'Não foi possível carregar os dados salvos. '
                      'Para evitar sobrescrever seu histórico, as alterações '
                      'estão temporariamente bloqueadas.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          carregando = true;
                          erroCarregamento = false;
                        });
                        carregarDados();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            )
          : SafeArea(
              child: IndexedStack(index: abaSelecionada, children: paginas),
            ),
      bottomNavigationBar: construirBarraDeNavegacao(),
    );
  }

  Widget _cartaoTreinoDoDia() {
    final resultado = escolherTreinoDoDia(
      treinos: [
        for (final t in treinos)
          CandidatoTreinoDia(
            id: t.id,
            nome: t.nome,
            quantidadeExercicios: itensTreino
                .where((i) => i.treinoId == t.id)
                .length,
            ciclo: t.workfitCiclo,
          ),
      ],
      sessoes: [
        for (final s in sessoesTreino)
          SessaoTreinoDia(
            id: s.id,
            treinoId: s.treinoId,
            inicio: s.inicio,
            fim: s.fim,
            planoId: s.workfitPlanoId,
          ),
      ],
      agora: DateTime.now(),
    );
    final cor = switch (resultado.situacao) {
      SituacaoTreinoDia.descanso ||
      SituacaoTreinoDia.concluidoHoje => const Color(0xFF2EE59D),
      _ => painelLima,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CartaoPainel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TituloSecaoPainel(
              'Treino de hoje',
              icone: Icons.fitness_center,
            ),
            const SizedBox(height: 10),
            Text(
              resultado.mensagem,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (resultado.fraseFase != null) ...[
              const SizedBox(height: 6),
              Text(
                resultado.fraseFase!,
                style: const TextStyle(color: painelTextoSuave, fontSize: 13),
              ),
            ],
            if (resultado.estadoCiclo != null &&
                !resultado.estadoCiclo!.naoIniciado &&
                !resultado.estadoCiclo!.encerrado) ...[
              const SizedBox(height: 6),
              Text(
                '${resultado.estadoCiclo!.diasConcluidos} de '
                '${resultado.estadoCiclo!.metaSemanal} dias concluídos '
                'nesta semana.',
                style: const TextStyle(color: painelTextoSuave, fontSize: 13),
              ),
            ],
            if (resultado.podeAbrirExecucao) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => iniciarSessaoTreino(resultado.treino!.id),
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  resultado.situacao == SituacaoTreinoDia.retomar
                      ? 'Retomar treino'
                      : 'Começar agora',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: cor,
                  foregroundColor: Colors.black,
                ),
              ),
            ] else if (resultado.situacao == SituacaoTreinoDia.semTreino) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    verificarWorkFitPrimeiroAcesso(abrirNovamente: true),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Criar plano com WorkFit'),
              ),
            ],
          ],
        ),
      ),
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
    final treinosConcluidosSemana = sessoesFinalizadas.where((sessao) {
      final fim = sessao.fim!;
      return !fim.isBefore(inicioSemana) &&
          fim.isBefore(inicioSemana.add(const Duration(days: 7)));
    }).length;

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

    final inicioSemanaAnterior = inicioSemana.subtract(const Duration(days: 7));
    bool naSemana(DateTime d, DateTime inicio) =>
        !d.isBefore(inicio) && d.isBefore(inicio.add(const Duration(days: 7)));

    final diasAtivosSemana = valoresSemana.where((v) => v > 0).length;
    final seriesSemana = sessoesFinalizadas
        .where((s) => naSemana(s.inicio, inicioSemana))
        .fold<int>(0, (t, s) => t + s.seriesConcluidas);
    final seriesSemanaAnterior = sessoesFinalizadas
        .where((s) => naSemana(s.inicio, inicioSemanaAnterior))
        .fold<int>(0, (t, s) => t + s.seriesConcluidas);
    double kmNoPeriodo(DateTime inicio) =>
        corridasFinalizadas
            .where((c) => naSemana(c.inicio, inicio))
            .fold<double>(0, (t, c) => t + c.distanciaMetros) /
        1000;
    final kmSemana = kmNoPeriodo(inicioSemana);
    final kmSemanaAnterior = kmNoPeriodo(inicioSemanaAnterior);
    final kmTotal =
        corridasFinalizadas.fold<double>(0, (t, c) => t + c.distanciaMetros) /
        1000;
    final caloriasTotal = corridasFinalizadas.fold<double>(
      0,
      (t, c) => t + c.caloriasEstimadas,
    );

    final diasComAtividade = {
      for (final a in atividadesFinalizadas)
        DateTime(a.inicio.year, a.inicio.month, a.inicio.day),
    };
    var sequenciaDias = 0;
    var cursor = DateTime(agora.year, agora.month, agora.day);
    if (!diasComAtividade.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (diasComAtividade.contains(cursor)) {
      sequenciaDias++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          _saudacao,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Acompanhe sua rotina e sua evolução.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),

        _cartaoTreinoDoDia(),

        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flag_outlined, color: verde),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Meta semanal de musculação',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '$treinosConcluidosSemana/$_metaTreinosSemana',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: (treinosConcluidosSemana / _metaTreinosSemana)
                      .clamp(0.0, 1.0)
                      .toDouble(),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tempo total de treino',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    AnelProgressoPainel(
                      progresso: diasAtivosSemana / 7,
                      cor: painelLima,
                      icone: Icons.calendar_month,
                      valor: '$diasAtivosSemana',
                      detalhe: '/ 7',
                      rotulo: 'Dias ativos',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${atividadesFinalizadas.length} atividades finalizadas',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        Card(
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
                  Text(
                    'Você ainda não concluiu uma atividade. '
                    'Seu histórico aparecerá aqui.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ultimaAtividade.tipo == _TipoAtividadePainel.corrida
                        ? '${((ultimaAtividade.distanciaMetros ?? 0) / 1000).toStringAsFixed(2).replaceAll('.', ',')} km'
                              ' • ${_formatarDuracao(ultimaAtividade.duracaoSegundos)}'
                        : '${ultimaAtividade.seriesConcluidas} séries concluídas',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
          Text(
            'Nenhum treino cadastrado. Crie seu primeiro treino.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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

  double _progressoContraAnterior(num atual, num anterior) {
    if (atual <= 0) return 0;
    if (anterior <= 0) return 1;
    return (atual / anterior).toDouble();
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
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            height: altura,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary
                                  .withValues(alpha: valor == 0 ? 0.20 : 0.90),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            rotulos[indice],
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
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
              Text(
                'Ainda não há sessões concluídas neste período.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
        color: Theme.of(context).colorScheme.surfaceContainerLow,
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
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
    final itensDoTreino = itensTreino
        .where((item) => item.treinoId == treino.id)
        .toList();
    final sessoesDoTreino =
        sessoesTreino
            .where(
              (sessao) => sessao.treinoId == treino.id && sessao.finalizada,
            )
            .toList()
          ..sort((a, b) => b.inicio.compareTo(a.inicio));
    final duracaoEstimada = _duracaoEstimada(itensDoTreino);
    final ultimaSessao = sessoesDoTreino.firstOrNull;
    final cores = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: painelFundoCartao,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: painelBorda),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => abrirDetalhesTreino(treino.id),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cores.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.fitness_center,
                  color: cores.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            treino.nome,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: treino.favorito
                              ? 'Remover dos favoritos'
                              : 'Adicionar aos favoritos',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => alternarFavorito(treino),
                          icon: Icon(
                            treino.favorito ? Icons.star : Icons.star_border,
                            color: treino.favorito ? Colors.amber : null,
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Opções do treino',
                          onSelected: (opcao) {
                            switch (opcao) {
                              case 'abrir':
                                abrirDetalhesTreino(treino.id);
                              case 'editar':
                                criarOuEditarTreino(treino);
                              case 'duplicar':
                                duplicarTreino(treino);
                              case 'excluir':
                                excluirTreino(treino);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'abrir',
                              child: Text('Montar treino'),
                            ),
                            PopupMenuItem(
                              value: 'editar',
                              child: Text('Editar detalhes'),
                            ),
                            PopupMenuItem(
                              value: 'duplicar',
                              child: Text('Duplicar treino'),
                            ),
                            PopupMenuItem(
                              value: 'excluir',
                              child: Text('Excluir treino'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (treino.objetivo.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        treino.objetivo,
                        style: TextStyle(color: cores.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (treino.grupo.trim().isNotEmpty)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(treino.grupo),
                          ),
                        if (treino.diasSemana.isNotEmpty)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(Icons.event_repeat, size: 16),
                            label: Text(
                              treino.diasSemana
                                  .map((dia) => _diasTreino[dia - 1])
                                  .join(', '),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '${itensDoTreino.length} ${itensDoTreino.length == 1 ? 'exercício' : 'exercícios'}'
                      '${duracaoEstimada == null ? '' : ' • Cerca de $duracaoEstimada min'}',
                      style: TextStyle(
                        color: cores.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ultimaSessao == null
                          ? 'Ainda não realizado'
                          : 'Último: ${_formatarDataTreino(ultimaSessao.fim!)}',
                      style: TextStyle(
                        color: cores.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int? _duracaoEstimada(List<ItemTreino> itensDoTreino) {
    if (itensDoTreino.isEmpty) return null;
    final segundos = itensDoTreino.fold<int>(0, (total, item) {
      final tempoExecucao = item.series * item.repeticoes * 3;
      final descansos =
          (item.series - 1).clamp(0, item.series) * item.descansoSegundos;
      return total + tempoExecucao + descansos + 60;
    });
    return (segundos / 60).ceil();
  }

  List<Treino> get _treinosFiltrados {
    final termo = _buscaTreinosController.text.trim().toLowerCase();
    return treinos.where((treino) {
      final correspondeBusca =
          termo.isEmpty ||
          treino.nome.toLowerCase().contains(termo) ||
          treino.objetivo.toLowerCase().contains(termo) ||
          treino.grupo.toLowerCase().contains(termo);
      final correspondeGrupo =
          _filtroGrupoTreinos.isEmpty || treino.grupo == _filtroGrupoTreinos;
      final correspondeDia =
          _filtroDiaTreinos == null ||
          treino.diasSemana.contains(_filtroDiaTreinos);
      return correspondeBusca &&
          correspondeGrupo &&
          correspondeDia &&
          (!_somenteFavoritos || treino.favorito);
    }).toList()..sort((a, b) {
      if (a.favorito != b.favorito) return a.favorito ? -1 : 1;
      return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
    });
  }

  Widget _planejamentoSemanal() {
    final planejados = treinos.where((treino) => treino.diasSemana.isNotEmpty);
    if (planejados.isEmpty) return const SizedBox.shrink();
    final nomesDoDia = _filtroDiaTreinos == null
        ? const <String>[]
        : planejados
              .where((treino) => treino.diasSemana.contains(_filtroDiaTreinos))
              .map((treino) => treino.nome)
              .toList();
    final cores = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Planejamento semanal',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: List.generate(_diasTreino.length, (indice) {
                final dia = indice + 1;
                final quantidade = planejados
                    .where((treino) => treino.diasSemana.contains(dia))
                    .length;
                return FilterChip(
                  label: Text('${_diasTreino[indice]} $quantidade'),
                  selected: _filtroDiaTreinos == dia,
                  onSelected: quantidade == 0
                      ? null
                      : (_) => setState(() {
                          _filtroDiaTreinos = _filtroDiaTreinos == dia
                              ? null
                              : dia;
                          _filtroGrupoTreinos = '';
                        }),
                );
              }),
            ),
            if (nomesDoDia.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Na rotina: ${nomesDoDia.join(', ')}',
                style: TextStyle(color: cores.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget construirPaginaTreinos() {
    final filtrados = _treinosFiltrados;
    final grupos =
        treinos
            .map((treino) => treino.grupo.trim())
            .where((grupo) => grupo.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Meus treinos',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton.filled(
              onPressed: () => criarOuEditarTreino(),
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _buscaTreinosController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Buscar por treino, objetivo ou grupo',
            suffixIcon: _buscaTreinosController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpar busca',
                    onPressed: () {
                      _buscaTreinosController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close),
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('Favoritos'),
              avatar: const Icon(Icons.star, size: 18),
              selected: _somenteFavoritos,
              onSelected: (selecionado) =>
                  setState(() => _somenteFavoritos = selecionado),
            ),
            ChoiceChip(
              label: const Text('Todos os grupos'),
              selected: _filtroGrupoTreinos.isEmpty,
              onSelected: (_) => setState(() => _filtroGrupoTreinos = ''),
            ),
            ...grupos.map(
              (grupo) => ChoiceChip(
                label: Text(grupo),
                selected: _filtroGrupoTreinos == grupo,
                onSelected: (_) => setState(
                  () => _filtroGrupoTreinos = _filtroGrupoTreinos == grupo
                      ? ''
                      : grupo,
                ),
              ),
            ),
          ],
        ),
        _planejamentoSemanal(),
        const SizedBox(height: 8),
        if (treinos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Text(
              'Você ainda não cadastrou treinos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (treinos.isNotEmpty && filtrados.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Text(
              'Nenhum treino corresponde aos filtros selecionados.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ...filtrados.map((treino) => cartaoTreino(treino)),
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
                              onAdicionar: adicionarExerciciosPredefinidos,
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
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context)
                            .colorScheme
                            .onPrimary,
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
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
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
          color: selecionado
              ? painelLima.withValues(alpha: 0.12)
              : painelFundoCartao,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: selecionado ? painelLima : painelBorda),
          ),
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
                : CircleAvatar(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    child: Icon(
                      Icons.fitness_center,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
            title: Text(
              exercicio.nome,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${exercicio.grupo} • ${exercicio.series} séries • ${exercicio.repeticoes} repetições',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (exercicio.anotacoes.isNotEmpty)
                  Text(
                    exercicio.anotacoes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
              ],
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
    final cores = Theme.of(context).colorScheme;

    String dataFormatada(DateTime data) {
      final d = data.toLocal();
      String dois(int n) => n.toString().padLeft(2, '0');
      return '${dois(d.day)}/${dois(d.month)}/${d.year} '
          '${dois(d.hour)}:${dois(d.minute)}';
    }

    final agora = DateTime.now();
    final inicioSemana = DateTime(
      agora.year,
      agora.month,
      agora.day,
    ).subtract(Duration(days: agora.weekday - 1));
    final seriesPorDia = List<int>.generate(7, (i) {
      final dia = inicioSemana.add(Duration(days: i));
      return sessoesTreino
          .where(
            (s) =>
                s.finalizada &&
                s.inicio.year == dia.year &&
                s.inicio.month == dia.month &&
                s.inicio.day == dia.day,
          )
          .fold<int>(0, (t, s) => t + s.seriesConcluidas);
    });
    final finalizadas = sessoesTreino.where((s) => s.finalizada).toList();
    final diasComAtividade = {
      for (final s in finalizadas)
        DateTime(s.inicio.year, s.inicio.month, s.inicio.day),
      for (final c in corridasFinalizadas)
        DateTime(c.inicio.year, c.inicio.month, c.inicio.day),
    };
    var sequencia = 0;
    var cursor = DateTime(agora.year, agora.month, agora.day);
    if (!diasComAtividade.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (diasComAtividade.contains(cursor)) {
      sequencia++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    final maisSeries = finalizadas.fold<int>(
      0,
      (m, s) => s.seriesConcluidas > m ? s.seriesConcluidas : m,
    );
    final maiorCorridaKm =
        corridasFinalizadas.fold<double>(
          0,
          (m, c) => c.distanciaMetros > m ? c.distanciaMetros : m,
        ) /
        1000;
    final maiorGasto = corridasFinalizadas.fold<double>(
      0,
      (m, c) => c.caloriasEstimadas > m ? c.caloriasEstimadas : m,
    );

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
        CartaoPainel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TituloSecaoPainel(
                'Séries concluídas na semana',
                icone: Icons.bar_chart,
              ),
              const SizedBox(height: 12),
              BarrasSemanaPainel(
                rotulos: const [
                  'Seg',
                  'Ter',
                  'Qua',
                  'Qui',
                  'Sex',
                  'Sáb',
                  'Dom',
                ],
                valores: seriesPorDia,
                indiceAtual: agora.weekday - 1,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const TituloSecaoPainel('Conquistas', icone: Icons.emoji_events),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SeloConquistaPainel(
                valor: '$sequencia',
                titulo: 'Sequência de dias',
                descricao: sequencia > 0
                    ? 'Continue assim!'
                    : 'Conclua uma atividade hoje.',
                cor: painelLima,
                ativo: sequencia > 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SeloConquistaPainel(
                valor: '${finalizadas.length}',
                titulo: 'Treinos concluídos',
                descricao: 'Total desde o início.',
                cor: painelRoxo,
                ativo: finalizadas.isNotEmpty,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const TituloSecaoPainel(
          'Recordes pessoais',
          icone: Icons.military_tech,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: MetricaPainel(
                valor: '$maisSeries',
                unidade: '',
                rotulo: 'Mais séries em um treino',
                icone: Icons.check_circle_outline,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricaPainel(
                valor: maiorCorridaKm.toStringAsFixed(1).replaceAll('.', ','),
                unidade: 'km',
                rotulo: 'Maior corrida',
                icone: Icons.directions_run,
                cor: painelRoxo,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricaPainel(
                valor: '${maiorGasto.round()}',
                unidade: 'kcal',
                rotulo: 'Maior gasto',
                icone: Icons.local_fire_department,
                cor: const Color(0xFFFF7A45),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const TituloSecaoPainel('Sessões de treino', icone: Icons.history),
        const SizedBox(height: 10),
        if (ordenadas.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Icon(Icons.history, size: 44, color: cores.primary),
                  const SizedBox(height: 12),
                  const Text(
                    'Nenhuma sessão registrada',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Inicie um treino para registrar sua primeira sessão.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cores.onSurfaceVariant),
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
            final minutos = (sessao.fim ?? DateTime.now())
                .difference(sessao.inicio)
                .inMinutes;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: painelFundoCartao,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: painelBorda),
              ),
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
                            icon: Icon(
                              Icons.play_circle_outline,
                              color: cores.primary,
                            ),
                          ),
                        IconButton(
                          tooltip: 'Anotações da sessão',
                          onPressed: () => editarAnotacoes(sessao),
                          icon: Icon(
                            sessao.anotacoes.isEmpty
                                ? Icons.note_add_outlined
                                : Icons.sticky_note_2_outlined,
                          ),
                        ),
                        if (sessao.finalizada &&
                            treinos.any((t) => t.id == sessao.treinoId))
                          IconButton(
                            tooltip: 'Refazer treino',
                            onPressed: () {
                              iniciarSessaoTreino(
                                sessao.treinoId,
                                alunoId: sessao.alunoId,
                              );
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
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${sessao.finalizada ? "Finalizado" : "Em andamento"}'
                      ' • $feitas/$total séries'
                      ' • $minutos min',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (sessao.anotacoes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        sessao.anotacoes,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: progresso.clamp(0.0, 1.0),
                      color: Theme.of(context).colorScheme.primary,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
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
  const ConfiguracoesPage({
    super.key,
    required this.aparencia,
    required this.exercicios,
    required this.onBackupRestaurado,
    required this.onMetaAtualizada,
  });

  final WorkHolyAparencia aparencia;
  final List<Exercicio> exercicios;
  final Future<void> Function() onBackupRestaurado;
  final Future<void> Function() onMetaAtualizada;

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
    ).push(MaterialPageRoute<void>(builder: (_) => const SobreMoveriaPage()));
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
          Text(
            'Gerencie as preferências do Moveria.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'PREFERÊNCIAS',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
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
                  leading: const Icon(
                    Icons.emoji_events_outlined,
                    color: verde,
                  ),
                  title: const Text('Recordes pessoais'),
                  subtitle: const Text('Acompanhe suas melhores marcas'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => RecordesPessoaisPage(
                          exercicios: exercicios
                              .map(
                                (e) => RecordeExercicio(id: e.id, nome: e.nome),
                              )
                              .toList(),
                        ),
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
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.scale_outlined, color: verde),
                  title: const Text('Unidade de carga'),
                  subtitle: const Text('Os valores são armazenados em kg'),
                  trailing: DropdownButton<UnidadeCarga>(
                    value: PreferenciaUnidadeCarga.instancia.unidade,
                    items: const [
                      DropdownMenuItem(
                        value: UnidadeCarga.kg,
                        child: Text('kg'),
                      ),
                      DropdownMenuItem(
                        value: UnidadeCarga.lb,
                        child: Text('lb'),
                      ),
                    ],
                    onChanged: (unidade) async {
                      if (unidade == null) return;
                      try {
                        await PreferenciaUnidadeCarga.instancia.definir(
                          unidade,
                        );
                      } catch (erro) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Não foi possível salvar a unidade: $erro',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text(
            'APLICATIVO',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
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
                  leading: const Icon(Icons.flag_outlined, color: verde),
                  title: const Text('Metas e lembretes'),
                  subtitle: const Text(
                    'Objetivo semanal e notificação recorrente',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute<void>(
                            builder: (_) => const MetasLembretesPage(),
                          ),
                        )
                        .then((_) => onMetaAtualizada());
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.backup_outlined, color: verde),
                  title: const Text('Backup e exportação'),
                  subtitle: const Text(
                    'Salvar no Google Drive, exportar ou restaurar',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BackupTreinoPage(
                          onBackupRestaurado: onBackupRestaurado,
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
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
                  title: const Text('Sobre o Moveria'),
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

class SobreMoveriaPage extends StatelessWidget {
  const SobreMoveriaPage({super.key});

  static const String direitosAutorais =
      '© 2026 Murilo da Silva Machado. Todos os direitos reservados.';

  static const String termosDeUso = '''
TERMOS DE USO — MOVERIA

1. FINALIDADE
O Moveria é um aplicativo destinado à organização e ao acompanhamento de
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
a orientação de profissionais de saúde ou de educação física. Antes de realizar
exercícios físicos, é importante procurar um médico. O WorkHoly é feito para
amantes do exercício físico e não substitui o acompanhamento de um profissional
de educação física qualificado e registrado no conselho profissional (CREF).

6. ATUALIZAÇÕES
Estes termos poderão ser revisados conforme a evolução do aplicativo.
''';

  static const String politicaPrivacidade = '''
POLÍTICA DE PRIVACIDADE — MOVERIA

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
      appBar: AppBar(title: const Text('Sobre o Moveria')),
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
            'Moveria',
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
                  Text(
                    'DESENVOLVEDOR',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
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
                  Text(
                    direitosAutorais,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'INFORMAÇÕES LEGAIS',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
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
          Text(
            'O uso e a distribuição do aplicativo estão sujeitos à legislação '
            'aplicável e às licenças dos componentes utilizados.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
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
  late final TextEditingController grupoController;
  late final TextEditingController anotacoesController;
  late Set<int> diasSemana;
  late bool favorito;

  @override
  void initState() {
    super.initState();
    nomeController = TextEditingController(text: widget.existente?.nome ?? '');
    objetivoController = TextEditingController(
      text: widget.existente?.objetivo ?? '',
    );
    grupoController = TextEditingController(
      text: widget.existente?.grupo ?? '',
    );
    anotacoesController = TextEditingController(
      text: widget.existente?.anotacoes ?? '',
    );
    diasSemana = {...?widget.existente?.diasSemana};
    favorito = widget.existente?.favorito ?? false;
  }

  @override
  void dispose() {
    nomeController.dispose();
    objetivoController.dispose();
    grupoController.dispose();
    anotacoesController.dispose();
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
        grupo: grupoController.text.trim(),
        favorito: favorito,
        diasSemana: diasSemana.toList(),
        anotacoes: anotacoesController.text.trim(),
        exercicios: existente?.exercicios ?? 0,
        workfitCiclo: existente?.workfitCiclo,
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
            const SizedBox(height: 12),
            TextField(
              controller: grupoController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Grupo ou divisão',
                hintText: 'Ex.: A, Superior, Força',
                helperText: 'Use o mesmo nome para agrupar treinos.',
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Dias planejados (opcional)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: List.generate(_diasTreino.length, (indice) {
                final dia = indice + 1;
                return FilterChip(
                  label: Text(_diasTreino[indice]),
                  selected: diasSemana.contains(dia),
                  onSelected: (selecionado) => setState(() {
                    if (selecionado) {
                      diasSemana.add(dia);
                    } else {
                      diasSemana.remove(dia);
                    }
                  }),
                );
              }),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Marcar como favorito'),
              value: favorito,
              onChanged: (valor) => setState(() => favorito = valor),
            ),
            TextField(
              controller: anotacoesController,
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 4,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Anotações do treino',
                hintText: 'Orientações gerais para esta rotina',
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
  late final TextEditingController anotacoesController;

  @override
  void initState() {
    super.initState();

    final exercicio = widget.existente;

    nomeController = TextEditingController(text: exercicio?.nome ?? '');
    grupoController = TextEditingController(text: exercicio?.grupo ?? '');
    anotacoesController = TextEditingController(
      text: exercicio?.anotacoes ?? '',
    );
  }

  @override
  void dispose() {
    nomeController.dispose();
    grupoController.dispose();
    anotacoesController.dispose();
    super.dispose();
  }

  void salvar() {
    final nome = nomeController.text.trim();
    final grupo = grupoController.text.trim();
    if (nome.isEmpty || grupo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome e o grupo muscular.')),
      );
      return;
    }

    Navigator.of(context).pop(
      Exercicio(
        id: widget.existente?.id,
        nome: nome,
        grupo: grupo,
        series: widget.existente?.series ?? 3,
        repeticoes: widget.existente?.repeticoes ?? 12,
        anotacoes: anotacoesController.text.trim(),
        catalogoId: widget.existente?.catalogoId,
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
            TextField(
              controller: anotacoesController,
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Anotações do exercício',
                hintText: 'Dicas de execução ou observações pessoais',
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

// ============================================================
// DETALHES E MONTAGEM DO TREINO
// ============================================================

class DetalheTreinoPage extends StatefulWidget {
  final Treino treino;
  final List<Exercicio> exerciciosDisponiveis;
  final List<ItemTreino> itensIniciais;
  final List<SessaoTreino> sessoesTreino;
  final List<CorridaConcluida> corridasConcluidas;
  final bool corridasDisponiveis;
  final List<SessaoTreino> sessoesAnteriores;
  final Future<void> Function(List<ItemTreino>) onSalvar;
  final Future<void> Function() onIniciarTreino;

  const DetalheTreinoPage({
    super.key,
    required this.treino,
    required this.exerciciosDisponiveis,
    required this.itensIniciais,
    this.sessoesTreino = const [],
    this.corridasConcluidas = const [],
    this.corridasDisponiveis = false,
    this.sessoesAnteriores = const [],
    required this.onSalvar,
    required this.onIniciarTreino,
  });

  @override
  State<DetalheTreinoPage> createState() => _DetalheTreinoPageState();
}

class _DetalheTreinoPageState extends State<DetalheTreinoPage> {
  late List<ItemTreino> itens;
  late List<ItemTreino> _itensSalvos;
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
    _itensSalvos = List<ItemTreino>.from(widget.itensIniciais);

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

  String _resumoMeta(ItemTreino item) {
    final partes = <String>[];
    if (item.metaCargaKg != null) {
      partes.add(PreferenciaUnidadeCarga.instancia.formatar(item.metaCargaKg!));
    }
    if (item.metaRepeticoes != null) {
      partes.add('${item.metaRepeticoes} repetições');
    }
    return partes.join(' • ');
  }

  String _resumoUltimaExecucao(ItemTreino item) {
    final sessoes =
        widget.sessoesAnteriores
            .where(
              (sessao) =>
                  sessao.treinoId == widget.treino.id && sessao.finalizada,
            )
            .toList()
          ..sort((a, b) => b.inicio.compareTo(a.inicio));
    if (sessoes.isEmpty) return 'Ainda sem histórico deste treino';

    final seriesPorSessao = sessoes
        .map(
          (sessao) => sessao.series
              .where(
                (serie) =>
                    serie.exercicioId == item.exercicioId && serie.concluida,
              )
              .toList(),
        )
        .where((series) => series.isNotEmpty)
        .toList();
    if (seriesPorSessao.isEmpty) {
      return 'Sem séries concluídas deste exercício';
    }

    final todasAsSeries = seriesPorSessao.expand((series) => series).toList();
    SerieExecutada compararCarga(SerieExecutada melhor, SerieExecutada serie) {
      if (serie.cargaKg != melhor.cargaKg) {
        return serie.cargaKg > melhor.cargaKg ? serie : melhor;
      }
      return serie.repeticoesRealizadas > melhor.repeticoesRealizadas
          ? serie
          : melhor;
    }

    SerieExecutada compararRepeticoes(
      SerieExecutada melhor,
      SerieExecutada serie,
    ) {
      if (serie.repeticoesRealizadas != melhor.repeticoesRealizadas) {
        return serie.repeticoesRealizadas > melhor.repeticoesRealizadas
            ? serie
            : melhor;
      }
      return serie.cargaKg > melhor.cargaKg ? serie : melhor;
    }

    final compararDesempenho = item.pesoCorporal
        ? compararRepeticoes
        : compararCarga;
    final ultimaSerie = seriesPorSessao.first.reduce(compararDesempenho);
    final maiorCarga = todasAsSeries.reduce(compararCarga);
    final maisRepeticoes = todasAsSeries.reduce(compararRepeticoes);
    final resultado = <String>[
      'Última sessão: ${formatarCarga(ultimaSerie.cargaKg, pesoCorporal: item.pesoCorporal)} '
          '× ${ultimaSerie.repeticoesRealizadas}',
    ];
    if (item.metaCargaKg case final metaCarga?) {
      resultado.add(
        'Carga máxima: ${formatarCarga(maiorCarga.cargaKg, pesoCorporal: item.pesoCorporal)} • '
        '${maiorCarga.cargaKg >= metaCarga ? 'Meta de carga atingida' : 'faltam ${formatarCarga(metaCarga - maiorCarga.cargaKg)}'}',
      );
    }
    if (item.metaRepeticoes case final metaRepeticoes?) {
      resultado.add(
        'Mais repetições: ${maisRepeticoes.repeticoesRealizadas} • '
        '${maisRepeticoes.repeticoesRealizadas >= metaRepeticoes ? 'Meta de repetições atingida' : 'faltam ${metaRepeticoes - maisRepeticoes.repeticoesRealizadas} reps'}',
      );
    }
    return resultado.join(' • ');
  }

  Future<void> compartilharTreino() async {
    final dias = widget.treino.diasSemana
        .map((dia) => _diasTreino[dia - 1])
        .join(', ');
    final duracao = _duracaoEstimada(itens);
    final linhas = <String>[
      'Treino: ${widget.treino.nome}',
      if (widget.treino.grupo.trim().isNotEmpty)
        'Divisão: ${widget.treino.grupo}',
      if (widget.treino.objetivo.trim().isNotEmpty)
        'Objetivo: ${widget.treino.objetivo}',
      if (dias.isNotEmpty) 'Dias sugeridos: $dias',
      if (duracao != null) 'Duração estimada: cerca de $duracao min',
      if (widget.treino.anotacoes.trim().isNotEmpty)
        'Orientações: ${widget.treino.anotacoes.trim()}',
      '',
      for (var indice = 0; indice < itens.length; indice++)
        ..._linhasCompartilhamentoItem(indice, itens[indice]),
    ];
    try {
      final compartilhado =
          await const MethodChannel('br.com.workholyia.workholy_mobile/sharing')
              .invokeMethod<bool>('compartilharTexto', {
                'titulo': 'Treino ${widget.treino.nome}',
                'texto': linhas.join('\n'),
              });
      if (!mounted) return;
      if (compartilhado != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('O compartilhamento foi cancelado.')),
        );
      }
    } on PlatformException catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível compartilhar o treino: ${erro.message}',
          ),
        ),
      );
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compartilhamento disponível somente no Android.'),
        ),
      );
    }
  }

  List<String> _linhasCompartilhamentoItem(int indice, ItemTreino item) {
    final exercicio = encontrarExercicio(item.exercicioId);
    final nome = exercicio?.nome ?? 'Exercício indisponível';
    final carga = formatarCarga(item.cargaKg, pesoCorporal: item.pesoCorporal);
    final meta = _resumoMeta(item);
    return [
      '${indice + 1}. $nome',
      '   ${item.series} × ${item.repeticoes} • $carga • descanso '
          '${formatarDescanso(item.descansoSegundos)}',
      if (meta.isNotEmpty) '   Meta: $meta',
      if (item.instrucoes.trim().isNotEmpty)
        '   Instruções: ${item.instrucoes.trim()}',
    ];
  }

  int? _duracaoEstimada(List<ItemTreino> itensDoTreino) {
    if (itensDoTreino.isEmpty) return null;
    final segundos = itensDoTreino.fold<int>(0, (total, item) {
      final tempoExecucao = item.series * item.repeticoes * 3;
      final descansos =
          (item.series - 1).clamp(0, item.series) * item.descansoSegundos;
      return total + tempoExecucao + descansos + 60;
    });
    return (segundos / 60).ceil();
  }

  Future<void> reordenarExercicio(int indiceAntigo, int indiceNovo) async {
    setState(() {
      final item = itens.removeAt(indiceAntigo);
      itens.insert(indiceNovo, item);
    });
    await persistir();
  }

  Future<void> persistir() async {
    setState(() => salvando = true);

    try {
      await widget.onSalvar(List<ItemTreino>.from(itens));

      if (!mounted) return;

      _itensSalvos = List<ItemTreino>.from(itens);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Treino salvo com sucesso.')),
      );
    } catch (erro) {
      if (!mounted) return;

      setState(() => itens = List<ItemTreino>.from(_itensSalvos));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar o treino: $erro')));
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  Future<void> sugerirAjustes() async {
    final sessoes = widget.sessoesTreino
        .where((sessao) => sessao.treinoId == widget.treino.id)
        .toList();
    if (sessoes.any((sessao) => !sessao.finalizada)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Finalize a sessão aberta antes de ajustar o treino.'),
        ),
      );
      return;
    }
    sessoes.sort((a, b) => b.fim!.compareTo(a.fim!));
    if (sessoes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conclua um treino para ver sugestões de ajuste.'),
        ),
      );
      return;
    }
    final ultima = sessoes.first;
    final ciclo = widget.treino.workfitCiclo;
    final estadoCiclo = ciclo == null
        ? null
        : avaliarCicloWorkFit(ciclo, DateTime.now(), []);
    if (estadoCiclo?.naoIniciado == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'O ciclo ainda não começou. Confira a data do aparelho.',
          ),
        ),
      );
      return;
    }
    final cicloEncerrado = estadoCiclo?.encerrado == true;

    DesempenhoWorkFit? desempenho(SessaoTreino sessao, ItemTreino item) {
      final series = sessao.series
          .where((serie) => serie.exercicioId == item.exercicioId)
          .toList();
      final numeros = series.map((serie) => serie.numeroSerie).toSet();
      if (series.length != item.series ||
          numeros.length != item.series ||
          !List.generate(
            item.series,
            (indice) => indice + 1,
          ).every(numeros.contains)) {
        return null;
      }
      return DesempenhoWorkFit(
        rpe: sessao.rpe,
        rir: sessao.rir,
        series: series
            .map(
              (serie) => ResultadoSerieWorkFit(
                concluida: serie.concluida,
                repeticoesPlanejadas: serie.repeticoesPlanejadas,
                repeticoesRealizadas: serie.repeticoesRealizadas,
                cargaKg: serie.cargaKg,
              ),
            )
            .toList(),
      );
    }

    final alteracoes = <String, AjusteWorkFit>{};
    final leituras = <String, LeituraWorkFit>{};
    for (final item in itens) {
      if (item.workfitUltimaSessaoAjustada == ultima.id ||
          (cicloEncerrado && item.workfitCicloRecuperado == ciclo?.id) ||
          itens
                  .where((outro) => outro.exercicioId == item.exercicioId)
                  .length !=
              1) {
        continue;
      }
      final recente = desempenho(ultima, item);
      if (recente == null) continue;
      final leitura = lerExercicioWorkFit(
        seriesPlanejadas: item.series,
        repeticoesPlanejadas: item.repeticoes,
        cargaPlanejadaKg: item.cargaKg,
        ultima: recente,
        anterior: sessoes.length > 1 ? desempenho(sessoes[1], item) : null,
        cicloEncerrado: cicloEncerrado,
        exigirEsforco: ciclo != null,
        permitirProgressao:
            item.progressaoAtiva &&
            (estadoCiclo == null ||
                estadoCiclo.semana == 2 ||
                estadoCiclo.semana == 3),
      );
      leituras[item.id] = leitura;
      if (leitura.ajuste != null) alteracoes[item.id] = leitura.ajuste!;
    }
    if (leituras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nenhum exercício com série registrada na última sessão para analisar.',
          ),
        ),
      );
      return;
    }
    String descrever(ItemTreino item, AjusteWorkFit ajuste) {
      final nome = encontrarExercicio(item.exercicioId)?.nome ?? 'Exercício';
      return switch (ajuste.tipo) {
        TipoAjusteWorkFit.repeticoes =>
          '$nome: ${item.repeticoes} → ${ajuste.repeticoes} repetições',
        TipoAjusteWorkFit.carga =>
          '$nome: ${item.cargaKg} → ${ajuste.cargaKg} kg',
        TipoAjusteWorkFit.recuperacao =>
          '$nome: ${item.series} → ${ajuste.series} séries (recuperação)',
      };
    }

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Sugestões para o próximo treino'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sugestões baseadas nas sessões registradas e, quando informado, '
                'no esforço geral. Não avaliam técnica. Confira a disponibilidade '
                'das cargas e revise antes de aceitar. Ajustes de recuperação '
                'permanecem no treino até você alterá-los novamente.',
              ),
              const SizedBox(height: 12),
              for (final item in itens)
                if (leituras[item.id] case final leitura?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          leitura.ajuste != null
                              ? descrever(item, leitura.ajuste!)
                              : '${encontrarExercicio(item.exercicioId)?.nome ?? 'Exercício'}: sem alteração',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          leitura.motivo,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: Text(alteracoes.isEmpty ? 'Entendi' : 'Agora não'),
          ),
          if (alteracoes.isNotEmpty)
            FilledButton(
              onPressed: () => Navigator.pop(contexto, true),
              child: const Text('Aplicar ajustes'),
            ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    if (widget.sessoesTreino.any(
      (sessao) => sessao.treinoId == widget.treino.id && !sessao.finalizada,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Finalize a sessão aberta antes de ajustar o treino.'),
        ),
      );
      return;
    }
    final atuais =
        widget.sessoesTreino
            .where((sessao) => sessao.treinoId == widget.treino.id)
            .toList()
          ..sort((a, b) => b.fim!.compareTo(a.fim!));
    if (atuais.isEmpty || !identical(atuais.first, ultima)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O histórico mudou. Gere as sugestões novamente.'),
        ),
      );
      return;
    }
    final novosItens = [
      for (final item in itens)
        if (alteracoes[item.id] case final ajuste?)
          ItemTreino(
            id: item.id,
            treinoId: item.treinoId,
            exercicioId: item.exercicioId,
            series: ajuste.series,
            repeticoes: ajuste.repeticoes,
            cargaKg: ajuste.cargaKg,
            descansoSegundos: item.descansoSegundos,
            progressaoAtiva: item.progressaoAtiva,
            workfitUltimaSessaoAjustada: ultima.id,
            workfitCicloRecuperado:
                ajuste.tipo == TipoAjusteWorkFit.recuperacao && cicloEncerrado
                ? ciclo?.id
                : item.workfitCicloRecuperado,
          )
        else
          item,
    ];
    setState(() => salvando = true);
    try {
      await widget.onSalvar(novosItens);
      if (!mounted) return;
      setState(() => itens = novosItens);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ajustes salvos para os próximos treinos.'),
        ),
      );
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar os ajustes: $erro')),
      );
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
                leading: iconeGrupo(exercicio.grupo, color: verde),
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
      progressaoAtiva: false,
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

  String formatarCarga(double carga, {bool pesoCorporal = false}) {
    return PreferenciaUnidadeCarga.instancia.formatar(
      carga,
      pesoCorporal: pesoCorporal,
    );
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
          if (widget.treino.workfitCiclo?.modalidade != 'corrida')
            IconButton(
              tooltip: 'Sugerir ajustes',
              onPressed: salvando ? null : sugerirAjustes,
              icon: const Icon(Icons.trending_up),
            ),
          IconButton(
            tooltip: 'Compartilhar treino',
            onPressed: itens.isEmpty ? null : compartilharTreino,
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: 'Iniciar treino',
            onPressed: salvando || itens.isEmpty
                ? null
                : () async {
                    await widget.onIniciarTreino();
                    if (mounted) setState(() {});
                  },
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
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.treino.objetivo.isEmpty
                          ? 'Objetivo não definido'
                          : widget.treino.objetivo,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${itens.length} ${itens.length == 1 ? 'exercício configurado' : 'exercícios configurados'}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.treino.grupo.trim().isNotEmpty ||
                        widget.treino.diasSemana.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (widget.treino.grupo.trim().isNotEmpty)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(widget.treino.grupo),
                            ),
                          if (widget.treino.diasSemana.isNotEmpty)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              avatar: const Icon(Icons.event_repeat, size: 16),
                              label: Text(
                                widget.treino.diasSemana
                                    .map((dia) => _diasTreino[dia - 1])
                                    .join(', '),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (widget.treino.anotacoes.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.treino.anotacoes,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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
                            Text(
                              'Adicione exercícios cadastrados e configure séries, repetições, carga e descanso.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
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
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
                      buildDefaultDragHandles: false,
                      itemCount: itens.length,
                      onReorderItem: salvando ? null : reordenarExercicio,
                      itemBuilder: (context, indice) {
                        final ciclo = widget.treino.workfitCiclo;
                        if (ciclo != null && indice == 0) {
                          final corridasDoPlano =
                              widget.corridasConcluidas
                                  .where(
                                    (corrida) =>
                                        corrida.workfitPlanoId == ciclo.id,
                                  )
                                  .toList()
                                ..sort((a, b) => b.fim.compareTo(a.fim));
                          return WorkFitCicloCard(
                            key: ValueKey('workfit-ciclo-${ciclo.id}'),
                            ciclo: ciclo,
                            dadosDisponiveis:
                                ciclo.modalidade != 'corrida' ||
                                widget.corridasDisponiveis,
                            temCorrida: corridasDoPlano.isNotEmpty,
                            ultimoRpeCorrida: corridasDoPlano.isEmpty
                                ? null
                                : corridasDoPlano.first.rpe,
                            sessoes: ciclo.modalidade == 'corrida'
                                ? corridasDoPlano
                                      .map(
                                        (corrida) => DiaConcluidoWorkFit(
                                          planoId: corrida.workfitPlanoId!,
                                          data: corrida.fim,
                                        ),
                                      )
                                      .toList()
                                : widget.sessoesTreino
                                      .where(
                                        (sessao) =>
                                            sessao.finalizada &&
                                            sessao.seriesConcluidas > 0 &&
                                            sessao.workfitPlanoId != null,
                                      )
                                      .map(
                                        (sessao) => DiaConcluidoWorkFit(
                                          planoId: sessao.workfitPlanoId!,
                                          data: sessao.fim!,
                                        ),
                                      )
                                      .toList(),
                          );
                        }
                        if (ciclo != null) indice--;
                        final item = itens[indice];
                        final exercicio = encontrarExercicio(item.exercicioId);
                        final ultimaExecucao = _resumoUltimaExecucao(item);
                        final meta = _resumoMeta(item);

                        return Card(
                          key: ValueKey(item.id),
                          margin: const EdgeInsets.only(bottom: 10),
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ReorderableDragStartListener(
                                  index: indice,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      top: 8,
                                      right: 10,
                                    ),
                                    child: Icon(
                                      Icons.drag_handle,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: verde.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${indice + 1}',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => editarExercicio(item),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
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
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 8),
                                          Text(
                                            '${item.series} séries × ${item.repeticoes} repetições',
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${formatarCarga(item.cargaKg, pesoCorporal: item.pesoCorporal)} • Descanso: ${formatarDescanso(item.descansoSegundos)}',
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (meta.isNotEmpty) ...[
                                            const SizedBox(height: 5),
                                            Text(
                                              'Meta: $meta',
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 5),
                                          Text(
                                            ultimaExecucao,
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (item.instrucoes
                                              .trim()
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              item.instrucoes,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
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
                        );
                      },
                    ),
            ),
            if (salvando)
              LinearProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
                minHeight: 3,
              ),
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
  late final TextEditingController instrucoesController;
  late final TextEditingController metaCargaController;
  late final TextEditingController metaRepeticoesController;
  bool pesoCorporal = false;
  bool progressaoAtiva = true;

  String? erroValidacao;

  @override
  void initState() {
    super.initState();

    final item = widget.item;
    pesoCorporal = item.pesoCorporal;
    progressaoAtiva = item.progressaoAtiva;

    seriesController = TextEditingController(text: '${item.series}');
    repeticoesController = TextEditingController(text: '${item.repeticoes}');
    final cargaExibida = PreferenciaUnidadeCarga.instancia.deKg(item.cargaKg);
    cargaController = TextEditingController(
      text: cargaExibida.toStringAsFixed(cargaExibida % 1 == 0 ? 0 : 1),
    );
    descansoController = TextEditingController(
      text: '${item.descansoSegundos}',
    );
    instrucoesController = TextEditingController(text: item.instrucoes);
    final metaCargaExibida = item.metaCargaKg == null
        ? null
        : PreferenciaUnidadeCarga.instancia.deKg(item.metaCargaKg!);
    metaCargaController = TextEditingController(
      text: metaCargaExibida == null
          ? ''
          : metaCargaExibida.toStringAsFixed(metaCargaExibida % 1 == 0 ? 0 : 1),
    );
    metaRepeticoesController = TextEditingController(
      text: item.metaRepeticoes?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    seriesController.dispose();
    repeticoesController.dispose();
    cargaController.dispose();
    descansoController.dispose();
    instrucoesController.dispose();
    metaCargaController.dispose();
    metaRepeticoesController.dispose();
    super.dispose();
  }

  void salvar() {
    final series = int.tryParse(seriesController.text.trim());
    final repeticoes = int.tryParse(repeticoesController.text.trim());
    final cargaTexto = cargaController.text.trim().replaceAll(',', '.');
    final carga = double.tryParse(cargaTexto);
    final descanso = int.tryParse(descansoController.text.trim());
    final metaCargaTexto = metaCargaController.text.trim().replaceAll(',', '.');
    final metaCarga = metaCargaTexto.isEmpty
        ? null
        : double.tryParse(metaCargaTexto);
    final metaRepeticoesTexto = metaRepeticoesController.text.trim();
    final metaRepeticoes = metaRepeticoesTexto.isEmpty
        ? null
        : int.tryParse(metaRepeticoesTexto);

    if (series == null ||
        repeticoes == null ||
        carga == null ||
        descanso == null ||
        series < 1 ||
        repeticoes < 1 ||
        !carga.isFinite ||
        carga < 0 ||
        descanso < 0 ||
        descanso > descansoMaximoSegundos ||
        (metaCargaTexto.isNotEmpty &&
            (metaCarga == null || !metaCarga.isFinite || metaCarga < 0)) ||
        (metaRepeticoesTexto.isNotEmpty &&
            (metaRepeticoes == null || metaRepeticoes < 1))) {
      setState(() {
        erroValidacao =
            'Séries e repetições devem ser maiores que zero. A carga não pode '
            'ser negativa, as metas devem ser válidas e o descanso deve ficar '
            'entre 0 e $descansoMaximoSegundos segundos.';
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
        cargaKg: pesoCorporal
            ? 0
            : PreferenciaUnidadeCarga.instancia.paraKg(carga),
        descansoSegundos: descanso,
        pesoCorporal: pesoCorporal,
        instrucoes: instrucoesController.text.trim(),
        metaCargaKg: pesoCorporal || metaCarga == null
            ? null
            : PreferenciaUnidadeCarga.instancia.paraKg(metaCarga),
        metaRepeticoes: metaRepeticoes,
        progressaoAtiva: progressaoAtiva,
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
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sugerir progressão'),
              subtitle: const Text(
                'Ajustes de carga ou repetições exigem sua confirmação.',
              ),
              value: progressaoAtiva,
              onChanged: (valor) => setState(() => progressaoAtiva = valor),
            ),
            const SizedBox(height: 8),
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
              enabled: !pesoCorporal,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: false,
              ),
              decoration: InputDecoration(
                labelText:
                    'Carga (${PreferenciaUnidadeCarga.instancia.rotulo})',
                hintText: '0 para peso corporal ou não informado',
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Exercício com peso corporal'),
              value: pesoCorporal,
              onChanged: (valor) {
                setState(() => pesoCorporal = valor ?? false);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descansoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Descanso entre séries (segundos)',
                helperText: 'Máximo: 3600 segundos',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Metas de progressão (opcional)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: metaCargaController,
                    enabled: !pesoCorporal,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: false,
                    ),
                    decoration: InputDecoration(
                      labelText:
                          'Meta de carga (${PreferenciaUnidadeCarga.instancia.rotulo})',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: metaRepeticoesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Meta de repetições',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: instrucoesController,
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 5,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Instruções para este exercício',
                hintText: 'Dicas de execução, amplitude ou ritmo',
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
  final Map<String, double> cargasMaximasAnteriores;
  final List<Exercicio> exercicios;
  final Future<List<ExercicioPredefinido>> Function()? carregarCatalogo;

  const ExecucaoTreinoPage({
    super.key,
    required this.sessaoInicial,
    required this.onSalvar,
    this.cargasMaximasAnteriores = const {},
    this.exercicios = const [],
    this.carregarCatalogo,
  });

  @override
  State<ExecucaoTreinoPage> createState() => _ExecucaoTreinoPageState();
}

class _ExecucaoTreinoPageState extends State<ExecucaoTreinoPage>
    with WidgetsBindingObserver {
  late SessaoTreino sessao;
  bool salvando = false;
  bool finalizando = false;
  Future<List<ExercicioPredefinido>>? _catalogo;

  Future<List<ExercicioPredefinido>> get catalogo => _catalogo ??=
      (widget.carregarCatalogo ?? CatalogoExercicios.instancia.carregar)();

  String? catalogoIdPara(SerieExecutada serie) {
    if (serie.catalogoId != null) return serie.catalogoId;
    for (final exercicio in widget.exercicios) {
      if (exercicio.id == serie.exercicioId) return exercicio.catalogoId;
    }
    return null;
  }

  Future<void> vincularDemonstracao(
    String exercicioId,
    String catalogoId,
  ) async {
    if (salvando || finalizando || sessao.finalizada) return;
    final anterior = sessao;
    final atualizada = sessao.copiar(
      series: sessao.series
          .map(
            (serie) => serie.exercicioId == exercicioId
                ? serie.copiar(catalogoId: catalogoId)
                : serie,
          )
          .toList(),
    );
    setState(() {
      salvando = true;
      sessao = atualizada;
    });
    try {
      await widget.onSalvar(atualizada);
    } catch (erro, stackTrace) {
      debugPrint('Erro ao vincular demonstração: $erro');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() => sessao = anterior);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível salvar a demonstração. Tente novamente.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  bool _escutando = false;

  Future<void> _ouvirComando() async {
    if (_escutando) {
      await EscutaVoz.instancia.parar();
      if (mounted) setState(() => _escutando = false);
      return;
    }
    setState(() => _escutando = true);
    final erro = await EscutaVoz.instancia.escutar((comando, texto) {
      if (!mounted) return;
      setState(() => _escutando = false);
      unawaited(_executarComando(comando, texto));
    });
    if (erro != null && mounted) {
      setState(() => _escutando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  Future<void> _executarComando(ComandoVoz? comando, String texto) async {
    if (comando == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            texto.isEmpty
                ? 'Não ouvi nada. Tente de novo ou use os botões.'
                : 'Não entendi "$texto". Diga: pausar, continuar, próximo, '
                      'série concluída ou finalizar.',
          ),
        ),
      );
      return;
    }
    switch (comando) {
      case ComandoVoz.pausar:
        pausarDescanso();
      case ComandoVoz.retomar:
        retomarDescanso();
      case ComandoVoz.proximo:
        if (descansoAtivo) encerrarDescanso();
        final proxima = _proximaSeriePendente();
        if (proxima != null) {
          unawaited(VozTreinador.instancia.falar(_fraseProximaSerie(proxima)));
        }
      case ComandoVoz.repetir:
        final atual = _proximaSeriePendente();
        if (atual != null) {
          unawaited(VozTreinador.instancia.falar(_fraseProximaSerie(atual)));
        }
      case ComandoVoz.serieConcluida:
        final atual = _proximaSeriePendente();
        if (atual != null) await alternarSerie(atual);
      case ComandoVoz.finalizar:
        await finalizarTreino();
    }
  }

  Timer? temporizador;

  int descansoTotal = 60;
  int segundosRestantes = 60;
  DateTime? _descansoTerminaEm;

  bool descansoAtivo = false;
  bool descansoPausado = false;
  @override
  void initState() {
    super.initState();
    sessao = widget.sessaoInicial;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && descansoAtivo) {
      _atualizarDescanso();
    }
  }

  void iniciarDescanso(int duracaoSegundos) {
    temporizador?.cancel();

    if (duracaoSegundos > descansoMaximoSegundos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'O descanso salvo excede 60 minutos; a contagem foi limitada a 60 minutos.',
          ),
        ),
      );
    }
    final int duracao = duracaoSegundos
        .clamp(0, descansoMaximoSegundos)
        .toInt();

    if (duracao == 0) {
      setState(() {
        descansoTotal = 0;
        segundosRestantes = 0;
        descansoAtivo = false;
        descansoPausado = false;
        _descansoTerminaEm = null;
      });
      return;
    }

    setState(() {
      descansoTotal = duracao;
      segundosRestantes = duracao;
      descansoAtivo = true;
      descansoPausado = false;
      _descansoTerminaEm = DateTime.now().add(Duration(seconds: duracao));
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

      _atualizarDescanso();
    });
  }

  void _atualizarDescanso() {
    final terminaEm = _descansoTerminaEm;
    if (!mounted || terminaEm == null) return;

    final restante = terminaEm.difference(DateTime.now()).inSeconds;
    if (restante <= 0) {
      temporizador?.cancel();
      setState(() {
        segundosRestantes = 0;
        descansoAtivo = false;
        descansoPausado = false;
        _descansoTerminaEm = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Descanso finalizado! Próxima série.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (restante != segundosRestantes) {
      setState(() => segundosRestantes = restante);
    }
  }

  void pausarDescanso() {
    if (!descansoAtivo || descansoPausado) return;

    temporizador?.cancel();
    final terminaEm = _descansoTerminaEm;
    final restante = terminaEm == null
        ? segundosRestantes
        : terminaEm
              .difference(DateTime.now())
              .inSeconds
              .clamp(0, descansoTotal)
              .toInt();

    setState(() {
      segundosRestantes = restante;
      descansoPausado = true;
      _descansoTerminaEm = null;
    });
  }

  void retomarDescanso() {
    if (!descansoAtivo || !descansoPausado) return;

    setState(() {
      descansoPausado = false;
      _descansoTerminaEm = DateTime.now().add(
        Duration(seconds: segundosRestantes),
      );
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
      _descansoTerminaEm = null;
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String formatarCarga(double carga, {bool pesoCorporal = false}) {
    return PreferenciaUnidadeCarga.instancia.formatar(
      carga,
      pesoCorporal: pesoCorporal,
    );
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
    setState(() {
      finalizando = true;
      descansoAtivo = false;
      descansoPausado = false;
      _descansoTerminaEm = null;
    });

    try {
      final esforco = sessao.treinoId.startsWith('workfit_')
          ? await showDialog<EsforcoWorkFit>(
              context: context,
              barrierDismissible: false,
              builder: (_) => const WorkFitEsforcoDialog(),
            )
          : null;
      if (!mounted) return;
      final encerrada = sessao.copiar(
        fim: DateTime.now(),
        rpe: esforco?.rpe,
        rir: esforco?.rir,
      );
      setState(() => sessao = encerrada);
      await widget.onSalvar(encerrada);
      unawaited(VozTreinador.instancia.falar(MensagensVoz.treinoFinalizado()));
      try {
        await RecordesPessoaisBanco.instancia.registrarRecordesAutomaticos(
          sessaoId: encerrada.id,
          data: encerrada.fim ?? DateTime.now(),
          series: encerrada.series.map((serie) => serie.toJson()).toList(),
        );
        SincronizacaoUsuario.instancia.agendarEnvio();
      } catch (erro, stackTrace) {
        debugPrint('Erro ao registrar recordes pessoais: ');
        debugPrintStack(stackTrace: stackTrace);
      }

      if (!mounted) return;

      await Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute(
          builder: (_) => ResumoTreinoPage(
            sessao: encerrada,
            cargasMaximasAnteriores: widget.cargasMaximasAnteriores,
          ),
        ),
      );
    } catch (erro) {
      if (!mounted) return;

      setState(() {
        sessao = sessaoAnterior;
        finalizando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao concluir o treino: $erro')),
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
    if (serie.descansoSegundos > 0) {
      unawaited(
        VozTreinador.instancia.falar(
          MensagensVoz.descansoIniciado(serie.descansoSegundos),
        ),
      );
    }
  }

  SerieExecutada? _proximaSeriePendente() {
    for (final s in sessao.series) {
      if (!s.concluida) return s;
    }
    return null;
  }

  String _fraseProximaSerie(SerieExecutada s) {
    final total = sessao.series
        .where((x) => x.exercicioId == s.exercicioId)
        .length;
    return MensagensVoz.exercicioAtual(
      nome: s.nomeExercicio,
      serie: s.numeroSerie,
      totalSeries: total,
      repeticoes: s.repeticoesPlanejadas,
      cargaKg: s.cargaKg,
    );
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
    await finalizarAutomaticamente();
  }

  Widget construirSerie(SerieExecutada serie) {
    final bloqueada = salvando || finalizando || sessao.finalizada;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 5, 12, 7),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: serie.concluida
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: serie.concluida
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
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
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: serie.concluida
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.onPrimary,
                      )
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
                      '${formatarCarga(serie.cargaKg, pesoCorporal: serie.pesoCorporal)}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
                backgroundColor: serie.concluida
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : Theme.of(context).colorScheme.primary,
                foregroundColor: serie.concluida
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : Theme.of(context).colorScheme.onPrimary,
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
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: verde.withValues(alpha: 0.55)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined, color: verde),
              SizedBox(width: 8),
              Text(
                'TEMPO DE DESCANSO',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            formatarTempo(segundosRestantes),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
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
              color: Theme.of(context).colorScheme.primary,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest,
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
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (descansoPausado) ...[
            const SizedBox(height: 8),
            Text(
              'Descanso pausado',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
        actions: [
          IconButton(
            tooltip: _escutando ? 'Ouvindo...' : 'Comando de voz (opcional)',
            icon: Icon(_escutando ? Icons.mic : Icons.mic_none),
            onPressed: _ouvirComando,
          ),
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
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'Seu progresso',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        '$percentual%',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
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
                      color: Theme.of(context).colorScheme.primary,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  if (sessao.finalizada) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Sessão finalizada',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
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
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontSize: 13,
                                            ),
                                          ),
                                          if (primeira.instrucoes
                                              .trim()
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              primeira.instrucoes,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          ],
                                          if (primeira.metaCargaKg != null ||
                                              primeira.metaRepeticoes !=
                                                  null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Meta: ${[if (primeira.metaCargaKg case final metaCarga?) formatarCarga(metaCarga), if (primeira.metaRepeticoes case final metaRepeticoes?) '$metaRepeticoes repetições'].join(' • ')}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary,
                                                  ),
                                            ),
                                          ],
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
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              DemonstracaoExercicio(
                                catalogoId: catalogoIdPara(primeira),
                                nomeExercicio: primeira.nomeExercicio,
                                carregarCatalogo: () => catalogo,
                                habilitado:
                                    !salvando &&
                                    !finalizando &&
                                    !sessao.finalizada,
                                onSelecionar: (id) => vincularDemonstracao(
                                  primeira.exercicioId,
                                  id,
                                ),
                              ),
                              ...series.map(construirSerie),
                              const SizedBox(height: 5),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            if (salvando || finalizando)
              LinearProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
                minHeight: 3,
              ),
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
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
  final Map<String, double> cargasMaximasAnteriores;

  const ResumoTreinoPage({
    super.key,
    required this.sessao,
    this.cargasMaximasAnteriores = const {},
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
    final percentual = total == 0 ? 0 : (concluidas * 100 / total).round();

    final fim = sessao.fim ?? DateTime.now();
    final duracao = fim.difference(sessao.inicio);
    final agrupadas = <String, List<SerieExecutada>>{};

    for (final serie in sessao.series) {
      agrupadas.putIfAbsent(serie.exercicioId, () => []).add(serie);
    }

    final exerciciosConcluidos = agrupadas.values.where((series) {
      return series.every((serie) => serie.concluida);
    }).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Resumo do treino')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Icon(Icons.emoji_events_outlined, size: 64, color: verde),
            const SizedBox(height: 12),
            Text(
              'Treino concluído!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              sessao.nomeTreino,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Text(
                      '$percentual%',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Text('Conclusão do treino'),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: total == 0 ? 0 : concluidas / total,
                      color: Theme.of(context).colorScheme.primary,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      minHeight: 8,
                    ),
                    const SizedBox(height: 20),
                    _itemResumo(
                      context,
                      'Séries concluídas',
                      '$concluidas de $total',
                    ),
                    _itemResumo(
                      context,
                      'Exercícios concluídos',
                      '$exerciciosConcluidos de ${agrupadas.length}',
                    ),
                    _itemResumo(context, 'Duração', formatarDuracao(duracao)),
                    _itemResumo(context, 'Início', formatarData(sessao.inicio)),
                    _itemResumo(context, 'Término', formatarData(fim)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (sessao.anotacoes.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Anotações',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(sessao.anotacoes),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Detalhamento por exercício',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...agrupadas.entries.map((entrada) {
              final series = entrada.value;
              final feitas = series.where((serie) => serie.concluida).length;
              final maiorCargaAtual = series
                  .where((serie) => serie.concluida)
                  .fold<double>(
                    0,
                    (maior, serie) =>
                        serie.cargaKg > maior ? serie.cargaKg : maior,
                  );
              final maiorCargaAnterior =
                  cargasMaximasAnteriores[entrada.key] ?? 0;
              final novoRecorde =
                  maiorCargaAtual > maiorCargaAnterior && maiorCargaAtual > 0;

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
                      if (novoRecorde) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              Icons.emoji_events,
                              size: 17,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Novo recorde de carga!',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 5),
                      Text('$feitas de ${series.length} séries concluídas'),
                      const Divider(),
                      ...series.map((serie) {
                        final carga = PreferenciaUnidadeCarga.instancia
                            .formatar(
                              serie.cargaKg,
                              pesoCorporal: serie.pesoCorporal,
                            );

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
                                    : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
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
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemResumo(BuildContext context, String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              titulo,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
  bool pesoCorporal = false;

  @override
  void initState() {
    super.initState();
    pesoCorporal = widget.serie.pesoCorporal;
    repeticoesController = TextEditingController(
      text: '${widget.serie.repeticoesRealizadas}',
    );
    final cargaExibida = PreferenciaUnidadeCarga.instancia.deKg(
      widget.serie.cargaKg,
    );
    cargaController = TextEditingController(
      text: cargaExibida.toStringAsFixed(cargaExibida % 1 == 0 ? 0 : 1),
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
      widget.serie.copiar(
        repeticoesRealizadas: repeticoes,
        cargaKg: pesoCorporal
            ? 0
            : PreferenciaUnidadeCarga.instancia.paraKg(carga),
        pesoCorporal: pesoCorporal,
      ),
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
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Meta: ${widget.serie.repeticoesPlanejadas} repetições',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
              enabled: !pesoCorporal,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: false,
              ),
              decoration: InputDecoration(
                labelText:
                    'Carga utilizada (${PreferenciaUnidadeCarga.instancia.rotulo})',
                hintText: '0 para peso corporal ou não informado',
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Exercício com peso corporal'),
              value: pesoCorporal,
              onChanged: (valor) {
                setState(() => pesoCorporal = valor ?? false);
              },
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
  final Future<int> Function(List<ExercicioPredefinido>) onAdicionar;

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
  String _equipamentoSelecionado = 'Todos os equipamentos';
  final Set<String> _adicionadosNestaSessao = {};
  final Set<String> _processando = {};
  late final Set<String> _idsCadastrados;
  bool _adicionandoEmLote = false;
  List<ExercicioPredefinido> _catalogo = const [];
  String? _erroCatalogo;

  List<String> get _grupos {
    final grupos =
        _catalogo.map((exercicio) => exercicio.grupo).toSet().toList()..sort();
    return ['Todos', ...grupos];
  }

  List<String> get _equipamentos {
    return _catalogo
        .map((exercicio) => exercicio.equipamentoParaFiltro)
        .toSet()
        .toList()
      ..sort();
  }

  @override
  void initState() {
    super.initState();
    _idsCadastrados = widget.exerciciosCadastrados
        .map((exercicio) => exercicio.catalogoId)
        .whereType<String>()
        .toSet();
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

  String _chave(ExercicioPredefinido exercicio) => exercicio.id;

  bool _jaCadastrado(ExercicioPredefinido exercicio) {
    final chave = _chave(exercicio);
    final nomeNormalizado = exercicio.nome.trim().toLowerCase();

    return _idsCadastrados.contains(chave) ||
        _adicionadosNestaSessao.contains(chave) ||
        widget.exerciciosCadastrados.any((item) {
          final nomeExistente = item.nome.trim().toLowerCase();
          return (nomeExistente == nomeNormalizado ||
                  nomeExistente.startsWith('$nomeNormalizado (')) &&
              item.grupo.trim().toLowerCase() ==
                  exercicio.grupo.trim().toLowerCase();
        });
  }

  List<ExercicioPredefinido> get _exerciciosFiltrados {
    final busca = _buscaController.text.trim().toLowerCase();

    return _catalogo.where((exercicio) {
      final correspondeGrupo =
          _grupoSelecionado == 'Todos' || exercicio.grupo == _grupoSelecionado;
      final correspondeEquipamento =
          _equipamentoSelecionado == 'Todos os equipamentos' ||
          exercicio.equipamentoParaFiltro == _equipamentoSelecionado;

      final termosBusca = [
        exercicio.nome,
        exercicio.nomeOriginal,
        exercicio.grupo,
        exercicio.equipamento,
        exercicio.equipamentoParaFiltro,
        exercicio.categoria,
        ...exercicio.musculosPrimarios,
        ...exercicio.musculosSecundarios,
      ].join(' ').toLowerCase();

      final correspondeBusca = termosBusca.contains(busca);

      return correspondeGrupo && correspondeEquipamento && correspondeBusca;
    }).toList();
  }

  Future<void> _adicionar(ExercicioPredefinido exercicio) async {
    final chave = exercicio.id;

    if (_jaCadastrado(exercicio) ||
        _processando.contains(chave) ||
        _adicionandoEmLote) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esse exercício já está cadastrado.')),
      );
      return;
    }

    setState(() => _processando.add(chave));

    try {
      final quantidade = await widget.onAdicionar([exercicio]);

      if (!mounted) return;

      setState(() {
        _processando.remove(chave);
        if (quantidade > 0) {
          _adicionadosNestaSessao.add(chave);
          _idsCadastrados.add(chave);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            quantidade > 0
                ? '${exercicio.nomeComNomeOriginal} adicionado ao acervo!'
                : 'Esse exercício já está cadastrado.',
          ),
        ),
      );
    } catch (erro, stackTrace) {
      debugPrint('Erro ao adicionar exercício do catálogo: $erro');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;

      setState(() => _processando.remove(chave));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível adicionar o exercício.'),
        ),
      );
    }
  }

  Future<void> _adicionarTodos() async {
    if (_adicionandoEmLote || _processando.isNotEmpty) return;
    final pendentes = _catalogo
        .where((exercicio) => !_jaCadastrado(exercicio))
        .toList();
    if (pendentes.isEmpty) return;
    final jaCadastrados = _catalogo.length - pendentes.length;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Adicionar todo o catálogo?'),
        content: Text(
          'Serão adicionados até ${pendentes.length} exercícios do catálogo, '
          'inclusive os que não aparecem nos filtros atuais. $jaCadastrados '
          'já estão vinculados ao catálogo e serão mantidos. Cadastros '
          'antigos sem vínculo serão preservados e podem ter nomes repetidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Adicionar todos'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() => _adicionandoEmLote = true);
    try {
      final adicionados = await widget.onAdicionar(pendentes);
      if (!mounted) return;
      setState(() {
        _adicionadosNestaSessao.addAll(pendentes.map((item) => item.id));
        _idsCadastrados.addAll(pendentes.map((item) => item.id));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$adicionados exercícios adicionados. '
            '${_catalogo.length - adicionados} já estavam no acervo.',
          ),
        ),
      );
    } catch (erro, stackTrace) {
      debugPrint('Erro ao adicionar catálogo: $erro');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível adicionar o catálogo. Nenhuma alteração foi salva.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _adicionandoEmLote = false);
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
                exercicio.nomeComNomeOriginal,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: iconeGrupo(exercicio.grupo, size: 18),
                    label: Text(exercicio.grupo),
                  ),
                  Chip(
                    avatar: iconeEquipamento(
                      exercicio.equipamentoParaFiltro,
                      size: 18,
                    ),
                    label: Text(exercicio.equipamentoParaFiltro),
                  ),
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
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            alignment: Alignment.center,
                            child: Image.asset(
                              caminho,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              errorBuilder: (context, erro, stackTrace) {
                                return const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.image_not_supported_outlined,
                                      size: 42,
                                    ),
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
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
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
                  'Como executar',
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
              Text(
                'Use uma carga que permita manter o controle do movimento. '
                'Interrompa se sentir dor e procure orientação profissional '
                'para aprender variações técnicas.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Dados: Free Exercise DB (Unlicense/public domain).',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
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
        appBar: AppBar(title: const Text('Biblioteca de exerc?cios')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 44),
                const SizedBox(height: 12),
                const Text(
                  'N?o foi poss?vel abrir o cat?logo de exerc?cios.',
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
        appBar: AppBar(title: const Text('Biblioteca de exerc?cios')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final filtrados = _exerciciosFiltrados;
    final pendentes = _catalogo
        .where((exercicio) => !_jaCadastrado(exercicio))
        .length;

    return PopScope(
      canPop: !_adicionandoEmLote,
      child: Scaffold(
        appBar: AppBar(title: const Text('Biblioteca de exerc?cios')),
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
              child: DropdownButtonFormField<String>(
                initialValue: _equipamentoSelecionado,
                decoration: const InputDecoration(labelText: 'Equipamento'),
                items: [
                  const DropdownMenuItem(
                    value: 'Todos os equipamentos',
                    child: Text('Todos os equipamentos'),
                  ),
                  ..._equipamentos.map(
                    (equipamento) => DropdownMenuItem<String>(
                      value: equipamento,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          iconeEquipamento(equipamento, size: 20),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 220,
                            child: Text(
                              equipamento,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                onChanged: (equipamento) {
                  if (equipamento != null) {
                    setState(() => _equipamentoSelecionado = equipamento);
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${filtrados.length} de ${_catalogo.length} exercícios disponíveis',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      _adicionandoEmLote ||
                          _processando.isNotEmpty ||
                          pendentes == 0
                      ? null
                      : _adicionarTodos,
                  icon: const Icon(Icons.library_add),
                  label: Text('Adicionar todos ($pendentes restantes)'),
                ),
              ),
            ),
            if (_adicionandoEmLote) ...[
              const LinearProgressIndicator(),
              const Text('Adicionando exercícios. Aguarde...'),
            ],
            Expanded(
              child: filtrados.isEmpty
                  ? const Center(child: Text('Nenhum exercício encontrado.'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: filtrados.length,
                      itemBuilder: (context, index) {
                        final exercicio = filtrados[index];
                        final cadastrado = _jaCadastrado(exercicio);
                        final processando = _processando.contains(exercicio.id);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            onTap: () => _mostrarDetalhes(exercicio),
                            leading: CircleAvatar(
                              child: iconeGrupo(exercicio.grupo, size: 22),
                            ),
                            title: Text(
                              exercicio.nomeComNomeOriginal,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${exercicio.grupo} • ${exercicio.equipamentoParaFiltro}'
                              '${exercicio.nivel.isEmpty ? '' : ' • ${exercicio.nivel}'}',
                            ),
                            trailing: cadastrado
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                : IconButton(
                                    tooltip: 'Adicionar exercício',
                                    onPressed: processando || _adicionandoEmLote
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
      ),
    );
  }
}
