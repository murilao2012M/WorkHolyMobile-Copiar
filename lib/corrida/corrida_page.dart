import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' hide Icon;
import 'package:flutter/services.dart';

import 'plano_corrida.dart';
import '../voz/comandos_voz.dart';
import '../voz/escuta_voz.dart';
import '../voz/mensagens_voz.dart';
import '../voz/voz_treinador.dart';
import '../painel/w_icone.dart';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'analise_corrida_page.dart';

import '../dados/workholy_banco.dart';
import '../exercicios/aviso_atividade_fisica.dart';
import '../sincronizacao/sincronizacao_usuario.dart';
import '../workfit/workfit_ciclo.dart';
import '../workfit/workfit_selecao_corrida.dart';
import '../workfit/workfit_esforco_dialog.dart';
import 'corrida_banco.dart';
import 'corrida_servico.dart';
import 'filtro_gps.dart';
import '../painel/componentes_painel.dart';

class CorridaPage extends StatefulWidget {
  const CorridaPage({
    super.key,
    this.onHistoricoAtualizado,
    this.ciclosWorkFit = const [],
  });

  /// Notifica o painel quando o histórico de corridas muda.
  final Future<void> Function()? onHistoricoAtualizado;
  final List<WorkFitCiclo> ciclosWorkFit;

  @override
  State<CorridaPage> createState() => _CorridaPageState();
}

class _CorridaPageState extends State<CorridaPage> {
  final MapController _mapController = MapController();

  List<Map<String, Object?>> _historico = [];
  List<LatLng> _rota = [];

  String _estado = 'parada';
  String? _erro;

  double _distancia = 0;
  int _duracao = 0;

  double _caloriasEstimadas = 0;
  double? _pesoKg;

  bool _carregando = false;
  bool _comandoEmAndamento = false;
  bool _avisoCorridaAberto = false;
  bool _selecionandoCiclo = false;
  bool _mapaPronto = false;
  bool _seguirPosicao = true;

  LatLng? _posicaoAtual;
  double? _precisaoGps;

  String _mensagemGps = 'Aguardando o sinal do GPS.';
  Timer? _limiteDeConfirmacao;
  bool _finalizacaoProcessada = false;

  bool get _emAndamento => _estado == 'em_andamento';
  bool get _pausada => _estado == 'pausada';
  bool get _finalizada => _estado == 'finalizada';

  static const String _chaveCorridaGuiada = 'workfit_corrida_guiada_v1';
  bool _guiada = false;
  int _minutosGuiada = 30;
  String _experienciaGuiada = 'Iniciante';
  PlanoCorrida? _plano;
  int _blocoAnunciado = -1;

  /// Lê a experiência já informada no onboarding; sem ela, usa Iniciante.
  Future<void> _carregarExperienciaPerfil() async {
    try {
      final texto = await WorkHolyBanco.instancia.lerTexto(
        'workholy_perfil_praticante_v1',
      );
      if (texto == null) return;
      final dados = jsonDecode(texto);
      final valor = dados is Map ? dados['experiencia'] : null;
      if (valor is String &&
          const ['Iniciante', 'Intermediário', 'Avançado'].contains(valor) &&
          mounted) {
        setState(() => _experienciaGuiada = valor);
      }
    } catch (erro) {
      debugPrint('Não foi possível ler a experiência do perfil: $erro');
    }
  }

  Future<void> _restaurarPlanoGuiado(String sessaoId) async {
    try {
      final texto = await WorkHolyBanco.instancia.lerTexto(_chaveCorridaGuiada);
      if (texto == null) return;
      final dados = jsonDecode(texto);
      if (dados is! Map || dados['id'] != sessaoId) return;
      final minutos = dados['minutos'];
      final experiencia = dados['experiencia'];
      final semana = dados['semana'];
      if (minutos is! int || experiencia is! String) return;
      if (!mounted) return;
      setState(() {
        _plano = PlanoCorrida.gerar(
          experiencia: experiencia,
          minutos: minutos,
          semanaCiclo: semana is int ? semana : null,
        );
        _blocoAnunciado = _plano!.posicao(_duracao).indice;
      });
    } catch (erro) {
      debugPrint('Não foi possível restaurar o plano guiado: $erro');
    }
  }

  int _kmAnunciado = 0;
  bool _vozAtiva = true;
  int _avisoBlocoIndice = -1;

  /// Fala início de bloco, aviso de 10 s e quilômetros. Só com o app aberto.
  void _anunciarMudancaDeBloco() {
    if (_emAndamento) {
      if (_distancia < _kmAnunciado * 1000) _kmAnunciado = 0;
      final km = _distancia ~/ 1000;
      if (km > _kmAnunciado) {
        _kmAnunciado = km;
        final ritmo = _duracao > 0
            ? (_duracao / (_distancia / 1000)).round()
            : null;
        unawaited(
          VozTreinador.instancia.falar(
            MensagensVoz.quilometro(km, ritmoSegundosPorKm: ritmo),
            interromper: false,
          ),
        );
      }
    }
    final plano = _plano;
    if (plano == null || !_emAndamento) return;
    final posicao = plano.posicao(_duracao);
    if (posicao.indice == _blocoAnunciado) {
      final proximo = plano.proximoBloco(posicao.indice);
      if (!posicao.concluido &&
          proximo != null &&
          posicao.restanteNoBloco == 10 &&
          _avisoBlocoIndice != posicao.indice &&
          posicao.bloco.segundos > 20) {
        _avisoBlocoIndice = posicao.indice;
        unawaited(
          VozTreinador.instancia.falar(MensagensVoz.avisoProximoBloco(proximo)),
        );
      }
      return;
    }
    final primeiro = _blocoAnunciado == -1;
    _blocoAnunciado = posicao.indice;
    if (!primeiro) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    }
    unawaited(
      VozTreinador.instancia.falar(
        posicao.concluido
            ? MensagensVoz.planoConcluido()
            : MensagensVoz.inicioDeBloco(posicao.bloco),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    FlutterForegroundTask.addTaskDataCallback(_receberDadosServico);
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
    unawaited(_carregarExperienciaPerfil());
    unawaited(
      VozTreinador.instancia.carregarPreferencia().then((_) {
        if (mounted) setState(() => _vozAtiva = VozTreinador.instancia.ativa);
      }),
    );
  }

  @override
  void dispose() {
    _limiteDeConfirmacao?.cancel();
    FlutterForegroundTask.removeTaskDataCallback(_receberDadosServico);
    super.dispose();
  }

  /// Lê o peso já salvo no perfil do praticante.
  /// Não cria outro cadastro nem utiliza peso padrão.
  Future<double?> _lerPesoPerfil() async {
    try {
      final texto = await WorkHolyBanco.instancia.lerTexto(
        'workholy_perfil_praticante_v1',
      );

      if (texto == null || texto.trim().isEmpty) {
        return null;
      }

      final decodificado = jsonDecode(texto);

      if (decodificado is! Map) {
        return null;
      }

      final valor = decodificado['peso'];

      final double? peso;
      if (valor is num) {
        peso = valor.toDouble();
      } else {
        peso = double.tryParse(
          valor?.toString().trim().replaceAll(',', '.') ?? '',
        );
      }

      if (peso == null || !peso.isFinite || peso <= 0 || peso > 500) {
        return null;
      }

      return peso;
    } catch (erro) {
      debugPrint('Não foi possível ler o peso do perfil: $erro');
      return null;
    }
  }

  Future<void> _carregar() async {
    try {
      final historico = await CorridaBanco.instancia.listar();
      final aberta = await CorridaBanco.instancia.buscarSessaoAberta();

      if (!mounted) return;

      setState(() {
        _historico = historico;
      });

      if (aberta != null) {
        final id = aberta['id'] as String;

        final rota = CorridaBanco.instancia
            .decodificarRota(aberta['rota_json'])
            .map(
              (p) => LatLng(
                (p['lat'] as num).toDouble(),
                (p['lon'] as num).toDouble(),
              ),
            )
            .toList();

        setState(() {
          _estado = aberta['estado'] as String;
          _distancia = (aberta['distancia_metros'] as num?)?.toDouble() ?? 0;
          _duracao = (aberta['duracao_segundos'] as num?)?.toInt() ?? 0;

          _caloriasEstimadas =
              (aberta['calorias_estimadas'] as num?)?.toDouble() ?? 0;

          _pesoKg = (aberta['peso_kg'] as num?)?.toDouble();

          _rota = rota;
          if (rota.isNotEmpty) {
            _posicaoAtual = rota.last;
          }
        });

        await _garantirServico();

        await _restaurarPlanoGuiado(id);

        FlutterForegroundTask.sendDataToTask({
          'comando': 'restaurar',
          'id': id,
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _erro = 'Erro ao carregar corridas: $e');
      }
    }
  }

  Future<void> _abrirAnaliseCorridaHoje() async {
    try {
      Map<String, Object?>? corridaSelecionada;

      // Prioridade: corrida que ainda está ativa ou pausada.
      final aberta = await CorridaBanco.instancia.buscarSessaoAberta();

      if (aberta != null) {
        corridaSelecionada = aberta;
      } else {
        // Sem corrida ativa: procura a última corrida iniciada hoje.
        final agora = DateTime.now();
        final inicioHoje = DateTime(agora.year, agora.month, agora.day);

        final amanha = inicioHoje.add(const Duration(days: 1));

        final historico = await CorridaBanco.instancia.listar();

        for (final corrida in historico) {
          final inicioMs = (corrida['inicio_ms'] as num?)?.toInt();
          if (inicioMs == null) continue;

          final data = DateTime.fromMillisecondsSinceEpoch(inicioMs).toLocal();

          if (!data.isBefore(inicioHoje) && data.isBefore(amanha)) {
            corridaSelecionada = corrida;
            break;
          }
        }
      }

      if (!mounted) return;

      final id = corridaSelecionada?['id']?.toString();

      if (id == null || id.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhuma corrida registrada hoje.')),
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AnaliseCorridaPage(corridaId: id)),
      );

      if (mounted) {
        await _carregar();
      }
    } catch (erro) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível abrir a análise: $erro')),
      );
    }
  }

  void _receberDadosServico(Object data) {
    if (data is! Map || !mounted) return;

    final tipo = data['tipo'];

    if (tipo == 'erro') {
      _limiteDeConfirmacao?.cancel();

      setState(() {
        _erro = data['mensagem']?.toString() ?? 'Erro no GPS.';
        _carregando = false;
        _comandoEmAndamento = false;
      });

      return;
    }

    final novaRota = data['rota'];

    final List<LatLng>? pontos = novaRota is List
        ? novaRota.whereType<Map>().map((p) {
            return LatLng(
              (p['lat'] as num).toDouble(),
              (p['lon'] as num).toDouble(),
            );
          }).toList()
        : null;

    LatLng? novoPonto;

    final pontoRecebido = data['novo_ponto'];

    if (pontoRecebido is Map) {
      final lat = pontoRecebido['lat'];
      final lon = pontoRecebido['lon'];

      if (lat is num && lon is num) {
        novoPonto = LatLng(lat.toDouble(), lon.toDouble());
      }
    }

    final caloriasRecebidas = data['calorias'];
    final pesoRecebido = data['peso_kg'];
    final estadoAnterior = _estado;
    final novoEstado = data['estado'];
    if (novoEstado is String && novoEstado != estadoAnterior) {
      if (novoEstado == 'pausada') {
        unawaited(VozTreinador.instancia.falar(MensagensVoz.corridaPausada()));
      } else if (novoEstado == 'em_andamento' && estadoAnterior == 'pausada') {
        unawaited(VozTreinador.instancia.falar(MensagensVoz.corridaRetomada()));
      }
    }
    if (tipo == 'finalizada') {
      unawaited(VozTreinador.instancia.falar(MensagensVoz.corridaFinalizada()));
    }

    setState(() {
      if (data['estado'] is String) {
        _estado = data['estado'] as String;
      }

      if (data['duracao'] is num) {
        _duracao = (data['duracao'] as num).toInt();
      }

      if (data['distancia'] is num) {
        _distancia = (data['distancia'] as num).toDouble();
      }

      if (caloriasRecebidas is num) {
        _caloriasEstimadas = caloriasRecebidas.toDouble();
      }

      if (pesoRecebido is num) {
        final peso = pesoRecebido.toDouble();
        _pesoKg = peso.isFinite && peso > 0 && peso <= 500 ? peso : null;
      } else {
        _pesoKg = null;
      }

      if (pontos != null) {
        _rota = pontos;
      } else if (novoPonto != null &&
          (_rota.isEmpty || _rota.last != novoPonto)) {
        _rota = [..._rota, novoPonto];
      }

      final lat = data['latitude'];
      final lon = data['longitude'];

      if (lat is num && lon is num) {
        _posicaoAtual = LatLng(lat.toDouble(), lon.toDouble());
      }

      if (data['precisao_gps'] is num) {
        _precisaoGps = (data['precisao_gps'] as num).toDouble();
      }

      if (data['mensagem_gps'] is String) {
        _mensagemGps = data['mensagem_gps'] as String;
      }

      if (tipo == 'estado_confirmado' || tipo == 'finalizada') {
        _limiteDeConfirmacao?.cancel();
        _carregando = false;
        _comandoEmAndamento = false;
      }
    });

    if (_mapaPronto &&
        _posicaoAtual != null &&
        _emAndamento &&
        _seguirPosicao) {
      _mapController.move(_posicaoAtual!, 17);
    }

    _anunciarMudancaDeBloco();
    if (tipo == 'finalizada') {
      unawaited(_concluirNaInterface());
    } else if (tipo == 'estado_confirmado') {
      unawaited(_atualizarHistorico());
    }
  }

  /// A corrida finalizada continua no banco/histórico, mas não permanece como
  /// sessão ativa na tela. Assim o próximo toque em iniciar começa limpo.
  Future<void> _concluirNaInterface() async {
    if (_finalizacaoProcessada) return;
    _finalizacaoProcessada = true;
    await _atualizarHistorico();
    if (!mounted) return;

    setState(() {
      _estado = 'parada';
      _distancia = 0;
      _duracao = 0;
      _caloriasEstimadas = 0;
      _pesoKg = null;
      _rota = [];
      _posicaoAtual = null;
      _precisaoGps = null;
      _mensagemGps = 'Corrida salva. Pronto para uma nova atividade.';
      _seguirPosicao = true;
      _carregando = false;
      _comandoEmAndamento = false;
      _plano = null;
      _blocoAnunciado = -1;
    });
  }

  Future<void> _atualizarHistorico({bool propagarErro = false}) async {
    try {
      final lista = await CorridaBanco.instancia.listar();

      if (!mounted) return;

      setState(() => _historico = lista);
      SincronizacaoUsuario.instancia.agendarEnvio();
      await widget.onHistoricoAtualizado?.call();
    } catch (erro) {
      debugPrint('Erro ao atualizar o histórico de corridas: $erro');
      if (propagarErro) rethrow;
    }
  }

  Future<void> _registrarEsforcoCorrida(Map<String, Object?> corrida) async {
    final id = corrida['id'];
    if (id is! String || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível identificar a corrida.'),
        ),
      );
      return;
    }
    final esforco = await showDialog<EsforcoWorkFit>(
      context: context,
      builder: (_) => WorkFitEsforcoDialog(
        permiteRir: false,
        rpeInicial: corrida['rpe'] as int?,
      ),
    );
    if (!mounted || esforco?.rpe == null) return;
    try {
      await CorridaBanco.instancia.registrarRpe(id, esforco!.rpe!);
    } catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível registrar o esforço: $erro'),
          ),
        );
      }
      return;
    }
    try {
      await _atualizarHistorico(propagarErro: true);
    } catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Esforço salvo, mas não foi possível atualizar o histórico: $erro',
            ),
          ),
        );
      }
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esforço da corrida registrado.')),
      );
    }
  }

  Future<void> _excluirCorridaFinalizada(Map<String, Object?> corrida) async {
    final id = corrida['id']?.toString();
    if (id == null || id.isEmpty) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir corrida?'),
        content: const Text(
          'A corrida e a rota GPS salva serão removidas do histórico. '
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

    try {
      final excluida = await CorridaBanco.instancia.excluirFinalizada(id);

      if (!mounted) return;

      if (!excluida) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Apenas corridas finalizadas podem ser excluídas.'),
          ),
        );
        return;
      }

      await _atualizarHistorico();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Corrida removida do histórico.')),
      );
    } catch (erro) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível excluir a corrida: $erro')),
      );
    }
  }

  Future<void> _limparHistoricoDeCorridas() async {
    final quantidade = _historico
        .where((corrida) => corrida['estado'] == 'finalizada')
        .length;

    if (quantidade == 0) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Limpar histórico de corridas?'),
        content: Text(
          'Serão removidas $quantidade corrida(s) finalizada(s), '
          'incluindo as rotas GPS salvas. Corridas em andamento ou pausadas '
          'serão preservadas. Esta ação não pode ser desfeita.',
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

    try {
      final removidas = await CorridaBanco.instancia.limparFinalizadas();

      if (!mounted) return;

      await _atualizarHistorico();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$removidas corrida(s) removida(s) do histórico.'),
        ),
      );
    } catch (erro) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível limpar o histórico: $erro')),
      );
    }
  }

  void _programarLimiteDeConfirmacao() {
    _limiteDeConfirmacao?.cancel();

    _limiteDeConfirmacao = Timer(const Duration(seconds: 12), () {
      if (!mounted || (!_carregando && !_comandoEmAndamento)) return;

      setState(() {
        _carregando = false;
        _comandoEmAndamento = false;
        _erro =
            'O serviço de corrida não confirmou a ação. '
            'Verifique a notificação e tente novamente.';
      });
    });
  }

  Future<bool> _prepararPermissoes() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        setState(() {
          _erro = 'Ative o GPS do dispositivo antes de correr.';
        });
      }
      return false;
    }

    var permissao = await Geolocator.checkPermission();

    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }

    if (permissao == LocationPermission.denied ||
        permissao == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _erro = permissao == LocationPermission.deniedForever
              ? 'Permissão negada nas configurações do Android.'
              : 'A permissão de localização é necessária para registrar a corrida.';
        });
      }
      return false;
    }

    final notificacao =
        await FlutterForegroundTask.checkNotificationPermission();

    if (notificacao != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    return true;
  }

  Future<void> _garantirServico() async {
    if (await FlutterForegroundTask.isRunningService) return;

    final resultado = await FlutterForegroundTask.startService(
      serviceId: 410,
      serviceTypes: const [ForegroundServiceTypes.location],
      notificationTitle: 'Moveria — Corrida',
      notificationText: 'O registro da corrida está ativo.',
      callback: iniciarServicoCorrida,
    );

    if (resultado is ServiceRequestFailure) {
      throw StateError(
        'Não foi possível iniciar o serviço: ${resultado.error}',
      );
    }
  }

  Future<bool> _confirmarAvisoCorrida() async {
    if (_avisoCorridaAberto || _carregando || _comandoEmAndamento) {
      return false;
    }
    _avisoCorridaAberto = true;
    try {
      final continuar = await mostrarAvisoAtividadeFisica(context);
      return mounted && continuar;
    } finally {
      _avisoCorridaAberto = false;
    }
  }

  Future<void> _iniciarComAviso({bool limparAnterior = false}) async {
    if (_selecionandoCiclo) return;
    _selecionandoCiclo = true;
    try {
      if (!await _confirmarAvisoCorrida() || !mounted) return;
      final ciclos = widget.ciclosWorkFit.where((ciclo) {
        final estado = avaliarCicloWorkFit(ciclo, DateTime.now(), []);
        return ciclo.modalidade == 'corrida' &&
            !estado.encerrado &&
            !estado.naoIniciado;
      }).toList();
      String? planoId;
      int? semanaCiclo;
      if (ciclos.isNotEmpty) {
        final selecao = await showDialog<SelecaoCicloCorrida>(
          context: context,
          builder: (_) => SelecaoCicloCorridaDialog(ciclos: ciclos),
        );
        if (!mounted || selecao == null) return;
        planoId = selecao.planoId;
        final escolhido = ciclos.where((c) => c.id == planoId).firstOrNull;
        if (escolhido != null) {
          semanaCiclo = avaliarCicloWorkFit(
            escolhido,
            DateTime.now(),
            [],
          ).semana;
        }
      }
      if (limparAnterior) {
        setState(() {
          _estado = 'parada';
          _distancia = 0;
          _duracao = 0;
          _caloriasEstimadas = 0;
          _pesoKg = null;
          _rota = [];
          _posicaoAtual = null;
          _erro = null;
          _precisaoGps = null;
          _mensagemGps = 'Aguardando o sinal do GPS.';
          _seguirPosicao = true;
          _finalizacaoProcessada = false;
        });
      }
      await _iniciar(workfitPlanoId: planoId, semanaCiclo: semanaCiclo);
    } finally {
      _selecionandoCiclo = false;
    }
  }

  Future<void> _iniciar({String? workfitPlanoId, int? semanaCiclo}) async {
    if (_carregando) return;

    setState(() {
      _finalizacaoProcessada = false;
      _carregando = true;
      _erro = null;
    });

    String? idCriado;
    var comandoEnviado = false;

    try {
      if (!await _prepararPermissoes()) return;

      // Usa o peso já cadastrado no perfil do praticante.
      final peso = await _lerPesoPerfil();

      if (!mounted) return;

      final agora = DateTime.now().millisecondsSinceEpoch;
      final id = agora.toString();

      await CorridaBanco.instancia.criar(
        id,
        agora,
        workfitPlanoId: workfitPlanoId,
      );
      idCriado = id;

      if (_guiada) {
        await WorkHolyBanco.instancia.salvarTexto(
          _chaveCorridaGuiada,
          jsonEncode({
            'id': id,
            'minutos': _minutosGuiada,
            'experiencia': _experienciaGuiada,
            'semana': semanaCiclo,
          }),
        );
      }

      await _garantirServico();

      if (!mounted) return;

      setState(() {
        _plano = _guiada
            ? PlanoCorrida.gerar(
                experiencia: _experienciaGuiada,
                minutos: _minutosGuiada,
                semanaCiclo: semanaCiclo,
              )
            : null;
        _blocoAnunciado = -1;
        _distancia = 0;
        _duracao = 0;
        _caloriasEstimadas = 0;
        _pesoKg = peso;

        _rota = [];
        _posicaoAtual = null;
        _precisaoGps = null;
        _mensagemGps = 'Preparando o GPS para a corrida.';
        _seguirPosicao = true;
      });

      // O serviço recebe o peso para calcular as calorias
      // conforme os trechos de distância aceitos pelo filtro GPS.
      FlutterForegroundTask.sendDataToTask({
        'comando': 'iniciar',
        'id': id,
        'pesoKg': peso,
      });

      comandoEnviado = true;
      _programarLimiteDeConfirmacao();
    } catch (e) {
      if (idCriado != null && !comandoEnviado) {
        await CorridaBanco.instancia.excluir(idCriado);
      }

      if (mounted) {
        setState(() => _erro = 'Não foi possível iniciar: $e');
      }
    } finally {
      if (mounted && !comandoEnviado) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _enviarComando(String comando) async {
    if (_comandoEmAndamento || _carregando) return;

    try {
      setState(() {
        _comandoEmAndamento = true;
        _erro = null;
      });

      FlutterForegroundTask.sendDataToTask({'comando': comando});
      _programarLimiteDeConfirmacao();
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Erro no comando da corrida: $e';
          _comandoEmAndamento = false;
        });
      }
    }
  }

  Future<void> _novaCorrida() => _iniciarComAviso(limparAnterior: true);

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
      String? aviso;
      switch (comando) {
        case ComandoVoz.pausar when _emAndamento:
          unawaited(_enviarComando('pausar'));
        case ComandoVoz.retomar when _pausada:
          unawaited(_enviarComando('retomar'));
        case ComandoVoz.finalizar:
          aviso = 'Para finalizar a corrida, use o botão na tela.';
        case ComandoVoz.pausar || ComandoVoz.retomar:
          aviso = 'Esse comando não vale agora.';
        case null:
          aviso = texto.isEmpty
              ? 'Não ouvi nada. Use os botões se preferir.'
              : 'Não entendi "$texto". Diga: pausar ou continuar.';
        default:
          aviso = 'Na corrida, só funcionam "pausar" e "continuar".';
      }
      if (aviso != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(aviso)));
      }
    });
    if (erro != null && mounted) {
      setState(() => _escutando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  String _tempo(int segundos) {
    final h = segundos ~/ 3600;
    final m = (segundos % 3600) ~/ 60;
    final s = segundos % 60;

    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }

    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  String _ritmo() {
    final km = _distancia / 1000;

    if (km < 0.05) return '--:--';

    final segundos = (_duracao / km).round();

    return '${segundos ~/ 60}:'
        '${(segundos % 60).toString().padLeft(2, '0')}';
  }

  String _distanciaFormatada(double metros) =>
      (metros / 1000).toStringAsFixed(2).replaceAll('.', ',');

  String _velocidade() {
    if (_duracao <= 0 || _distancia <= 0) return '0,0';

    final kmh = (_distancia / 1000) / (_duracao / 3600);

    return kmh.toStringAsFixed(1).replaceAll('.', ',');
  }

  String _caloriasFormatadas(double? calorias, double? peso) {
    if (peso == null ||
        !peso.isFinite ||
        peso <= 0 ||
        calorias == null ||
        !calorias.isFinite ||
        calorias < 0) {
      return '-- kcal';
    }

    return '${calorias.round()} kcal';
  }

  Widget _configuracaoGuiada(ThemeData tema) {
    final previa = _guiada
        ? PlanoCorrida.gerar(
            experiencia: _experienciaGuiada,
            minutos: _minutosGuiada,
          )
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Corrida guiada'),
          subtitle: const Text(
            'Intervalos de corrida e caminhada com aviso a cada troca.',
          ),
          value: _guiada,
          onChanged: _carregando
              ? null
              : (valor) => setState(() => _guiada = valor),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Voz do treinador'),
          subtitle: const Text(
            'Fala quilômetros, trocas de bloco, pausa e fim. '
            'Só com o app aberto.',
          ),
          value: _vozAtiva,
          onChanged: (valor) async {
            setState(() => _vozAtiva = valor);
            await VozTreinador.instancia.definirAtiva(valor);
            if (!valor) return;
            final erro = await VozTreinador.instancia.testar();
            if (erro != null && mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(erro)));
            }
          },
        ),
        if (_guiada) ...[
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _experienciaGuiada,
                  decoration: const InputDecoration(labelText: 'Nível'),
                  items: [
                    for (final n in ['Iniciante', 'Intermediário', 'Avançado'])
                      DropdownMenuItem(value: n, child: Text(n)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _experienciaGuiada = v);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _minutosGuiada,
                  decoration: const InputDecoration(labelText: 'Duração'),
                  items: [
                    for (final m in [20, 30, 45, 60])
                      DropdownMenuItem(value: m, child: Text('$m min')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _minutosGuiada = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${previa!.blocos.length} blocos em ${previa.duracaoTotal ~/ 60} '
            'minutos: aquecimento, intervalos e desaquecimento. É uma '
            'estrutura geral, sem avaliação de saúde; pare se sentir dor ou '
            'mal-estar.',
            style: tema.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _painelGuia(ThemeData tema) {
    final plano = _plano!;
    final pos = plano.posicao(_duracao);
    final proximo = plano.proximoBloco(pos.indice);
    final corrida = pos.bloco.tipo == TipoBlocoCorrida.corrida;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: corrida
            ? tema.colorScheme.primaryContainer
            : tema.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pos.concluido
                ? 'PLANO CONCLUÍDO'
                : 'AGORA: ${pos.bloco.tipo.rotulo.toUpperCase()}',
            style: tema.textTheme.labelLarge,
          ),
          if (!pos.concluido) ...[
            const SizedBox(height: 4),
            Text(
              _tempo(pos.restanteNoBloco),
              style: tema.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(pos.bloco.tipo.orientacao),
            if (proximo != null) ...[
              const SizedBox(height: 6),
              Text(
                'Depois: ${proximo.tipo.rotulo} '
                '(${_tempo(proximo.segundos)})',
                style: tema.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: plano.duracaoTotal == 0
                  ? 0
                  : 1 - pos.restanteTotal / plano.duracaoTotal,
            ),
          ] else
            const Text(
              'Você cumpriu o plano. Finalize a corrida quando quiser.',
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final centro = _posicaoAtual ?? const LatLng(-23.5505, -46.6333);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Corrida',
          style: tema.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Registre seu trajeto, acompanhe as métricas e salve seu histórico.',
          style: tema.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: painelBorda),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: SizedBox(
              height: 300,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: centro,
                  initialZoom: 14,
                  onMapReady: () => _mapaPronto = true,
                  onPositionChanged: (_, hasGesture) {
                    if (hasGesture && _seguirPosicao) {
                      setState(() => _seguirPosicao = false);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'br.com.workholyia.workholy_mobile',
                  ),
                  if (_rota.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _rota,
                          strokeWidth: 5,
                          color: tema.colorScheme.primary,
                        ),
                      ],
                    ),
                  if (_posicaoAtual != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _posicaoAtual!,
                          width: 44,
                          height: 44,
                          child: Icon(
                            Icons.my_location,
                            size: 34,
                            color: tema.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('© OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_posicaoAtual != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                setState(() => _seguirPosicao = true);
                _mapController.move(_posicaoAtual!, 17);
              },
              icon: Icon(_seguirPosicao ? Icons.gps_fixed : Icons.my_location),
              label: Text(
                _seguirPosicao ? 'Seguindo sua posição' : 'Centralizar mapa',
              ),
            ),
          ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Text(
                  _carregando
                      ? 'PREPARANDO CORRIDA'
                      : _comandoEmAndamento
                      ? 'SALVANDO ALTERAÇÃO'
                      : _finalizada
                      ? 'CORRIDA FINALIZADA'
                      : _pausada
                      ? 'CORRIDA PAUSADA'
                      : _emAndamento
                      ? 'CORRIDA EM ANDAMENTO'
                      : 'PRONTO PARA CORRER',
                  style: tema.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _tempo(_duracao),
                  style: tema.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: painelLima,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (_precisaoGps ?? double.infinity) <=
                            FiltroGpsCorrida.precisaoMaximaMetros
                        ? tema.colorScheme.primaryContainer
                        : tema.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        (_precisaoGps ?? double.infinity) <=
                                FiltroGpsCorrida.precisaoMaximaMetros
                            ? Icons.gps_fixed
                            : Icons.gps_not_fixed,
                        size: 19,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _mensagemGps,
                          style: tema.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Métricas atuais da corrida.
                Wrap(
                  alignment: WrapAlignment.spaceAround,
                  spacing: 20,
                  runSpacing: 18,
                  children: [
                    _Metrica(
                      titulo: 'DISTÂNCIA',
                      valor: '${_distanciaFormatada(_distancia)} km',
                    ),
                    _Metrica(titulo: 'RITMO MÉDIO', valor: '${_ritmo()} /km'),
                    _Metrica(
                      titulo: 'VELOCIDADE',
                      valor: '${_velocidade()} km/h',
                    ),
                    _Metrica(
                      titulo: 'CALORIAS ESTIMADAS',
                      valor: _caloriasFormatadas(_caloriasEstimadas, _pesoKg),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (_pesoKg == null && (_emAndamento || _pausada))
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Cadastre seu peso no perfil para habilitar a estimativa '
                      'de calorias na próxima corrida.',
                      style: tema.textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 8),
                if (!_emAndamento && !_pausada && !_finalizada)
                  _configuracaoGuiada(tema),
                if ((_emAndamento || _pausada) && _plano != null)
                  _painelGuia(tema),
                if (!_emAndamento && !_pausada && !_finalizada)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _carregando || _comandoEmAndamento
                          ? null
                          : _iniciarComAviso,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(
                        _carregando ? 'Preparando...' : 'Iniciar corrida',
                      ),
                    ),
                  ),
                if (_emAndamento) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _comandoEmAndamento
                          ? null
                          : () => _enviarComando('pausar'),
                      icon: const Icon(Icons.pause),
                      label: const Text('Pausar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: painelRoxo,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _comandoEmAndamento
                          ? null
                          : () => _enviarComando('finalizar'),
                      icon: const Icon(Icons.stop),
                      label: const Text('Finalizar corrida'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF5A4D),
                        side: const BorderSide(color: Color(0xFFFF5A4D)),
                      ),
                    ),
                  ),
                ],
                if (_pausada) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _comandoEmAndamento
                          ? null
                          : () => _enviarComando('retomar'),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Retomar corrida'),
                      style: FilledButton.styleFrom(
                        backgroundColor: painelRoxo,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _comandoEmAndamento
                          ? null
                          : () => _enviarComando('finalizar'),
                      icon: const Icon(Icons.stop),
                      label: const Text('Finalizar corrida'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF5A4D),
                        side: const BorderSide(color: Color(0xFFFF5A4D)),
                      ),
                    ),
                  ),
                ],
                if (_emAndamento || _pausada)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _ouvirComando,
                      icon: Icon(_escutando ? Icons.mic : Icons.mic_none),
                      label: Text(
                        _escutando ? 'Ouvindo...' : 'Comando de voz (opcional)',
                      ),
                    ),
                  ),
                if (_finalizada)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _novaCorrida,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Nova corrida'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _abrirAnaliseCorridaHoje,
            icon: const Icon(Icons.analytics_outlined),
            label: const Text('Análise da corrida de hoje'),
            style: FilledButton.styleFrom(
              backgroundColor: painelLima,
              foregroundColor: const Color(0xFF0A0B10),
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        if (_erro != null) ...[
          const SizedBox(height: 12),
          Card(
            color: tema.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _erro!,
                style: TextStyle(color: tema.colorScheme.onErrorContainer),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Histórico de corridas',
                style: tema.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_historico.any((corrida) => corrida['estado'] == 'finalizada'))
              IconButton(
                tooltip: 'Limpar histórico de corridas',
                onPressed: _limparHistoricoDeCorridas,
                icon: const Icon(
                  Icons.delete_sweep_outlined,
                  color: Colors.redAccent,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_historico.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Suas corridas salvas aparecerão aqui.'),
            ),
          ),
        ..._historico.map((corrida) {
          final inicio = DateTime.fromMillisecondsSinceEpoch(
            (corrida['inicio_ms'] as num).toInt(),
          ).toLocal();

          final distancia =
              (corrida['distancia_metros'] as num?)?.toDouble() ?? 0.0;

          final duracao = (corrida['duracao_segundos'] as num?)?.toInt() ?? 0;

          final calorias = (corrida['calorias_estimadas'] as num?)?.toDouble();

          final peso = (corrida['peso_kg'] as num?)?.toDouble();

          final estado = corrida['estado']?.toString() ?? 'desconhecido';

          final km = distancia / 1000;

          final ritmoSegundos = km > 0 && duracao > 0
              ? (duracao / km).round()
              : null;

          final ritmo = ritmoSegundos == null
              ? '--:--'
              : '${ritmoSegundos ~/ 60}:'
                    '${(ritmoSegundos % 60).toString().padLeft(2, '0')}';

          final velocidade = duracao > 0 && km > 0
              ? (km / (duracao / 3600)).toStringAsFixed(1).replaceAll('.', ',')
              : '0,0';

          final data =
              '${inicio.day.toString().padLeft(2, '0')}/'
              '${inicio.month.toString().padLeft(2, '0')}/'
              '${inicio.year}';

          final hora =
              '${inicio.hour.toString().padLeft(2, '0')}:'
              '${inicio.minute.toString().padLeft(2, '0')}';

          final estadoFormatado = switch (estado) {
            'finalizada' => 'Finalizada',
            'em_andamento' => 'Em andamento',
            'pausada' => 'Pausada',
            _ => estado,
          };

          final rotaSalva = CorridaBanco.instancia
              .decodificarRota(corrida['rota_json'])
              .map(
                (p) => LatLng(
                  (p['lat'] as num).toDouble(),
                  (p['lon'] as num).toDouble(),
                ),
              )
              .toList();

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.directions_run,
                        size: 30,
                        color: tema.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_distanciaFormatada(distancia)} km',
                              style: tema.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '$data às $hora',
                              style: tema.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Ver rota salva',
                        icon: const Icon(Icons.map_outlined),
                        onPressed: () {
                          if (rotaSalva.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Esta corrida não tem pontos GPS salvos.',
                                ),
                              ),
                            );
                            return;
                          }

                          setState(() {
                            _rota = rotaSalva;
                            _posicaoAtual = rotaSalva.last;
                          });

                          if (_mapaPronto) {
                            _mapController.move(rotaSalva.last, 16);
                          }
                        },
                      ),
                      if (estado == 'finalizada')
                        IconButton(
                          tooltip: 'Registrar esforço da corrida',
                          icon: const Icon(Icons.speed),
                          onPressed: () => _registrarEsforcoCorrida(corrida),
                        ),
                      if (estado == 'finalizada')
                        IconButton(
                          tooltip: 'Excluir corrida',
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _excluirCorridaFinalizada(corrida),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 20,
                    runSpacing: 14,
                    children: [
                      _Metrica(titulo: 'DURAÇÃO', valor: _tempo(duracao)),
                      _Metrica(titulo: 'RITMO MÉDIO', valor: '$ritmo /km'),
                      _Metrica(
                        titulo: 'VELOCIDADE MÉDIA',
                        valor: '$velocidade km/h',
                      ),
                      _Metrica(
                        titulo: 'CALORIAS ESTIMADAS',
                        valor: _caloriasFormatadas(calorias, peso),
                      ),
                      if (corrida['rpe'] != null)
                        _Metrica(titulo: 'RPE', valor: '${corrida['rpe']}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      avatar: Icon(
                        estado == 'finalizada'
                            ? Icons.check_circle_outline
                            : estado == 'pausada'
                            ? Icons.pause_circle_outline
                            : Icons.info_outline,
                        size: 18,
                      ),
                      label: Text(estadoFormatado),
                    ),
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

class _Metrica extends StatelessWidget {
  const _Metrica({required this.titulo, required this.valor});

  final String titulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: painelBorda),
      ),
      child: Column(
        children: [
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 0.6,
              color: painelTextoSuave,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
