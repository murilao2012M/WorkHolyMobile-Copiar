import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../dados/workholy_banco.dart';
import 'corrida_banco.dart';
import 'corrida_servico.dart';
import 'filtro_gps.dart';

class CorridaPage extends StatefulWidget {
  const CorridaPage({super.key, this.onHistoricoAtualizado});

  /// Notifica o painel quando o histórico de corridas muda.
  final Future<void> Function()? onHistoricoAtualizado;

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
  bool _mapaPronto = false;
  bool _seguirPosicao = true;

  LatLng? _posicaoAtual;
  double? _precisaoGps;

  String _mensagemGps = 'Aguardando o sinal do GPS.';
  Timer? _limiteDeConfirmacao;

  bool get _emAndamento => _estado == 'em_andamento';
  bool get _pausada => _estado == 'pausada';
  bool get _finalizada => _estado == 'finalizada';

  @override
  void initState() {
    super.initState();
    FlutterForegroundTask.addTaskDataCallback(_receberDadosServico);
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
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
            .map((p) => LatLng(p['lat']!, p['lon']!))
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

    if (tipo == 'finalizada' || tipo == 'estado_confirmado') {
      unawaited(_atualizarHistorico());
    }
  }

  Future<void> _atualizarHistorico() async {
    try {
      final lista = await CorridaBanco.instancia.listar();

      if (!mounted) return;

      setState(() => _historico = lista);
      await widget.onHistoricoAtualizado?.call();
    } catch (erro) {
      debugPrint('Erro ao atualizar o histórico de corridas: $erro');
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
      notificationTitle: 'WorkHoly — Corrida',
      notificationText: 'O registro da corrida está ativo.',
      callback: iniciarServicoCorrida,
    );

    if (resultado is ServiceRequestFailure) {
      throw StateError(
        'Não foi possível iniciar o serviço: ${resultado.error}',
      );
    }
  }

  Future<void> _iniciar() async {
    if (_carregando) return;

    setState(() {
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

      await CorridaBanco.instancia.criar(id, agora);
      idCriado = id;

      await _garantirServico();

      if (!mounted) return;

      setState(() {
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

  Future<void> _novaCorrida() async {
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
    });

    await _iniciar();
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
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
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
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                  style: tema.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [],
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
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _carregando || _comandoEmAndamento
                          ? null
                          : _iniciar,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(
                        _carregando ? 'Preparando...' : 'Iniciar corrida',
                      ),
                    ),
                  ),
                if (_emAndamento) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _comandoEmAndamento
                          ? null
                          : () => _enviarComando('pausar'),
                      icon: const Icon(Icons.pause),
                      label: const Text('Pausar'),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _comandoEmAndamento
                          ? null
                          : () => _enviarComando('finalizar'),
                      icon: const Icon(Icons.stop),
                      label: const Text('Finalizar corrida'),
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
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _comandoEmAndamento
                          ? null
                          : () => _enviarComando('finalizar'),
                      icon: const Icon(Icons.stop),
                      label: const Text('Finalizar corrida'),
                    ),
                  ),
                ],
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
              .map((p) => LatLng(p['lat']!, p['lon']!))
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
    return SizedBox(
      width: 135,
      child: Column(
        children: [
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 6),
          Text(
            valor,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
