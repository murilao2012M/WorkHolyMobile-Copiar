import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import 'corrida_banco.dart';
import 'filtro_gps.dart';

@pragma('vm:entry-point')
void iniciarServicoCorrida() {
  FlutterForegroundTask.setTaskHandler(CorridaTaskHandler());
}

class CorridaTaskHandler extends TaskHandler {
  static const _intervaloMinimoDePersistencia = Duration(seconds: 15);
  static const _distanciaMinimaDePersistencia = 30.0;

  StreamSubscription<Position>? _gps;

  String? _id;
  String _estado = 'parada';
  final List<Map<String, double>> _rota = [];

  PontoGps? _ultimoPontoAceito;
  double? _precisaoGps;
  String _mensagemGps = 'Aguardando o sinal do GPS.';

  double _distancia = 0;
  int _duracaoSegundos = 0;
  int _tempoAcumuladoMs = 0;
  int? _inicioTrechoMs;

  Future<void> _filaDePersistencia = Future.value();
  Future<void> _filaDeComandos = Future.value();
  int _salvamentosPendentes = 0;
  int _ultimoSalvamentoMs = 0;
  double _distanciaNoUltimoSalvamento = 0;

  Future<void> _restaurar(String id) async {
    // Evita reiniciar o cronômetro e o GPS ao restaurar
    // novamente a sessão que já está carregada.
    if (_id == id && (_estado == 'em_andamento' || _estado == 'pausada')) {
      _enviarEstado(tipo: 'estado_confirmado', incluirRota: true);
      return;
    }

    // Não permite substituir silenciosamente outra sessão ativa.
    if (_id != null &&
        _id != id &&
        (_estado == 'em_andamento' || _estado == 'pausada')) {
      throw StateError('Já existe outra corrida carregada neste serviço.');
    }

    final registro = await CorridaBanco.instancia.buscar(id);
    if (registro == null) return;

    _id = id;
    _estado = registro['estado'] as String;
    _distancia = (registro['distancia_metros'] as num).toDouble();
    _duracaoSegundos = registro['duracao_segundos'] as int;
    _tempoAcumuladoMs = _duracaoSegundos * 1000;
    _ultimoSalvamentoMs = DateTime.now().millisecondsSinceEpoch;
    _distanciaNoUltimoSalvamento = _distancia;

    _rota
      ..clear()
      ..addAll(CorridaBanco.instancia.decodificarRota(registro['rota_json']));

    // A rota antiga não contém os metadados necessários para validar o próximo
    // trecho. A primeira leitura após restaurar somente estabelece a base.
    _ultimoPontoAceito = null;

    if (_estado == 'em_andamento') {
      _inicioTrechoMs = DateTime.now().millisecondsSinceEpoch;
      _mensagemGps = 'Reconectando ao GPS.';
      await _iniciarGps();
    } else if (_estado == 'pausada') {
      _mensagemGps = 'Corrida pausada.';
    }

    _enviarEstado(tipo: 'estado_confirmado', incluirRota: true);
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (_estado == 'em_andamento' && _inicioTrechoMs != null) {
      final agora = DateTime.now().millisecondsSinceEpoch;
      _duracaoSegundos = ((_tempoAcumuladoMs + agora - _inicioTrechoMs!) / 1000)
          .floor();

      _salvarEmSegundoPlano();
      FlutterForegroundTask.updateService(
        notificationTitle: 'WorkHoly — Corrida em andamento',
        notificationText:
            '${(_distancia / 1000).toStringAsFixed(2)} km • '
            '${_formatarTempoCurto(_duracaoSegundos)}',
      );
    }

    // Atualizações de cronômetro não transportam a rota inteira. A UI recebe
    // somente novos pontos GPS quando eles são aceitos.
    _enviarEstado();
  }

  String _formatarTempoCurto(int segundos) {
    final minutos = segundos ~/ 60;
    final segundosRestantes = segundos % 60;
    return '${minutos.toString().padLeft(2, '0')}:'
        '${segundosRestantes.toString().padLeft(2, '0')}';
  }

  void _enviarEstado({
    String tipo = 'atualizacao',
    Map<String, double>? novoPonto,
    bool incluirRota = false,
  }) {
    final ultimoPonto = _rota.isEmpty ? null : _rota.last;

    FlutterForegroundTask.sendDataToMain({
      'tipo': tipo,
      'id': _id,
      'estado': _estado,
      'duracao': _duracaoSegundos,
      'distancia': _distancia,
      'latitude': ultimoPonto?['lat'],
      'longitude': ultimoPonto?['lon'],
      'precisao_gps': _precisaoGps,
      'mensagem_gps': _mensagemGps,
      'novo_ponto': ?novoPonto,
      if (incluirRota) 'rota': _rota,
    });
  }

  void _enviarErro(String mensagem) {
    FlutterForegroundTask.sendDataToMain({
      'tipo': 'erro',
      'mensagem': mensagem,
    });
  }

  void _salvarEmSegundoPlano() {
    unawaited(
      _salvarSeNecessario().catchError((Object erro, StackTrace stack) {
        // _enfileirarPersistencia já comunica a falha
        // pelo canal de erros do serviço.
        // Aqui impedimos que a Future fique sem tratamento.
      }),
    );
  }

  Future<void> _salvarSeNecessario({bool forcar = false}) {
    if (_id == null) return Future.value();

    // Uma gravação normal nunca deve reabrir ou sobrescrever
    // uma corrida que já foi finalizada.
    if (_estado == 'finalizada' && !forcar) {
      return _filaDePersistencia;
    }

    final agora = DateTime.now().millisecondsSinceEpoch;

    final passouIntervalo =
        agora - _ultimoSalvamentoMs >=
        _intervaloMinimoDePersistencia.inMilliseconds;

    final avancouDistancia =
        _distancia - _distanciaNoUltimoSalvamento >=
        _distanciaMinimaDePersistencia;

    if (!forcar && !passouIntervalo && !avancouDistancia) {
      return _filaDePersistencia;
    }

    // Se existe uma gravação em andamento, aguarda sua conclusão
    // e verifica novamente se os dados mais recentes precisam ser salvos.
    if (_salvamentosPendentes > 0) {
      return _filaDePersistencia.then<void>((_) {
        if (_estado == 'finalizada' && !forcar) {
          return Future<void>.value();
        }

        return _salvarSeNecessario(forcar: forcar);
      });
    }

    return _enfileirarPersistencia(finalizar: false);
  }

  Future<void> _enfileirarPersistencia({required bool finalizar}) {
    final id = _id;
    if (id == null) return Future<void>.value();

    // Captura um retrato consistente dos dados desta gravação.
    final duracao = _duracaoSegundos;
    final distancia = _distancia;
    final estado = finalizar ? 'finalizada' : _estado;
    final rota = _rota.map(Map<String, double>.from).toList(growable: false);
    final fimMs = finalizar ? DateTime.now().millisecondsSinceEpoch : null;

    _salvamentosPendentes += 1;

    final operacao = _filaDePersistencia
        .then<void>((_) async {
          await CorridaBanco.instancia.atualizar(
            id: id,
            duracaoSegundos: duracao,
            distanciaMetros: distancia,
            estado: estado,
            rota: rota,
            fimMs: fimMs,
          );

          // Atualiza os indicadores somente após a gravação bem-sucedida.
          _ultimoSalvamentoMs = DateTime.now().millisecondsSinceEpoch;
          _distanciaNoUltimoSalvamento = distancia;
        })
        .whenComplete(() {
          _salvamentosPendentes -= 1;
        });

    // A operação retornada ao chamador mantém a falha.
    // A fila interna, porém, é recuperada para permitir novas gravações.
    _filaDePersistencia = operacao.then<void>(
      (_) {},
      onError: (Object erro, StackTrace stack) {
        _enviarErro('Não foi possível salvar a corrida: $erro');
      },
    );

    return operacao;
  }

  Future<void> _iniciarGps() async {
    await _gps?.cancel();

    _gps =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 5,
          ),
        ).listen(
          (posicao) {
            if (_estado != 'em_andamento') return;

            _precisaoGps = posicao.accuracy;
            final pontoAtual = PontoGps(
              latitude: posicao.latitude,
              longitude: posicao.longitude,
              horario: posicao.timestamp,
              precisaoMetros: posicao.accuracy,
              temPrecisao: posicao.hasAccuracy,
            );

            final resultado = FiltroGpsCorrida.avaliar(
              atual: pontoAtual,
              anteriorAceito: _ultimoPontoAceito,
            );

            if (!resultado.aceito) {
              _mensagemGps = _mensagemParaDescarte(resultado.motivoDescarte!);
              _enviarEstado();
              return;
            }

            final haviaPontoAnterior = _ultimoPontoAceito != null;
            _ultimoPontoAceito = pontoAtual;
            _mensagemGps =
                'GPS conectado • precisão de ±${posicao.accuracy.round()} m';

            if (haviaPontoAnterior) {
              _distancia += resultado.distanciaMetros;
            }

            final pontoDaRota = <String, double>{
              'lat': posicao.latitude,
              'lon': posicao.longitude,
            };

            _rota.add(pontoDaRota);
            _salvarEmSegundoPlano();
            _enviarEstado(novoPonto: pontoDaRota);
          },
          onError: (Object erro) {
            _mensagemGps = 'GPS indisponível.';
            _enviarErro('Falha no GPS: $erro');
            _enviarEstado();
          },
        );
  }

  String _mensagemParaDescarte(MotivoDescarteGps motivo) {
    return switch (motivo) {
      MotivoDescarteGps.precisaoIndisponivel =>
        'Aguardando uma leitura GPS com precisÃ£o.',
      MotivoDescarteGps.precisaoInsuficiente =>
        'Sinal GPS fraco • precisão acima de ${FiltroGpsCorrida.precisaoMaximaMetros.toInt()} m',
      MotivoDescarteGps.velocidadeImprovavel =>
        'Salto de GPS descartado para proteger a distância.',
      MotivoDescarteGps.movimentoMuitoCurto =>
        'GPS conectado • aguardando movimento.',
      MotivoDescarteGps.horarioInvalido =>
        'Aguardando uma nova leitura do GPS.',
      MotivoDescarteGps.coordenadaInvalida =>
        'Leitura de GPS inválida descartada.',
    };
  }

  @override
  void onReceiveData(Object data) {
    if (data is! Map) return;
    _filaDeComandos = _filaDeComandos.then((_) => _executarComando(data));
    unawaited(_filaDeComandos);
  }

  Future<void> _executarComando(Map data) async {
    try {
      final comando = data['comando'];

      if (comando == 'iniciar') {
        await _iniciarNova(data);
      } else if (comando == 'restaurar') {
        final id = data['id'];
        if (id is String) await _restaurar(id);
      } else if (comando == 'pausar') {
        await _pausar();
      } else if (comando == 'retomar') {
        await _retomar();
      } else if (comando == 'finalizar') {
        await _finalizar();
      }
    } catch (erro) {
      _enviarErro('Não foi possível executar o comando da corrida: $erro');
    }
  }

  Future<void> _iniciarNova(Map data) async {
    final id = data['id'];
    if (id is! String) {
      throw ArgumentError.value(
        id,
        'id',
        'O identificador da corrida é obrigatório.',
      );
    }

    _id = id;
    _estado = 'em_andamento';
    _distancia = 0;
    _duracaoSegundos = 0;
    _tempoAcumuladoMs = 0;
    _inicioTrechoMs = DateTime.now().millisecondsSinceEpoch;
    _ultimoPontoAceito = null;
    _precisaoGps = null;
    _mensagemGps = 'Buscando sinal GPS.';
    _ultimoSalvamentoMs = 0;
    _distanciaNoUltimoSalvamento = 0;
    _rota.clear();

    await _iniciarGps();
    await _salvarSeNecessario(forcar: true);
    _enviarEstado(tipo: 'estado_confirmado', incluirRota: true);
  }

  Future<void> _pausar({bool confirmar = true}) async {
    if (_estado != 'em_andamento') return;

    final agora = DateTime.now().millisecondsSinceEpoch;
    if (_inicioTrechoMs != null) {
      _tempoAcumuladoMs += agora - _inicioTrechoMs!;
    }

    _duracaoSegundos = (_tempoAcumuladoMs / 1000).floor();
    _inicioTrechoMs = null;
    _estado = 'pausada';
    _mensagemGps = 'Corrida pausada.';

    await _gps?.cancel();
    _gps = null;
    await FlutterForegroundTask.updateService(
      notificationTitle: 'WorkHoly — Corrida pausada',
      notificationText: 'Abra o aplicativo para retomar ou finalizar.',
    );
    await _salvarSeNecessario(forcar: true);

    if (confirmar) {
      _enviarEstado(tipo: 'estado_confirmado');
    }
  }

  Future<void> _retomar() async {
    if (_estado != 'pausada') return;

    _estado = 'em_andamento';
    _inicioTrechoMs = DateTime.now().millisecondsSinceEpoch;
    _ultimoPontoAceito = null;
    _precisaoGps = null;
    _mensagemGps = 'Buscando sinal GPS.';

    await _iniciarGps();
    await _salvarSeNecessario(forcar: true);
    _enviarEstado(tipo: 'estado_confirmado');
  }

  Future<void> _finalizar() async {
    // Um segundo comando não deve alterar a data de término.
    if (_estado == 'finalizada') return;

    if (_id == null) return;

    if (_estado == 'em_andamento') {
      await _pausar(confirmar: false);
    }

    // A pausa pode ter falhado; só finalize se houver uma sessão válida.
    if (_id == null || _estado != 'pausada') return;

    _estado = 'finalizada';
    _mensagemGps = 'Corrida finalizada.';

    await _enfileirarPersistencia(finalizar: true);

    _enviarEstado(tipo: 'finalizada', incluirRota: true);

    await FlutterForegroundTask.stopService();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    if (_estado == 'em_andamento' && _inicioTrechoMs != null) {
      final agora = DateTime.now().millisecondsSinceEpoch;
      _duracaoSegundos = ((_tempoAcumuladoMs + agora - _inicioTrechoMs!) / 1000)
          .floor();
      await _salvarSeNecessario(forcar: true);
    }

    await _gps?.cancel();
    _gps = null;
  }
}
