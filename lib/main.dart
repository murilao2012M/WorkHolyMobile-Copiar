import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' hide Icon;

import 'painel/w_icone.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'dados/workholy_banco.dart';
import 'perfil_praticante_page.dart';
import 'aparencia/workholy_aparencia.dart';
import 'aparencia/aparencia_page.dart';
import 'painel/componentes_painel.dart';
import 'preferencias/preferencias_treino_page.dart';
import 'tutorial_primeiro_acesso_page.dart';
import 'exercicios/biblioteca_exercicios.dart';
import 'exercicios/demonstracao_exercicio.dart';
import 'exercicios/aviso_atividade_fisica.dart';
import 'corrida/corrida_banco.dart';
import 'corrida/corrida_page.dart';
import 'edicao_app.dart';
import 'alunos/aluno.dart';
import 'alunos/alunos_page.dart';
import 'alunos/ficha_aluno_page.dart';
import 'alunos/painel_alunos.dart';
import 'agenda/agenda_page.dart';
import 'agenda/agendamento.dart';
import 'agenda/avisos_agenda.dart';
import 'lembretes/lembretes_treino.dart';
import 'modo_exercicio.dart';
import 'textos_legais_personal.dart';
import 'alunos/resumo_aluno.dart';
import 'package:image_picker/image_picker.dart';
import 'midia/midia_exercicio.dart';
import 'midia/midias_widgets.dart';
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

const Color verde = Color(0xFFC6F432);
const Color fundo = Color(0xFF0A0B10);
const Color superficie = Color(0xFF12141A);
const Color textoSecundario = Color(0xFF9AA0AB);

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
  final WorkFitCiclo? workfitCiclo;

  // Aluno do personal (edição Personal); nulo nos treinos pessoais.
  final String? alunoId;

  Treino({
    String? id,
    required this.nome,
    required this.objetivo,
    this.exercicios = 0,
    this.workfitCiclo,
    this.alunoId,
  }) : id = id ?? novoId('treino');

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'objetivo': objetivo,
    'exercicios': exercicios,
    if (workfitCiclo != null) 'workfitCiclo': workfitCiclo!.toJson(),
    if (alunoId != null) 'alunoId': alunoId,
  };

  factory Treino.fromJson(Map<String, dynamic> json) {
    return Treino(
      id: json['id'] is String ? json['id'] as String : null,
      alunoId: json['alunoId'] is String ? json['alunoId'] as String : null,
      nome: json['nome']?.toString() ?? 'Treino sem nome',
      objetivo: json['objetivo']?.toString() ?? '',
      exercicios: (json['exercicios'] as num?)?.toInt() ?? 0,
      workfitCiclo: json['workfitCiclo'] == null
          ? null
          : WorkFitCiclo.fromJson(
              Map<String, dynamic>.from(json['workfitCiclo'] as Map),
            ),
    );
  }
}

class Exercicio {
  final String id;
  final String nome;
  final String grupo;
  final int series;
  final int repeticoes;
  final String? catalogoId;
  final List<MidiaExercicio> midias;

  Exercicio({
    String? id,
    required this.nome,
    required this.grupo,
    required this.series,
    required this.repeticoes,
    this.catalogoId,
    this.midias = const [],
  }) : id = id ?? novoId('exercicio');

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'grupo': grupo,
    'series': series,
    'repeticoes': repeticoes,
    if (catalogoId != null) 'catalogoId': catalogoId,
    if (midias.isNotEmpty) 'midias': midias.map((m) => m.toJson()).toList(),
  };

  factory Exercicio.fromJson(Map<String, dynamic> json) {
    return Exercicio(
      id: json['id'] is String ? json['id'] as String : null,
      nome: json['nome']?.toString() ?? 'Exercício sem nome',
      grupo: json['grupo']?.toString() ?? 'Outros',
      series: (json['series'] as num?)?.toInt() ?? 3,
      repeticoes: (json['repeticoes'] as num?)?.toInt() ?? 12,
      catalogoId: json['catalogoId'] as String?,
      midias: json['midias'] is List
          ? (json['midias'] as List)
                .map(MidiaExercicio.fromJson)
                .whereType<MidiaExercicio>()
                .toList()
          : const [],
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
  final bool progressaoAtiva;
  final String? workfitUltimaSessaoAjustada;
  final String? workfitCicloRecuperado;
  final ModoExercicio modo;
  final int duracaoSegundos;

  ItemTreino({
    String? id,
    required this.treinoId,
    required this.exercicioId,
    required this.series,
    required this.repeticoes,
    required this.cargaKg,
    required this.descansoSegundos,
    this.progressaoAtiva = true,
    this.workfitUltimaSessaoAjustada,
    this.workfitCicloRecuperado,
    this.modo = ModoExercicio.carga,
    this.duracaoSegundos = 0,
  }) : id = id ?? novoId('item');

  Map<String, dynamic> toJson() => {
    'id': id,
    'treinoId': treinoId,
    'exercicioId': exercicioId,
    'series': series,
    'repeticoes': repeticoes,
    'cargaKg': cargaKg,
    'descansoSegundos': descansoSegundos,
    'progressaoAtiva': progressaoAtiva,
    if (modo != ModoExercicio.carga) 'modo': modo.name,
    if (duracaoSegundos > 0) 'duracaoSegundos': duracaoSegundos,
    if (workfitUltimaSessaoAjustada != null)
      'workfitUltimaSessaoAjustada': workfitUltimaSessaoAjustada,
    if (workfitCicloRecuperado != null)
      'workfitCicloRecuperado': workfitCicloRecuperado,
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
      progressaoAtiva: json['progressaoAtiva'] as bool? ?? true,
      modo: ModoExercicio.deNome(json['modo']),
      duracaoSegundos: (json['duracaoSegundos'] as num?)?.toInt() ?? 0,
      workfitUltimaSessaoAjustada:
          json['workfitUltimaSessaoAjustada'] as String?,
      workfitCicloRecuperado: json['workfitCicloRecuperado'] as String?,
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
  final String? catalogoId;
  final ModoExercicio modo;
  final int duracaoPlanejadaSegundos;
  final int duracaoRealizadaSegundos;

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
    this.catalogoId,
    this.modo = ModoExercicio.carga,
    this.duracaoPlanejadaSegundos = 0,
    this.duracaoRealizadaSegundos = 0,
  });

  SerieExecutada copiar({
    int? repeticoesRealizadas,
    double? cargaKg,
    bool? concluida,
    String? catalogoId,
    int? duracaoRealizadaSegundos,
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
      catalogoId: catalogoId ?? this.catalogoId,
      modo: modo,
      duracaoPlanejadaSegundos: duracaoPlanejadaSegundos,
      duracaoRealizadaSegundos:
          duracaoRealizadaSegundos ?? this.duracaoRealizadaSegundos,
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
    if (catalogoId != null) 'catalogoId': catalogoId,
    if (modo != ModoExercicio.carga) 'modo': modo.name,
    if (duracaoPlanejadaSegundos > 0)
      'duracaoPlanejadaSegundos': duracaoPlanejadaSegundos,
    if (duracaoRealizadaSegundos > 0)
      'duracaoRealizadaSegundos': duracaoRealizadaSegundos,
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
      catalogoId: json['catalogoId'] as String?,
      modo: ModoExercicio.deNome(json['modo']),
      duracaoPlanejadaSegundos:
          (json['duracaoPlanejadaSegundos'] as num?)?.toInt() ?? 0,
      duracaoRealizadaSegundos:
          (json['duracaoRealizadaSegundos'] as num?)?.toInt() ?? 0,
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
  final String? workfitPlanoId;
  final int? rpe;
  final int? rir;

  const SessaoTreino({
    required this.id,
    required this.treinoId,
    required this.nomeTreino,
    required this.inicio,
    required this.fim,
    required this.series,
    this.workfitPlanoId,
    this.rpe,
    this.rir,
  });

  bool get finalizada => fim != null;

  int get seriesConcluidas => series.where((serie) => serie.concluida).length;

  SessaoTreino copiar({
    DateTime? fim,
    bool limparFim = false,
    List<SerieExecutada>? series,
    int? rpe,
    int? rir,
  }) {
    return SessaoTreino(
      id: id,
      treinoId: treinoId,
      nomeTreino: nomeTreino,
      inicio: inicio,
      fim: limparFim ? null : (fim ?? this.fim),
      series: series ?? List<SerieExecutada>.from(this.series),
      workfitPlanoId: workfitPlanoId,
      rpe: rpe ?? this.rpe,
      rir: rir ?? this.rir,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'treinoId': treinoId,
    'nomeTreino': nomeTreino,
    'inicio': inicio.toIso8601String(),
    'fim': fim?.toIso8601String(),
    'series': series.map((serie) => serie.toJson()).toList(),
    if (workfitPlanoId != null) 'workfitPlanoId': workfitPlanoId,
    if (rpe != null) 'rpe': rpe,
    if (rir != null) 'rir': rir,
  };

  factory SessaoTreino.fromJson(Map<String, dynamic> json) {
    final dadosSeries = json['series'] as List<dynamic>? ?? [];
    final rpe = json['rpe'];
    final rir = json['rir'];
    if ((rpe != null && (rpe is! int || rpe < 1 || rpe > 10)) ||
        (rir != null && (rir is! int || rir < 0 || rir > 10))) {
      throw const FormatException('Esforço registrado inválido.');
    }

    return SessaoTreino(
      id: json['id']?.toString() ?? novoId('sessao'),
      treinoId: json['treinoId']?.toString() ?? '',
      nomeTreino: json['nomeTreino']?.toString() ?? 'Treino',
      workfitPlanoId: json['workfitPlanoId'] as String?,
      rpe: rpe as int?,
      rir: rir as int?,
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

  // O Personal usa o app Firebase próprio, lido do google-services.json.
  await (EdicaoApp.personal
      ? Firebase.initializeApp()
      : Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform));

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
              return WorkHolyHome(
                key: ValueKey(usuario.uid),
                aparencia: aparencia,
                usuario: usuario,
              );
            },
          ),
        );
      },
    );
  }
}

class WorkHolyHome extends StatefulWidget {
  const WorkHolyHome({
    super.key,
    required this.aparencia,
    required this.usuario,
  });

  final WorkHolyAparencia aparencia;
  final User usuario;
  @override
  State<WorkHolyHome> createState() => _WorkHolyHomeState();
}

class _WorkHolyHomeState extends State<WorkHolyHome> {
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

  int abaSelecionada = 0;
  List<Aluno> alunos = [];
  List<Agendamento> agenda = [];

  Future<void> recarregarAgenda() async {
    final lista = await AgendaRepositorio.instancia.carregar();
    if (mounted) setState(() => agenda = lista);
    await sincronizarAvisosAgenda(pedirPermissao: true);
  }

  Future<void> sincronizarAvisosAgenda({bool pedirPermissao = false}) async {
    if (!EdicaoApp.personal) return;
    final minutos = await LembretesTreino.instancia.lerAvisoAgenda();
    final avisos = planejarAvisos(
      agenda: agenda,
      nomes: {for (final a in alunos) a.id: a.nome},
      agora: DateTime.now(),
      antecedenciaMin: minutos,
    );
    final erro = await LembretesTreino.instancia.agendarAvisosDaAgenda(
      avisos,
      pedirPermissao: pedirPermissao,
    );
    if (erro != null && pedirPermissao && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  void abrirAgenda() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AgendaPage(
          alunos: List<Aluno>.from(alunos),
          onAlterou: recarregarAgenda,
        ),
      ),
    );
  }
  String? alunoSelecionadoId;

  Aluno? get alunoSelecionado {
    for (final a in alunos) {
      if (a.id == alunoSelecionadoId) return a;
    }
    return null;
  }

  List<Treino> get treinosVisiveis => EdicaoApp.personal && alunoSelecionadoId != null
      ? treinos.where((t) => t.alunoId == alunoSelecionadoId).toList()
      : treinos;

  int contarTreinosDoAluno(String alunoId) =>
      treinos.where((t) => t.alunoId == alunoId).length;

  Future<void> salvarAluno(Aluno aluno) async {
    final indice = alunos.indexWhere((a) => a.id == aluno.id);
    final atualizados = List<Aluno>.from(alunos);
    if (indice >= 0) {
      atualizados[indice] = aluno;
    } else {
      atualizados.add(aluno);
    }
    await AlunosRepositorio.instancia.salvar(atualizados);
    if (mounted) setState(() => alunos = atualizados);
  }

  Future<void> excluirAluno(Aluno aluno) async {
    final atualizados = alunos.where((a) => a.id != aluno.id).toList();
    final treinosAtualizados = [
      for (final t in treinos)
        t.alunoId == aluno.id
            ? Treino(
                id: t.id,
                nome: t.nome,
                objetivo: t.objetivo,
                exercicios: t.exercicios,
                workfitCiclo: t.workfitCiclo,
              )
            : t,
    ];
    await WorkHolyBanco.instancia.salvarDadosTreino(
      treinos: treinosAtualizados.map((t) => t.toJson()).toList(),
      exercicios: exercicios.map((e) => e.toJson()).toList(),
      itensTreino: itensTreino.map((i) => i.toJson()).toList(),
      sessoesTreino: sessoesTreino.map((s) => s.toJson()).toList(),
    );
    await AlunosRepositorio.instancia.salvar(atualizados);
    if (!mounted) return;
    setState(() {
      alunos = atualizados;
      treinos = treinosAtualizados;
      if (alunoSelecionadoId == aluno.id) alunoSelecionadoId = null;
    });
  }

  void abrirFichaAluno(Aluno aluno) {
    final treinosAluno = treinos.where((t) => t.alunoId == aluno.id).toList();
    final idsTreinos = treinosAluno.map((t) => t.id).toSet();
    final sessoesAluno = <SessaoAluno>[
      for (final s in sessoesTreino)
        if (s.finalizada && idsTreinos.contains(s.treinoId))
          SessaoAluno(
            nomeTreino: s.nomeTreino,
            inicio: s.inicio,
            fim: s.fim!,
            seriesConcluidas: s.seriesConcluidas,
            volumeKg: s.series
                .where((x) => x.concluida)
                .fold<double>(0, (t, x) => t + x.repeticoesRealizadas * x.cargaKg),
            cargaMaxima: {
              for (final x in s.series.where((x) => x.concluida))
                x.nomeExercicio: s.series
                    .where((y) => y.concluida && y.nomeExercicio == x.nomeExercicio)
                    .map((y) => y.cargaKg)
                    .reduce((a, b) => a > b ? a : b),
            },
          ),
    ];
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => FichaAlunoPage(
          aluno: aluno,
          treinos: [
            for (final t in treinosAluno)
              TreinoDoAluno(
                t.id,
                t.nome,
                t.objetivo,
                quantidadeExercicios(t.id),
              ),
          ],
          sessoes: sessoesAluno,
          onAbrirTreino: (id) {
            Navigator.of(ctx).pop();
            abrirDetalhesTreino(id);
          },
          onNovoTreino: () {
            Navigator.of(ctx).pop();
            setState(() => alunoSelecionadoId = aluno.id);
            criarOuEditarTreino();
          },
        ),
      ),
    );
  }
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
  }

  @override
  void dispose() {
    SincronizacaoUsuario.instancia.parar();
    _buscaExerciciosController.dispose();
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
    if (!EdicaoApp.corridaHabilitada) return;
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
      if (EdicaoApp.workfitHabilitado && !await _perfilPraticanteCompleto()) {
        if (!mounted) return;
        final salvou = await _abrirEtapaObrigatoria(
          (_) => DadosPessoaisOnboardingPage(nomeInicial: _nomeCliente),
        );
        if (!salvou) return;
        await _atualizarNomeDoPerfil();
      }

      // 3. Primeiro treino, criado pelo WorkFit ou manualmente.
      while (EdicaoApp.workfitHabilitado && mounted && treinos.isEmpty) {
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

  Future<void> verificarWorkFitPrimeiroAcesso({
    bool abrirNovamente = false,
  }) async {
    if (!mounted || !EdicaoApp.workfitHabilitado) return;

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

      // Marca como concluído
      await banco.salvarBooleano(chaveWorkFitConcluido, true);
    } catch (erro, stackTrace) {
      debugPrint('Erro ao verificar WorkFit primeiro acesso: $erro');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível gerar ou salvar o plano WorkFit. Tente novamente.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _procesarSugestoesWorkFit(
    List<WorkFitSugestao> sugestoes,
  ) async {
    // Converte sugestões para modelos do app
    final dados = WorkFitAdapter.converterSugestoes(sugestoes);

    final novosTreinos = dados['treinos']!.map(Treino.fromJson).map((t) {
      if (!EdicaoApp.personal || alunoSelecionadoId == null) return t;
      return Treino(
        id: t.id,
        nome: t.nome,
        objetivo: t.objetivo,
        exercicios: t.exercicios,
        workfitCiclo: t.workfitCiclo,
        alunoId: alunoSelecionadoId,
      );
    }).toList();
    final novosExercicios = dados['exercicios']!
        .map(Exercicio.fromJson)
        .toList();
    final novosItens = dados['itensTreino']!.map(ItemTreino.fromJson).toList();
    await WorkHolyBanco.instancia.salvarDadosTreino(
      treinos: [...treinos, ...novosTreinos].map((t) => t.toJson()).toList(),
      exercicios: [
        ...exercicios,
        ...novosExercicios,
      ].map((e) => e.toJson()).toList(),
      itensTreino: [
        ...itensTreino,
        ...novosItens,
      ].map((i) => i.toJson()).toList(),
      sessoesTreino: sessoesTreino.map((s) => s.toJson()).toList(),
    );
    treinos.addAll(novosTreinos);
    exercicios.addAll(novosExercicios);
    itensTreino.addAll(novosItens);
    SincronizacaoUsuario.instancia.agendarEnvio();

    if (mounted) {
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'WorkFit criou ${dados['treinos']!.length} treino(s) personalizado(s)! 🎯',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
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
      await _carregarRemocoesWorkFit();
      if (EdicaoApp.personal) {
        alunos = await AlunosRepositorio.instancia.carregar();
        agenda = await AgendaRepositorio.instancia.carregar();
        unawaited(sincronizarAvisosAgenda());
      }      unawaited(carregarCorridasDoPainel());
    } on TrocaDeContaBloqueada {
      if (mounted) setState(() => _contaBloqueada = true);
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

        if (!_contaBloqueada) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              verificarTutorialPrimeiroAcesso();
            }
          });
        }
      }
    }
  }

  Future<bool> salvarDados() async {
    try {
      await WorkHolyBanco.instancia.salvarDadosTreino(
        treinos: treinos.map((treino) => treino.toJson()).toList(),
        exercicios: exercicios.map((exercicio) => exercicio.toJson()).toList(),
        itensTreino: itensTreino.map((item) => item.toJson()).toList(),
        sessoesTreino: sessoesTreino.map((sessao) => sessao.toJson()).toList(),
      );
      SincronizacaoUsuario.instancia.agendarEnvio();
      return true;
    } catch (erro) {
      debugPrint('Erro ao salvar dados do WorkHoly: $erro');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao salvar os dados no aparelho.')),
        );
      }
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
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  Future<void> iniciarSessaoTreino(String treinoId) async {
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
            concluida: false,
            catalogoId: indice >= 0 ? exercicios[indice].catalogoId : null,
            modo: item.modo,
            duracaoPlanejadaSegundos: item.duracaoSegundos,
            duracaoRealizadaSegundos: item.duracaoSegundos,
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
      workfitPlanoId: treino.workfitCiclo?.id,
    );

    setState(() => sessoesTreino.add(sessao));
    await salvarDados();

    if (!mounted) return;

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ExecucaoTreinoPage(
          sessaoInicial: sessao,
          onSalvar: salvarSessao,
          exercicios: List<Exercicio>.from(exercicios),
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  Future<void> salvarSessao(SessaoTreino sessao) async {
    final atualizadas = List<SessaoTreino>.from(sessoesTreino);
    final indice = atualizadas.indexWhere((s) => s.id == sessao.id);

    if (indice < 0) {
      atualizadas.add(sessao);
    } else {
      atualizadas[indice] = sessao;
    }

    await WorkHolyBanco.instancia.salvarDadosTreino(
      treinos: treinos.map((item) => item.toJson()).toList(),
      exercicios: exercicios.map((item) => item.toJson()).toList(),
      itensTreino: itensTreino.map((item) => item.toJson()).toList(),
      sessoesTreino: atualizadas.map((item) => item.toJson()).toList(),
    );
    sessoesTreino
      ..clear()
      ..addAll(atualizadas);
    SincronizacaoUsuario.instancia.agendarEnvio();

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
          exercicios: List<Exercicio>.from(exercicios),
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
    await _registrarRemocoesWorkFit(treinoId, novosItens);
    final indice = treinos.indexWhere((t) => t.id == treinoId);
    final treinosAtualizados = List<Treino>.from(treinos);
    if (indice >= 0) {
      final antigo = treinos[indice];
      treinosAtualizados[indice] = Treino(
        id: antigo.id,
        nome: antigo.nome,
        objetivo: antigo.objetivo,
        exercicios: novosItens.length,
        workfitCiclo: antigo.workfitCiclo,
        alunoId: antigo.alunoId,
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
  }

  Future<void> criarOuEditarTreino([Treino? existente]) async {
    final resultado = await showDialog<Treino>(
      context: context,
      builder: (_) => FormularioTreinoDialog(
        existente: existente,
        alunoIdNovo: EdicaoApp.personal ? alunoSelecionadoId : null,
        alunos: EdicaoApp.personal ? alunos : null,
      ),
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

  Future<int> adicionarExerciciosPredefinidos(
    List<ExercicioPredefinido> predefinidos,
  ) async {
    final candidatos = predefinidos
        .map(
          (predefinido) => Exercicio(
            nome: predefinido.nome,
            grupo: predefinido.grupo,
            series: predefinido.series,
            repeticoes: predefinido.repeticoes,
            catalogoId: predefinido.id,
          ).toJson(),
        )
        .toList();
    final adicionados = await WorkHolyBanco.instancia
        .adicionarExerciciosDoCatalogo(candidatos);
    exercicios.addAll(adicionados.map(Exercicio.fromJson));
    if (adicionados.isNotEmpty) {
      SincronizacaoUsuario.instancia.agendarEnvio();
    }
    if (mounted) setState(() {});
    return adicionados.length;
  }

  Future<void> criarOuEditarExercicio([Exercicio? existente]) async {
    final resultado = await showDialog<Exercicio>(
      context: context,
      builder: (_) => FormularioExercicioDialog(existente: existente),
    );

    if (resultado == null || !mounted) return;

    final midiasRemovidas = existente?.midias
            .where(
              (midia) => !resultado.midias.any((nova) => nova.id == midia.id),
            )
            .toList() ??
        const <MidiaExercicio>[];
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

    final salvou = await salvarDados();
    if (!salvou) return;
    for (final midia in midiasRemovidas) {
      try {
        await ArmazenamentoMidia.apagar(midia);
      } catch (erro, stackTrace) {
        debugPrint('Erro ao remover mídia local do exercício: $erro');
        debugPrintStack(stackTrace: stackTrace);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Exercício salvo, mas uma mídia removida não pôde ser apagada deste aparelho.',
              ),
            ),
          );
        }
      }
    }
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

    final exerciciosRemovidos = exercicios
        .where((exercicio) => idsValidos.contains(exercicio.id))
        .toList();
    final exerciciosRestantes = exercicios
        .where((exercicio) => !idsValidos.contains(exercicio.id))
        .toList();
    final itensRestantes = itensTreino
        .where((item) => !idsValidos.contains(item.exercicioId))
        .toList();
    try {
      await WorkHolyBanco.instancia.salvarDadosTreino(
        treinos: treinos.map((t) => t.toJson()).toList(),
        exercicios: exerciciosRestantes.map((e) => e.toJson()).toList(),
        itensTreino: itensRestantes.map((i) => i.toJson()).toList(),
        sessoesTreino: sessoesTreino.map((s) => s.toJson()).toList(),
      );
      SincronizacaoUsuario.instancia.agendarEnvio();
    } catch (erro, stackTrace) {
      debugPrint('Erro ao excluir exercícios: $erro');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível excluir os exercícios. Tente novamente.',
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      exercicios = exerciciosRestantes;
      itensTreino = itensRestantes;
    });
    var falhaAoApagarMidia = false;
    for (final exercicio in exerciciosRemovidos) {
      for (final midia in exercicio.midias) {
        try {
          await ArmazenamentoMidia.apagar(midia);
        } catch (erro, stackTrace) {
          falhaAoApagarMidia = true;
          debugPrint('Erro ao remover mídia local do exercício: $erro');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            falhaAoApagarMidia
                ? 'Exercício removido, mas não foi possível apagar uma mídia deste aparelho.'
                : quantidade == 1
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
    final destinos = [
      const _DestinoNavegacao(
        rotulo: 'Painel',
        icone: Icons.dashboard_outlined,
        iconeSelecionado: Icons.dashboard,
      ),
      if (EdicaoApp.personal)
        const _DestinoNavegacao(
          rotulo: 'Alunos',
          icone: Icons.groups_outlined,
          iconeSelecionado: Icons.groups,
        ),
      const _DestinoNavegacao(
        rotulo: 'Treinos',
        icone: Icons.view_list_outlined,
        iconeSelecionado: Icons.view_list,
      ),
      const _DestinoNavegacao(
        rotulo: 'Exercícios',
        icone: Icons.fitness_center_outlined,
        iconeSelecionado: Icons.fitness_center,
      ),
      if (EdicaoApp.corridaHabilitada)
        const _DestinoNavegacao(
          rotulo: 'Corrida',
          icone: Icons.directions_run_outlined,
          iconeSelecionado: Icons.directions_run,
        ),
      const _DestinoNavegacao(
        rotulo: 'Histórico',
        icone: Icons.history_outlined,
        iconeSelecionado: Icons.history,
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
      if (EdicaoApp.personal)
        AlunosPage(
          alunos: alunos,
          contarTreinos: contarTreinosDoAluno,
          onAbrirTreinos: abrirFichaAluno,
          onSalvar: salvarAluno,
          onExcluir: excluirAluno,
        ),
      construirPaginaTreinos(),
      construirPaginaExercicios(),
      if (EdicaoApp.corridaHabilitada)
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
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.fitness_center, color: verde),
            const SizedBox(width: 10),
            const Text(
              'WorkHoly',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_nomeCliente != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Olá, $_nomeCliente!',
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (EdicaoApp.personal)
            IconButton(
              tooltip: 'Agenda dos alunos',
              icon: const Icon(Icons.event_note_outlined),
              onPressed: abrirAgenda,
            ),
          IconButton(
            tooltip: 'Configurações',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ConfiguracoesPage(
                    aparencia: widget.aparencia,
                    exercicios: List<Exercicio>.from(exercicios),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            BackupAviso(restaurar: restaurarBackup),
            Expanded(
              child: IndexedStack(index: abaSelecionada, children: paginas),
            ),
          ],
        ),
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

  Widget construirPainelPersonal() {
    final alunoPorTreino = {for (final t in treinos) t.id: t.alunoId};
    final sessoes = [
      for (final s in sessoesTreino)
        if (s.finalizada)
          SessaoPainelAluno(
            alunoId: alunoPorTreino[s.treinoId],
            nomeTreino: s.nomeTreino,
            inicio: s.inicio,
            seriesConcluidas: s.seriesConcluidas,
          ),
    ];
    final resumos = resumirPainelPorAluno(
      alunos.map((a) => a.id).toList(),
      sessoes,
      DateTime.now(),
    );
    String nomeDe(ResumoPainelAluno r) {
      for (final a in alunos) {
        if (a.id == r.alunoId) return a.nome;
      }
      return 'Sem aluno';
    }

    String data(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    String hora(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    final comAtividadeHoje = resumos.where((r) => r.hoje.isNotEmpty).toList();
    final agendaHoje = agendamentosDoDia(agenda, DateTime.now());

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          _saudacao,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Acompanhe seus alunos e treinos.',
          style: TextStyle(color: painelTextoSuave),
        ),
        const SizedBox(height: 20),
        const SizedBox(height: 16),
        CartaoPainel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TituloSecaoPainel(
                'Agenda de hoje',
                icone: Icons.event_note_outlined,
                trailing: TextButton(
                  onPressed: abrirAgenda,
                  child: const Text('Abrir agenda'),
                ),
              ),
              const SizedBox(height: 8),
              if (agendaHoje.isEmpty)
                const Text(
                  'Nenhum horário marcado para hoje.',
                  style: TextStyle(color: textoSecundario),
                ),
              for (final a in agendaHoje)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${formatarHora(a.inicio)} • '
                    '${alunos.where((x) => x.id == a.alunoId).map((x) => x.nome).firstOrNull ?? 'Aluno removido'}'
                    '${a.local.isEmpty ? '' : ' • ${a.local}'}',
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CartaoPainel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TituloSecaoPainel(
                'Resumo por aluno',
                icone: Icons.groups_outlined,
              ),
              const SizedBox(height: 12),
              if (resumos.isEmpty)
                const Text(
                  'Cadastre alunos na aba Alunos para acompanhar aqui.',
                  style: TextStyle(color: textoSecundario),
                ),
              for (final r in resumos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nomeDe(r),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              r.ultima == null
                                  ? 'Nenhum treino concluído'
                                  : 'Último treino: ${data(r.ultima!)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: textoSecundario,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${r.concluidos} concluídos',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${r.naSemana} na semana',
                            style: const TextStyle(
                              fontSize: 12,
                              color: textoSecundario,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CartaoPainel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TituloSecaoPainel(
                'Atividades de hoje',
                icone: Icons.today_outlined,
              ),
              const SizedBox(height: 12),
              if (comAtividadeHoje.isEmpty)
                const Text(
                  'Nenhum aluno concluiu treino hoje.',
                  style: TextStyle(color: textoSecundario),
                ),
              for (final r in comAtividadeHoje) ...[
                Text(
                  nomeDe(r),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                for (final s in r.hoje)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${hora(s.inicio)} • ${s.nomeTreino} • '
                      '${s.seriesConcluidas} séries',
                      style: const TextStyle(color: textoSecundario),
                    ),
                  ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        tituloSecao('Meus treinos'),
        const SizedBox(height: 10),
        if (treinos.isEmpty)
          const Text(
            'Nenhum treino cadastrado. Crie o primeiro treino.',
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

  Widget construirPainel() {
    if (EdicaoApp.personal) return construirPainelPersonal();
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
          _nomeCliente == null
              ? 'Complete seu perfil para uma experiência ainda mais pessoal.'
              : 'Vamos acompanhar sua rotina e sua evolução hoje?',
          style: const TextStyle(color: painelTextoSuave),
        ),
        const SizedBox(height: 20),

        if (EdicaoApp.workfitHabilitado) _cartaoTreinoDoDia(),

        if (EdicaoApp.workfitHabilitado) const CartaoPassos(),

        CartaoPainel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TituloSecaoPainel(
                'Progresso da semana',
                icone: Icons.bolt,
                trailing: Text(
                  'Sequência: $sequenciaDias ${sequenciaDias == 1 ? "dia" : "dias"}',
                  style: const TextStyle(fontSize: 12, color: painelTextoSuave),
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
                  AnelProgressoPainel(
                    progresso: _progressoContraAnterior(
                      seriesSemana,
                      seriesSemanaAnterior,
                    ),
                    cor: const Color(0xFF2EE59D),
                    icone: Icons.check_circle_outline,
                    valor: '$seriesSemana',
                    detalhe: 'séries',
                    rotulo: 'Séries',
                  ),
                  if (EdicaoApp.corridaHabilitada)
                    AnelProgressoPainel(
                      progresso: _progressoContraAnterior(
                        kmSemana,
                        kmSemanaAnterior,
                      ),
                      cor: painelRoxo,
                      icone: Icons.directions_run,
                      valor: kmSemana.toStringAsFixed(1).replaceAll('.', ','),
                      detalhe: 'km',
                      rotulo: 'Corrida',
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                EdicaoApp.corridaHabilitada
                    ? 'Séries e corrida: progresso em relação à semana anterior.'
                    : 'Séries: progresso em relação à semana anterior.',
                style: const TextStyle(fontSize: 11, color: painelTextoSuave),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        CartaoPainel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TituloSecaoPainel(
                'Resumo de atividades',
                icone: Icons.insights,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: MetricaPainel(
                      valor: '${sessoesFinalizadas.length}',
                      unidade: '',
                      rotulo: 'Treinos concluídos',
                      icone: Icons.fitness_center,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MetricaPainel(
                      valor: kmTotal.toStringAsFixed(1).replaceAll('.', ','),
                      unidade: 'km',
                      rotulo: 'Distância total',
                      icone: Icons.route,
                      cor: painelRoxo,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MetricaPainel(
                      valor: '${caloriasTotal.round()}',
                      unidade: 'kcal',
                      rotulo: 'Gasto em corridas',
                      icone: Icons.local_fire_department,
                      cor: const Color(0xFFFF7A45),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        CartaoPainel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TituloSecaoPainel(
                'Atividades por dia',
                icone: Icons.bar_chart,
              ),
              const SizedBox(height: 12),
              BarrasSemanaPainel(
                rotulos: dias,
                valores: valoresSemana,
                indiceAtual: agora.weekday - 1,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        CartaoPainel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TituloSecaoPainel(
                'Últimos 6 meses',
                icone: Icons.calendar_view_month,
              ),
              const SizedBox(height: 12),
              BarrasSemanaPainel(
                rotulos: rotulosMeses,
                valores: valoresMeses,
                indiceAtual: 5,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Card(
          color: painelFundoCartao,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: painelBorda),
          ),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: painelLima.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: painelLima.withValues(alpha: 0.35)),
                ),
                child: const Icon(Icons.fitness_center, color: painelLima),
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
                    if (EdicaoApp.personal)
                      Text(
                        alunos
                                .where((a) => a.id == treino.alunoId)
                                .map((a) => 'Aluno: ${a.nome}')
                                .firstOrNull ??
                            'Sem aluno vinculado',
                        style: const TextStyle(
                          color: painelTextoSuave,
                          fontSize: 12,
                        ),
                      ),
                    Text(
                      '$quantidade ${quantidade == 1 ? 'exercício associado' : 'exercícios associados'}',
                      style: const TextStyle(color: painelLima, fontSize: 12),
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
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton.filled(
              onPressed: () => criarOuEditarTreino(),
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                backgroundColor: painelLima,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${treinosVisiveis.length} ${treinosVisiveis.length == 1 ? 'treino cadastrado' : 'treinos cadastrados'}',
          style: const TextStyle(color: painelTextoSuave),
        ),
        if (EdicaoApp.personal) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: alunoSelecionado?.id,
            decoration: const InputDecoration(labelText: 'Aluno'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Todos os treinos'),
              ),
              ...alunos.map(
                (a) => DropdownMenuItem<String?>(
                  value: a.id,
                  child: Text(a.nome),
                ),
              ),
            ],
            onChanged: (id) => setState(() => alunoSelecionadoId = id),
          ),
        ],
        const SizedBox(height: 14),
        if (EdicaoApp.workfitHabilitado) ...[
          FilledButton.icon(
            onPressed: () =>
                verificarWorkFitPrimeiroAcesso(abrirNovamente: true),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Criar plano com WorkFit'),
            style: FilledButton.styleFrom(
              backgroundColor: painelRoxo,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _cartaoAprendizadoWorkFit(),
        ],
        if (treinosVisiveis.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Text(
              'Você ainda não cadastrou treinos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textoSecundario),
            ),
          ),
        ...treinosVisiveis.map((treino) => cartaoTreino(treino)),
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
                    backgroundColor: painelRoxo.withValues(alpha: 0.18),
                    child: iconeGrupo(exercicio.grupo, color: painelLima),
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
                      '${sessao.finalizada ? "Treino concluído" : "Não inicializado"}'
                      ' • $feitas/$total séries',
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
  const ConfiguracoesPage({
    super.key,
    required this.aparencia,
    required this.exercicios,
  });

  final WorkHolyAparencia aparencia;
  final List<Exercicio> exercicios;

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
                if (!EdicaoApp.personal) ...[
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
                                  (e) =>
                                      RecordeExercicio(id: e.id, nome: e.nome),
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
                    leading: const Icon(
                      Icons.notifications_outlined,
                      color: verde,
                    ),
                    title: const Text('Lembretes e voz'),
                    subtitle: const Text('Avisos de treino e voz do treinador'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LembretesPage(),
                        ),
                      );
                    },
                  ),
                ],
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
a orientação de profissionais de saúde ou de educação física. Antes de realizar
exercícios físicos, é importante procurar um médico. O WorkHoly é feito para
amantes do exercício físico e não substitui o acompanhamento de um profissional
de educação física qualificado e registrado no conselho profissional (CREF).

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
            EdicaoApp.personal ? 'Work Holy Personal' : 'WorkHoly Mobile',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            EdicaoApp.personal
                ? 'Controle alunos, treinos, tudo nas palmas de suas mãos.'
                : 'Treinamento, organização e evolução.',
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
                  onTap: () => abrirDocumento(
                    context,
                    'Termos de uso',
                    EdicaoApp.personal
                        ? TextosLegaisPersonal.termosDeUso
                        : termosDeUso,
                  ),
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
                    EdicaoApp.personal
                        ? TextosLegaisPersonal.politicaPrivacidade
                        : politicaPrivacidade,
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

  // Aluno que receberá o treino ao criar um novo.
  final String? alunoIdNovo;

  // Quando informada (edição Personal), o formulário permite escolher o aluno.
  final List<Aluno>? alunos;

  const FormularioTreinoDialog({
    super.key,
    this.existente,
    this.alunoIdNovo,
    this.alunos,
  });

  @override
  State<FormularioTreinoDialog> createState() => _FormularioTreinoDialogState();
}

class _FormularioTreinoDialogState extends State<FormularioTreinoDialog> {
  late final TextEditingController nomeController;
  late final TextEditingController objetivoController;
  String? _alunoId;

  @override
  void initState() {
    super.initState();
    _alunoId = widget.existente == null
        ? widget.alunoIdNovo
        : widget.existente!.alunoId;
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
        workfitCiclo: existente?.workfitCiclo,
        alunoId: widget.alunos == null
            ? (existente?.alunoId ?? widget.alunoIdNovo)
            : _alunoId,
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
            if (widget.alunos != null) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: widget.alunos!.any((a) => a.id == _alunoId)
                    ? _alunoId
                    : null,
                decoration: const InputDecoration(labelText: 'Aluno'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sem aluno'),
                  ),
                  ...widget.alunos!.map(
                    (a) => DropdownMenuItem<String?>(
                      value: a.id,
                      child: Text(a.nome),
                    ),
                  ),
                ],
                onChanged: (id) => setState(() => _alunoId = id),
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
  late List<MidiaExercicio> _midias;
  final List<MidiaExercicio> _adicionadas = [];
  final ImagePicker _picker = ImagePicker();
  bool _confirmado = false;
  bool _anexando = false;

  @override
  void initState() {
    super.initState();

    final exercicio = widget.existente;
    _midias = List.of(exercicio?.midias ?? const []);

    nomeController = TextEditingController(text: exercicio?.nome ?? '');
    grupoController = TextEditingController(text: exercicio?.grupo ?? '');
  }

  @override
  void dispose() {
    // Cancelar o formulário descarta os arquivos copiados nesta sessão.
    if (!_confirmado) {
      for (final m in _adicionadas) {
        ArmazenamentoMidia.apagar(m);
      }
    }
    nomeController.dispose();
    grupoController.dispose();
    super.dispose();
  }

  Future<void> _anexarArquivo(TipoMidia tipo, ImageSource fonte) async {
    if (_anexando) return;
    setState(() => _anexando = true);
    try {
      final escolhido = tipo == TipoMidia.foto
          ? await _picker.pickImage(
              source: fonte,
              maxWidth: 1600,
              imageQuality: 85,
            )
          : await _picker.pickVideo(
              source: fonte,
              maxDuration: const Duration(minutes: 2),
            );
      if (escolhido == null) return;
      final destino = await ArmazenamentoMidia.copiar(
        escolhido.path,
        prefixo: tipo.name,
      );
      final midia = MidiaExercicio(tipo: tipo, destino: destino);
      _adicionadas.add(midia);
      if (mounted) setState(() => _midias.add(midia));
    } catch (erro) {
      debugPrint('Erro ao anexar mídia: $erro');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível anexar o arquivo. Tente de novo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _anexando = false);
    }
  }

  Future<void> _anexarLink() async {
    final controller = TextEditingController();
    final texto = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Link do vídeo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'youtube.com/... ou vimeo.com/...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (texto == null || !mounted) return;
    final uri = validarLinkMidia(texto);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um link http ou https válido.')),
      );
      return;
    }
    final midia = MidiaExercicio(tipo: TipoMidia.link, destino: uri.toString());
    setState(() => _midias.add(midia));
  }

  void _removerMidia(MidiaExercicio midia) {
    setState(() => _midias.removeWhere((m) => m.id == midia.id));
    if (_adicionadas.any((m) => m.id == midia.id)) {
      _adicionadas.removeWhere((m) => m.id == midia.id);
      ArmazenamentoMidia.apagar(midia);
    }
  }

  void salvar() {
    if (_anexando) return;
    final nome = nomeController.text.trim();
    final grupo = grupoController.text.trim();
    if (nome.isEmpty || grupo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome e o grupo muscular.')),
      );
      return;
    }

    _confirmado = true;
    Navigator.of(context).pop(
    Exercicio(
      id: widget.existente?.id,
      nome: nome,
      grupo: grupo,
      series: widget.existente?.series ?? 3,
      repeticoes: widget.existente?.repeticoes ?? 12,
      catalogoId: widget.existente?.catalogoId,
      midias: _midias,
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
            if (EdicaoApp.midiaHabilitada) ...[
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Fotos e vídeos',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Salvos apenas neste aparelho; não entram no backup.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              MidiasDoExercicio(midias: _midias, onRemover: _removerMidia),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Foto'),
                    onPressed: _anexando
                        ? null
                        : () => _anexarArquivo(
                            TipoMidia.foto,
                            ImageSource.gallery,
                          ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: const Text('Câmera'),
                    onPressed: _anexando
                        ? null
                        : () => _anexarArquivo(
                            TipoMidia.foto,
                            ImageSource.camera,
                          ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.video_library_outlined, size: 18),
                    label: const Text('Vídeo'),
                    onPressed: _anexando
                        ? null
                        : () => _anexarArquivo(
                            TipoMidia.video,
                            ImageSource.gallery,
                          ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.link, size: 18),
                    label: const Text('Link'),
                    onPressed: _anexando ? null : _anexarLink,
                  ),
                ],
              ),
              if (_anexando)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(),
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
        ElevatedButton(
          onPressed: _anexando ? null : salvar,
          child: const Text('Salvar'),
        ),
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
      if (item.modo != ModoExercicio.carga ||
          item.workfitUltimaSessaoAjustada == ultima.id ||
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
          if (widget.treino.workfitCiclo?.modalidade != 'corrida')
            IconButton(
              tooltip: 'Sugerir ajustes',
              onPressed: salvando ? null : sugerirAjustes,
              icon: const Icon(Icons.trending_up),
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
                      itemCount:
                          itens.length +
                          (widget.treino.workfitCiclo == null ? 0 : 1),
                      separatorBuilder: (_, indiceSeparador) =>
                          const SizedBox(height: 10),
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
                                          item.modo == ModoExercicio.tempo
                                              ? '${item.series} séries × ${formatarDuracaoCurta(item.duracaoSegundos)}'
                                              : '${item.series} séries × ${item.repeticoes} repetições',
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${item.modo == ModoExercicio.carga ? '${formatarCarga(item.cargaKg)} • ' : ''}Descanso: ${formatarDescanso(item.descansoSegundos)}',
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
  late final TextEditingController duracaoController;
  late bool progressaoAtiva;
  late ModoExercicio modo;

  String? erroValidacao;

  @override
  void initState() {
    super.initState();

    final item = widget.item;
    progressaoAtiva = item.progressaoAtiva;
    modo = item.modo;

    duracaoController = TextEditingController(
      text: '${item.duracaoSegundos > 0 ? item.duracaoSegundos : 60}',
    );
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
    duracaoController.dispose();
    super.dispose();
  }

  void salvar() {
    final series = int.tryParse(seriesController.text.trim());
    final porTempo = modo == ModoExercicio.tempo;
    final comCarga = modo == ModoExercicio.carga;
    final repeticoes = porTempo
        ? 1
        : int.tryParse(repeticoesController.text.trim());
    final cargaTexto = cargaController.text.trim().replaceAll(',', '.');
    final carga = comCarga ? double.tryParse(cargaTexto) : 0.0;
    final descanso = int.tryParse(descansoController.text.trim());
    final duracao = porTempo ? int.tryParse(duracaoController.text.trim()) : 0;

    if (series == null ||
        repeticoes == null ||
        carga == null ||
        descanso == null ||
        duracao == null ||
        series < 1 ||
        repeticoes < 1 ||
        !carga.isFinite ||
        carga < 0 ||
        descanso < 0 ||
        (porTempo && duracao < 1)) {
      setState(() {
        erroValidacao = 'Confira os valores. Séries, repetições e tempo devem ser maiores que zero; carga e descanso não podem ser negativos.';
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
        progressaoAtiva: comCarga && progressaoAtiva,
        modo: modo,
        duracaoSegundos: duracao,
        workfitUltimaSessaoAjustada: item.workfitUltimaSessaoAjustada,
        workfitCicloRecuperado: item.workfitCicloRecuperado,
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
            DropdownButtonFormField<ModoExercicio>(
              initialValue: modo,
              decoration: const InputDecoration(labelText: 'Tipo de exercício'),
              items: [
                for (final m in ModoExercicio.values)
                  DropdownMenuItem(value: m, child: Text(m.rotulo)),
              ],
              onChanged: (valor) {
                if (valor != null) setState(() => modo = valor);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: seriesController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: modo == ModoExercicio.tempo
                          ? 'Vezes'
                          : 'Séries',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: modo == ModoExercicio.tempo
                      ? TextField(
                          controller: duracaoController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Duração (segundos)',
                          ),
                        )
                      : TextField(
                          controller: repeticoesController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Repetições',
                          ),
                        ),
                ),
              ],
            ),
            if (modo == ModoExercicio.carga) ...[
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
            ],
            const SizedBox(height: 12),
            TextField(
              controller: descansoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Descanso entre séries (segundos)',
              ),
            ),
            if (modo == ModoExercicio.carga)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sugerir progressão'),
                subtitle: const Text(
                  'Ajustes de carga ou repetições exigem sua confirmação.',
                ),
                value: progressaoAtiva,
                onChanged: (valor) => setState(() => progressaoAtiva = valor),
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
  final List<Exercicio> exercicios;
  final Future<List<ExercicioPredefinido>> Function()? carregarCatalogo;

  const ExecucaoTreinoPage({
    super.key,
    required this.sessaoInicial,
    required this.onSalvar,
    this.exercicios = const [],
    this.carregarCatalogo,
  });

  @override
  State<ExecucaoTreinoPage> createState() => _ExecucaoTreinoPageState();
}

class _ExecucaoTreinoPageState extends State<ExecucaoTreinoPage> {
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

  bool descansoAtivo = false;
  bool descansoPausado = false;
  @override
  void initState() {
    super.initState();
    sessao = widget.sessaoInicial;
    if (!sessao.finalizada) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final primeira = _proximaSeriePendente();
        if (primeira != null && mounted) {
          unawaited(VozTreinador.instancia.falar(_fraseProximaSerie(primeira)));
        }
      });
    }
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

        final proxima = _proximaSeriePendente();
        unawaited(
          VozTreinador.instancia.falar(
            proxima == null
                ? MensagensVoz.descansoTerminou(null)
                : '${MensagensVoz.descansoTerminou(null)} '
                      '${_fraseProximaSerie(proxima)}',
          ),
        );

        return;
      }

      setState(() {
        segundosRestantes--;
      });
      if (segundosRestantes == 5 && descansoTotal > 10) {
        unawaited(
          VozTreinador.instancia.falar(MensagensVoz.descansoTerminando()),
        );
      }
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
    unawaited(EscutaVoz.instancia.parar());
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
    setState(() {
      finalizando = true;
      descansoAtivo = false;
      descansoPausado = false;
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
        MaterialPageRoute(builder: (_) => ResumoTreinoPage(sessao: encerrada)),
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
    if (s.modo == ModoExercicio.tempo) {
      return '${s.nomeExercicio}. Série ${s.numeroSerie} de $total: '
          '${formatarDuracaoCurta(s.duracaoPlanejadaSegundos)}.';
    }
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

    final sessaoAnterior = sessao;
    setState(() {
      finalizando = true;
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
        MaterialPageRoute(builder: (_) => ResumoTreinoPage(sessao: encerrada)),
      );
    } catch (erro) {
      if (!mounted) return;

      setState(() {
        sessao = sessaoAnterior;
        finalizando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível finalizar o treino: $erro')),
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
                      switch (serie.modo) {
                        ModoExercicio.tempo => formatarDuracaoCurta(
                          serie.duracaoRealizadaSegundos,
                        ),
                        ModoExercicio.repeticoes =>
                          '${serie.repeticoesRealizadas} repetições',
                        ModoExercicio.carga =>
                          '${serie.repeticoesRealizadas} repetições • '
                              '${formatarCarga(serie.cargaKg)}',
                      },
                      style: const TextStyle(color: textoSecundario),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: serie.modo == ModoExercicio.carga
                    ? 'Editar carga e repetições'
                    : 'Editar série',
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
                              if (EdicaoApp.midiaHabilitada)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: MidiasDoExercicio(
                                    midias:
                                        widget.exercicios
                                            .where(
                                              (e) =>
                                                  e.id == primeira.exercicioId,
                                            )
                                            .firstOrNull
                                            ?.midias ??
                                        const [],
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

  const ResumoTreinoPage({super.key, required this.sessao});

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
                    if (sessao.rpe != null)
                      _itemResumo('RPE da sessão', '${sessao.rpe}'),
                    if (sessao.rir != null)
                      _itemResumo('RIR da sessão', '${sessao.rir}'),
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
              final feitas = series.where((serie) => serie.concluida).length;

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
                            : '${serie.cargaKg.toStringAsFixed(serie.cargaKg % 1 == 0 ? 0 : 1)} kg';
                        final detalhe = switch (serie.modo) {
                          ModoExercicio.tempo => formatarDuracaoCurta(
                            serie.duracaoRealizadaSegundos,
                          ),
                          ModoExercicio.repeticoes =>
                            '${serie.repeticoesRealizadas} rep.',
                          ModoExercicio.carga =>
                            '${serie.repeticoesRealizadas} rep. • $carga',
                        };
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
                                  'Série ${serie.numeroSerie} • $detalhe',
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
            child: Text(titulo, style: const TextStyle(color: textoSecundario)),
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
  late final TextEditingController duracaoController;
  String? erro;

  @override
  void initState() {
    super.initState();
    duracaoController = TextEditingController(
      text: '${widget.serie.duracaoRealizadaSegundos}',
    );
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
    duracaoController.dispose();
    super.dispose();
  }

  void salvar() {
    if (widget.serie.modo == ModoExercicio.tempo) {
      final duracao = int.tryParse(duracaoController.text.trim());
      if (duracao == null || duracao < 0) {
        setState(() => erro = 'Informe o tempo em segundos, sem negativos.');
        return;
      }
      Navigator.of(
        context,
      ).pop(widget.serie.copiar(duracaoRealizadaSegundos: duracao));
      return;
    }

    final repeticoes = int.tryParse(repeticoesController.text.trim());
    final carga = widget.serie.modo == ModoExercicio.carga
        ? double.tryParse(cargaController.text.trim().replaceAll(',', '.'))
        : 0.0;

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
    final modo = widget.serie.modo;
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
              modo == ModoExercicio.tempo
                  ? 'Meta: ${formatarDuracaoCurta(widget.serie.duracaoPlanejadaSegundos)}'
                  : 'Meta: ${widget.serie.repeticoesPlanejadas} repetições',
              style: const TextStyle(color: textoSecundario),
            ),
            const SizedBox(height: 16),
            if (modo == ModoExercicio.tempo)
              TextField(
                controller: duracaoController,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tempo realizado (segundos)',
                ),
              )
            else
              TextField(
                controller: repeticoesController,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Repetições realizadas',
                ),
              ),
            if (modo == ModoExercicio.carga) ...[
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
            ],
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

  bool _jaCadastrado(ExercicioPredefinido exercicio) {
    return _adicionadosNestaSessao.contains(exercicio.id) ||
        _idsCadastrados.contains(exercicio.id);
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

        _adicionadosNestaSessao.add(chave);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            quantidade == 1
                ? '${exercicio.nome} adicionado ao acervo!'
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
                exercicio.nome,
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
                    style: const TextStyle(
                      color: textoSecundario,
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

    final pendentes = _catalogo
        .where((exercicio) => !_jaCadastrado(exercicio))
        .length;
    return PopScope(
      canPop: !_adicionandoEmLote,
      child: Scaffold(
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
                      avatar: iconeGrupo(grupo, size: 18),
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
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: DropdownButtonFormField<String>(
                initialValue: _equipamentoSelecionado,
                decoration: const InputDecoration(
                  labelText: 'Equipamento',
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Todos os equipamentos'),
                isExpanded: true,
                items: [
                  DropdownMenuItem<String>(
                    value: 'Todos os equipamentos',
                    child: Row(
                      children: [
                        iconeEquipamento('Todos', size: 20),
                        const SizedBox(width: 10),
                        const Text('Todos os equipamentos'),
                      ],
                    ),
                  ),
                  ..._equipamentos.map(
                    (equipamento) => DropdownMenuItem<String>(
                      value: equipamento,
                      child: Row(
                        children: [
                          iconeEquipamento(equipamento, size: 20),
                          const SizedBox(width: 10),
                          Flexible(
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
                  style: const TextStyle(color: textoSecundario),
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
                              exercicio.nome,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${exercicio.grupo}'
                              ' • ${exercicio.equipamentoParaFiltro}'
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
