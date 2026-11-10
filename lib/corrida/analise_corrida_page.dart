import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' hide Icon;

import '../painel/w_icone.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'corrida_banco.dart';

class AnaliseCorridaPage extends StatefulWidget {
  const AnaliseCorridaPage({super.key, required this.corridaId});

  final String corridaId;

  @override
  State<AnaliseCorridaPage> createState() => _AnaliseCorridaPageState();
}

class _AnaliseCorridaPageState extends State<AnaliseCorridaPage> {
  static const Color _fundo = Color(0xFF0A0B10);
  static const Color _cartao = Color(0xFF12141A);
  static const Color _neon = Color(0xFFC6F432);
  static const Color _textoSecundario = Color(0xFF9AA0AB);

  Map<String, Object?>? _registro;
  List<Map<String, Object?>> _rota = [];

  Timer? _atualizador;
  bool _carregando = true;
  bool _buscaEmAndamento = false;
  String? _erro;

  bool get _finalizada => _registro?['estado'] == 'finalizada';

  @override
  void initState() {
    super.initState();
    _carregar();

    // Atualiza os dados enquanto a corrida estiver sendo registrada.
    _atualizador = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _carregar(),
    );
  }

  @override
  void dispose() {
    _atualizador?.cancel();
    super.dispose();
  }

  Future<void> _carregar() async {
    if (_buscaEmAndamento) return;
    _buscaEmAndamento = true;

    try {
      final registro = await CorridaBanco.instancia.buscar(widget.corridaId);

      if (!mounted) return;

      if (registro == null) {
        setState(() {
          _erro = 'Não foi possível localizar esta corrida.';
          _carregando = false;
        });
        return;
      }

      final rota = CorridaBanco.instancia.decodificarRota(
        registro['rota_json'],
      );

      setState(() {
        _registro = registro;
        _rota = rota;
        _erro = null;
        _carregando = false;
      });

      if (registro['estado'] == 'finalizada') {
        _atualizador?.cancel();
      }
    } catch (erro) {
      if (mounted) {
        setState(() {
          _erro = 'Erro ao carregar a análise: $erro';
          _carregando = false;
        });
      }
    } finally {
      _buscaEmAndamento = false;
    }
  }

  double _numero(Object? valor) {
    if (valor is num) return valor.toDouble();
    return 0;
  }

  int _inteiro(Object? valor) {
    if (valor is num) return valor.toInt();
    return 0;
  }

  String _tempo(int segundos) {
    final horas = segundos ~/ 3600;
    final minutos = (segundos % 3600) ~/ 60;
    final restantes = segundos % 60;

    if (horas > 0) {
      return '${horas.toString().padLeft(2, '0')}:'
          '${minutos.toString().padLeft(2, '0')}:'
          '${restantes.toString().padLeft(2, '0')}';
    }

    return '${minutos.toString().padLeft(2, '0')}:'
        '${restantes.toString().padLeft(2, '0')}';
  }

  String _ritmo(double distancia, int duracao) {
    if (distancia < 50 || duracao <= 0) return '--:--';

    final segundosKm = (duracao / (distancia / 1000)).round();

    return '${segundosKm ~/ 60}:'
        '${(segundosKm % 60).toString().padLeft(2, '0')}';
  }

  String _distancia(double metros) {
    return (metros / 1000).toStringAsFixed(2).replaceAll('.', ',');
  }

  String _decimal(double valor, {int casas = 1}) {
    return valor.toStringAsFixed(casas).replaceAll('.', ',');
  }

  DateTime? get _inicio {
    final ms = _inteiro(_registro?['inicio_ms']);
    if (ms <= 0) return null;

    return DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
  }

  String _dataFormatada(DateTime? data) {
    if (data == null) return '--/--/----';

    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';
  }

  String _horaFormatada(DateTime? data) {
    if (data == null) return '--:--';

    return '${data.hour.toString().padLeft(2, '0')}:'
        '${data.minute.toString().padLeft(2, '0')}';
  }

  List<FlSpot> _gerarPontos(String campo) {
    final pontos = <FlSpot>[];

    final timestamps = _rota
        .map((p) => p['timestamp'])
        .whereType<num>()
        .toList();

    if (timestamps.isEmpty) return pontos;

    final primeiroTimestamp = timestamps.first.toDouble();

    for (final ponto in _rota) {
      final timestamp = ponto['timestamp'];
      final valor = ponto[campo];

      if (timestamp is! num || valor is! num) continue;

      if (!valor.isFinite || valor <= 0) continue;

      final minutos = (timestamp.toDouble() - primeiroTimestamp) / 60000;

      double valorGrafico = valor.toDouble();

      if (campo == 'velocidadeMps') {
        valorGrafico *= 3.6;
      }

      if (campo == 'ritmoSegundosKm') {
        valorGrafico /= 60;
      }

      if (campo == 'distanciaAcumulada') {
        valorGrafico /= 1000;
      }

      pontos.add(FlSpot(minutos, valorGrafico));
    }

    return pontos;
  }

  Widget _grafico({
    required String titulo,
    required String unidade,
    required String campo,
    required Color cor,
    int casasDecimais = 1,
  }) {
    final pontos = _gerarPontos(campo);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cartao,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            unidade,
            style: const TextStyle(color: _textoSecundario, fontSize: 11),
          ),
          const SizedBox(height: 20),
          if (pontos.length < 2)
            SizedBox(
              height: 170,
              child: Center(
                child: Text(
                  _finalizada
                      ? 'Dados insuficientes para este gráfico.'
                      : 'Aguardando novos pontos GPS...',
                  style: const TextStyle(color: _textoSecundario),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            SizedBox(
              height: 190,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: math.max(pontos.last.x, pontos.first.x + 1),
                  minY: 0,
                  maxY: math.max(
                    1,
                    pontos.map((p) => p.y).reduce(math.max) * 1.2,
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: Colors.white.withValues(alpha: 0.07),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        interval: math.max(
                          1,
                          pontos.map((p) => p.y).reduce(math.max) / 4,
                        ),
                        getTitlesWidget: (valor, meta) => Text(
                          valor.toStringAsFixed(casasDecimais),
                          style: const TextStyle(
                            color: _textoSecundario,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        interval: math.max(1, pontos.last.x / 4),
                        getTitlesWidget: (valor, meta) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${valor.toStringAsFixed(0)}m',
                            style: const TextStyle(
                              color: _textoSecundario,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: pontos,
                      isCurved: true,
                      curveSmoothness: 0.2,
                      color: cor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: cor.withValues(alpha: 0.10),
                      ),
                    ),
                  ],
                ),
                duration: const Duration(milliseconds: 350),
              ),
            ),
        ],
      ),
    );
  }

  Widget _indicador(String titulo, String valor, IconData icone) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cartao,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: _neon, size: 20),
          const SizedBox(height: 10),
          Text(
            titulo,
            style: const TextStyle(
              color: _textoSecundario,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            valor,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapa() {
    final pontos = _rota
        .where((p) => p['lat'] is num && p['lon'] is num)
        .map(
          (p) => LatLng(
            (p['lat'] as num).toDouble(),
            (p['lon'] as num).toDouble(),
          ),
        )
        .toList();

    if (pontos.length < 2) return const SizedBox.shrink();

    return Container(
      height: 230,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _cartao,
        borderRadius: BorderRadius.circular(18),
      ),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: pontos.first,
          initialZoom: 15,
          initialCameraFit: CameraFit.coordinates(
            coordinates: pontos,
            padding: const EdgeInsets.all(35),
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'br.com.workholyia.workholy_mobile',
          ),
          PolylineLayer(
            polylines: [Polyline(points: pontos, strokeWidth: 5, color: _neon)],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: pontos.first,
                width: 22,
                height: 22,
                child: const Icon(Icons.trip_origin, color: _neon, size: 20),
              ),
              Marker(
                point: pontos.last,
                width: 26,
                height: 26,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.redAccent,
                  size: 26,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final registro = _registro;

    if (_carregando) {
      return const Scaffold(
        backgroundColor: _fundo,
        body: Center(child: CircularProgressIndicator(color: _neon)),
      );
    }

    if (registro == null) {
      return Scaffold(
        backgroundColor: _fundo,
        appBar: AppBar(
          backgroundColor: _fundo,
          foregroundColor: Colors.white,
          title: const Text('Análise da corrida'),
        ),
        body: Center(
          child: Text(
            _erro ?? 'Corrida não encontrada.',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final distanciaMetros = _numero(registro['distancia_metros']);
    final duracao = _inteiro(registro['duracao_segundos']);
    final calorias = _numero(registro['calorias_estimadas']);
    final km = distanciaMetros / 1000;

    final velocidadeMedia = duracao > 0 && km > 0 ? km / (duracao / 3600) : 0.0;

    final inicio = _inicio;

    final estado = registro['estado'] == 'finalizada'
        ? 'CORRIDA FINALIZADA'
        : registro['estado'] == 'pausada'
        ? 'CORRIDA PAUSADA'
        : 'CORRIDA EM ANDAMENTO';

    return Scaffold(
      backgroundColor: _fundo,
      appBar: AppBar(
        backgroundColor: _fundo,
        foregroundColor: Colors.white,
        title: const Text(
          'Análise da corrida',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar análise',
            onPressed: _carregar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _neon,
        backgroundColor: _cartao,
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF241B4D), Color(0xFF12141A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _neon.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_run, color: _neon),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          estado,
                          style: const TextStyle(
                            color: _neon,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Text(
                        _dataFormatada(inicio),
                        style: const TextStyle(
                          color: _textoSecundario,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    '${_distancia(distanciaMetros)} km',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'DISTÂNCIA TOTAL',
                    style: TextStyle(
                      color: _textoSecundario,
                      fontSize: 10,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _resumo('DURAÇÃO', _tempo(duracao))),
                      Expanded(
                        child: _resumo(
                          'RITMO MÉDIO',
                          '${_ritmo(distanciaMetros, duracao)} /km',
                        ),
                      ),
                      Expanded(
                        child: _resumo(
                          'VELOCIDADE',
                          '${_decimal(velocidadeMedia)} km/h',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.65,
              children: [
                _indicador(
                  'CALORIAS ESTIMADAS',
                  calorias > 0 ? '${calorias.round()} kcal' : '--',
                  Icons.local_fire_department,
                ),
                _indicador('PONTOS GPS', '${_rota.length}', Icons.gps_fixed),
                _indicador(
                  'DISTÂNCIA',
                  '${_distancia(distanciaMetros)} km',
                  Icons.straighten,
                ),
                _indicador(
                  'HORÁRIO DE INÍCIO',
                  _horaFormatada(inicio),
                  Icons.schedule,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'DESEMPENHO POR TRECHO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            _grafico(
              titulo: 'Ritmo',
              unidade: 'Minutos por quilômetro ao longo do tempo',
              campo: 'ritmoSegundosKm',
              cor: _neon,
              casasDecimais: 1,
            ),
            const SizedBox(height: 12),
            _grafico(
              titulo: 'Velocidade',
              unidade: 'Quilômetros por hora ao longo do tempo',
              campo: 'velocidadeMps',
              cor: const Color(0xFF42C9FF),
            ),
            const SizedBox(height: 12),
            _grafico(
              titulo: 'Distância acumulada',
              unidade: 'Quilômetros percorridos ao longo do tempo',
              campo: 'distanciaAcumulada',
              cor: const Color(0xFFFFC857),
            ),
            if (_rota.length >= 2) ...[
              const SizedBox(height: 24),
              const Text(
                'PERCURSO GPS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              _mapa(),
            ],
            if (_erro != null) ...[
              const SizedBox(height: 12),
              Text(_erro!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 20),
            const Text(
              'Os gráficos utilizam os pontos GPS aceitos e salvos nesta corrida. '
              'Corridas antigas sem metadados por trecho podem não apresentar '
              'os gráficos de ritmo e velocidade.',
              style: TextStyle(
                color: _textoSecundario,
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resumo(String titulo, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            color: _textoSecundario,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          valor,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
