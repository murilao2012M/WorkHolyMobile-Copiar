import 'dart:convert';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide Icon;

import 'painel/w_icone.dart';

import 'corrida/corrida_banco.dart';
import 'dados/workholy_banco.dart';

import 'sincronizacao/sincronizacao_usuario.dart';

const chavePerfilPraticante = 'workholy_perfil_praticante_v1';
const _verdePerfil = Color(0xFFC6F432);
const _textoPerfil = Color(0xFF9AA0AB);

class PerfilPraticantePage extends StatefulWidget {
  const PerfilPraticantePage({super.key});
  @override
  State<PerfilPraticantePage> createState() => _PerfilPraticantePageState();
}

class _PerfilPraticantePageState extends State<PerfilPraticantePage> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _altura = TextEditingController();
  final _peso = TextEditingController();
  final _objetivoPersonalizado = TextEditingController();
  Map<String, dynamic> _medidasSalvas = {};
  DateTime? _nascimento;
  String _objetivo = 'Hipertrofia', _experiencia = 'Iniciante';
  bool _carregando = true, _salvando = false;
  List<MetaPessoal> _metas = const [];
  List<AvaliacaoFisica> _avaliacoes = const [];
  int _treinosSemana = 0, _corridasSemana = 0;
  double _kmSemana = 0;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final agora = DateTime.now();
      final inicio = DateTime(
        agora.year,
        agora.month,
        agora.day,
      ).subtract(Duration(days: agora.weekday - 1));
      final fim = inicio.add(const Duration(days: 7));
      final resultados = await Future.wait([
        WorkHolyBanco.instancia.lerTexto(chavePerfilPraticante),
        WorkHolyBanco.instancia.listarMetasPessoais(),
        WorkHolyBanco.instancia.listarAvaliacoesFisicas(),
        WorkHolyBanco.instancia.contarSessoesConcluidasNoPeriodo(inicio, fim),
        CorridaBanco.instancia.listarFinalizadas(),
      ]);

      if (!mounted) return;
      final texto = resultados[0] as String?;
      if (texto != null) {
        _preencherPerfil(jsonDecode(texto) as Map<String, dynamic>);
      } else {
        final nomeAutenticado = FirebaseAuth.instance.currentUser?.displayName
            ?.trim();
        if (nomeAutenticado != null && nomeAutenticado.isNotEmpty) {
          _nome.text = nomeAutenticado;
        }
      }
      final corridas = (resultados[4] as List<CorridaConcluida>)
          .where(
            (item) =>
                !item.inicio.isBefore(inicio) && item.inicio.isBefore(fim),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _metas = resultados[1] as List<MetaPessoal>;
        _avaliacoes = resultados[2] as List<AvaliacaoFisica>;
        _treinosSemana = resultados[3] as int;
        _corridasSemana = corridas.length;
        _kmSemana = corridas.fold(
          0.0,
          (soma, item) => soma + item.distanciaMetros / 1000,
        );
      });
    } catch (erro) {
      debugPrint('Erro ao carregar perfil: $erro');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _preencherPerfil(Map<String, dynamic> dados) {
    final nome = dados['nome']?.toString().trim() ?? '';
    _nome.text = nome.isNotEmpty
        ? nome
        : FirebaseAuth.instance.currentUser?.displayName?.trim() ?? '';
    _altura.text = dados['altura']?.toString() ?? '';
    _peso.text = dados['peso']?.toString() ?? '';
    _objetivo = dados['objetivo']?.toString() ?? _objetivo;
    _experiencia = dados['experiencia']?.toString() ?? _experiencia;
    _objetivoPersonalizado.text =
        dados['objetivoPersonalizado']?.toString() ?? '';
    _nascimento = DateTime.tryParse(dados['nascimento']?.toString() ?? '');
    _medidasSalvas = dados['medidas'] is Map
        ? Map<String, dynamic>.from(dados['medidas'] as Map)
        : {};
  }

  double? _numero(String valor) =>
      double.tryParse(valor.trim().replaceAll(',', '.'));
  String _num(double valor) => valor == valor.roundToDouble()
      ? valor.toStringAsFixed(0)
      : valor.toStringAsFixed(1).replaceAll('.', ',');
  String _data(DateTime valor) =>
      '${valor.day.toString().padLeft(2, '0')}/${valor.month.toString().padLeft(2, '0')}/${valor.year}';
  Map<String, dynamic> get _dados => {
    'nome': _nome.text.trim(),
    'altura': _altura.text.trim(),
    'peso': _peso.text.trim(),
    'nascimento': _nascimento?.toIso8601String(),
    'objetivo': _objetivo,
    'objetivoPersonalizado': _objetivoPersonalizado.text.trim(),
    'experiencia': _experiencia,
    if (_medidasSalvas.isNotEmpty) 'medidas': _medidasSalvas,
    'atualizadoEm': DateTime.now().toIso8601String(),
  };

  Future<void> _salvar({bool validar = true}) async {
    if (validar && !_formKey.currentState!.validate()) {
      return;
    }
    final dados = _dados;
    final nome = _nome.text.trim();
    final usuario = FirebaseAuth.instance.currentUser;
    setState(() => _salvando = true);
    try {
      await WorkHolyBanco.instancia.salvarTexto(
        chavePerfilPraticante,
        jsonEncode(dados),
      );
      SincronizacaoUsuario.instancia.agendarEnvio();
      if (nome.isNotEmpty && usuario?.displayName != nome) {
        try {
          await usuario?.updateDisplayName(nome);
        } on FirebaseAuthException catch (erro) {
          debugPrint(
            'Não foi possível atualizar o nome da conta: ${erro.code}',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Perfil salvo no aparelho, mas não foi possível atualizar o nome da conta. Tente novamente.',
                ),
              ),
            );
          }
          return;
        }
      }
      if (mounted && validar) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Perfil salvo.')));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  double? _valorAtual(MetaPessoal meta) {
    if (meta.tipo == 'frequencia_treino') return _treinosSemana.toDouble();
    if (meta.tipo == 'corrida') return _kmSemana;
    if (meta.tipo == 'peso') {
      for (final a in _avaliacoes) {
        if (a.pesoKg != null) return a.pesoKg;
      }
      return _numero(_peso.text);
    }
    for (final a in _avaliacoes) {
      if (a.medidas[meta.campo] != null) return a.medidas[meta.campo];
    }
    return _numero(_medidasSalvas[meta.campo]?.toString() ?? '');
  }

  double _progresso(MetaPessoal meta) {
    final atual = _valorAtual(meta) ?? meta.valorInicial;
    final intervalo = meta.valorAlvo - meta.valorInicial;
    return intervalo == 0
        ? (atual == meta.valorAlvo ? 1 : 0)
        : ((atual - meta.valorInicial) / intervalo).clamp(0, 1).toDouble();
  }

  String _titulo(MetaPessoal meta) => switch (meta.tipo) {
    'peso' => 'Peso corporal',
    'medida' => meta.campo,
    'frequencia_treino' => 'Treinos semanais',
    'corrida' => 'Corrida semanal',
    _ => 'Meta',
  };

  Future<void> _novaMeta() async {
    var tipo = 'peso', prazo = DateTime.now().add(const Duration(days: 90));
    final inicial = TextEditingController(text: _peso.text),
        alvo = TextEditingController();
    final form = GlobalKey<FormState>();
    final criar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, atualizar) => AlertDialog(
          title: const Text('Nova meta'),
          content: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: tipo,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: const [
                      DropdownMenuItem(
                        value: 'peso',
                        child: Text('Peso corporal'),
                      ),
                      DropdownMenuItem(
                        value: 'frequencia_treino',
                        child: Text('Treinos por semana'),
                      ),
                      DropdownMenuItem(
                        value: 'corrida',
                        child: Text('Distância de corrida semanal'),
                      ),
                    ],
                    onChanged: (v) => atualizar(() {
                      tipo = v!;
                      inicial.text = tipo == 'peso' ? _peso.text : '0';
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: inicial,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Valor inicial',
                    ),
                    validator: (v) =>
                        _numero(v ?? '') == null ? 'Informe um número.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: alvo,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Valor alvo'),
                    validator: (v) =>
                        _numero(v ?? '') == null ? 'Informe um número.' : null,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Prazo'),
                    subtitle: Text(_data(prazo)),
                    trailing: const Icon(Icons.calendar_month_outlined),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: prazo,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(
                          const Duration(days: 3650),
                        ),
                      );
                      if (d != null) atualizar(() => prazo = d);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) Navigator.pop(context, true);
              },
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );
    if (criar == true) {
      final unidade = tipo == 'peso'
          ? 'kg'
          : tipo == 'corrida'
          ? 'km'
          : 'treinos';
      await WorkHolyBanco.instancia.salvarMetaPessoal(
        MetaPessoal(
          id: 'meta-${DateTime.now().microsecondsSinceEpoch}',
          tipo: tipo,
          campo: tipo,
          valorInicial: _numero(inicial.text)!,
          valorAlvo: _numero(alvo.text)!,
          unidade: unidade,
          prazo: prazo,
          criadaEm: DateTime.now(),
        ),
      );
      SincronizacaoUsuario.instancia.agendarEnvio();
      await _carregar();
    }
    inicial.dispose();
    alvo.dispose();
  }

  Future<void> _novaAvaliacao() async {
    var data = DateTime.now();
    final peso = TextEditingController(text: _peso.text);
    String? erroPeso;
    final salvar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, atualizar) => AlertDialog(
          title: const Text('Nova avaliação'),
          content: SizedBox(
            width: 350,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Data'),
                    subtitle: Text(_data(data)),
                    trailing: const Icon(Icons.calendar_month_outlined),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: data,
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) atualizar(() => data = d);
                    },
                  ),
                  TextField(
                    controller: peso,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Peso',
                      suffixText: 'kg',
                      errorText: erroPeso,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final valor = _numero(peso.text);
                if (valor == null || !valor.isFinite || valor <= 0) {
                  atualizar(() => erroPeso = 'Informe um peso válido.');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (salvar == true) {
      final valorPeso = _numero(peso.text);
      if (valorPeso != null) {
        await WorkHolyBanco.instancia.salvarAvaliacaoFisica(
          AvaliacaoFisica(
            id: 'avaliacao-${DateTime.now().microsecondsSinceEpoch}',
            data: data,
            pesoKg: valorPeso,
            medidas: const {},
          ),
        );
        if (mounted) {
          _peso.text = peso.text;
          await _salvar(validar: false);
          await _carregar();
        } else {
          SincronizacaoUsuario.instancia.agendarEnvio();
        }
      }
    }
    peso.dispose();
  }

  Future<void> _excluirMeta(MetaPessoal meta) async {
    await WorkHolyBanco.instancia.excluirMetaPessoal(meta.id);
    SincronizacaoUsuario.instancia.agendarEnvio();
    await _carregar();
  }

  Future<void> _excluirAvaliacao(AvaliacaoFisica item) async {
    await WorkHolyBanco.instancia.excluirAvaliacaoFisica(item.id);
    SincronizacaoUsuario.instancia.agendarEnvio();
    await _carregar();
  }

  Widget _secao(
    String titulo,
    IconData icone,
    List<Widget> filhos, {
    Widget? acao,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, color: _verdePerfil),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ?acao,
            ],
          ),
          const SizedBox(height: 16),
          ...filhos,
        ],
      ),
    ),
  );
  Widget _campo(
    String titulo,
    TextEditingController c, {
    String? sufixo,
    TextInputType teclado = TextInputType.text,
  }) => TextFormField(
    controller: c,
    keyboardType: teclado,
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(
      labelText: titulo,
      suffixText: sufixo,
      border: const OutlineInputBorder(),
    ),
  );

  Widget _secaoMetas() => _secao(
    'Metas pessoais',
    Icons.flag_outlined,
    [
      const Text(
        'Defina valor inicial, alvo e prazo.',
        style: TextStyle(color: _textoPerfil),
      ),
      const SizedBox(height: 12),
      if (_metas.isEmpty)
        const Text('Crie sua primeira meta para começar a acompanhar.'),
      ..._metas.map((m) {
        final atual = _valorAtual(m) ?? m.valorInicial;
        final p = _progresso(m);
        return Card(
          child: ListTile(
            title: Text(_titulo(m)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_num(atual)} de ${_num(m.valorAlvo)} ${m.unidade} • prazo ${_data(m.prazo)}',
                ),
                const SizedBox(height: 7),
                LinearProgressIndicator(
                  value: p,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(7),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(p * 100).round()}% concluído',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            trailing: IconButton(
              onPressed: () => _excluirMeta(m),
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            ),
          ),
        );
      }),
    ],
    acao: IconButton(
      onPressed: _novaMeta,
      tooltip: 'Criar meta',
      icon: const Icon(Icons.add_circle_outline),
    ),
  );

  List<double> _pontosPeso() => _avaliacoes.reversed
      .where((e) => e.pesoKg != null)
      .map((e) => e.pesoKg!)
      .toList();
  Widget _grafico(String titulo, List<double> pontos, String unidade) =>
      pontos.length < 2
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$titulo: ${_num(pontos.first)} → ${_num(pontos.last)} $unidade',
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _GraficoLinha(pontos),
                ),
              ),
            ],
          ),
        );
  Widget _evolucao() => _secao(
    'Evolução física',
    Icons.show_chart,
    [
      const Text(
        'Avaliações têm data e não apagam as anteriores.',
        style: TextStyle(color: _textoPerfil),
      ),
      const SizedBox(height: 14),
      _grafico('Peso', _pontosPeso(), 'kg'),
      ...{
        ..._medidasSalvas.keys,
        ..._avaliacoes.expand((a) => a.medidas.keys),
      }.map(
        (chave) => _grafico(
          chave,
          _avaliacoes.reversed
              .map((e) => e.medidas[chave])
              .whereType<double>()
              .toList(),
          'cm',
        ),
      ),
      if (_avaliacoes.isEmpty) const Text('Nenhuma avaliação registrada.'),
      ..._avaliacoes
          .take(6)
          .map(
            (a) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_data(a.data)),
              subtitle: Text(
                [
                  if (a.pesoKg != null) '${_num(a.pesoKg!)} kg',
                  ...a.medidas.entries.map(
                    (e) => '${e.key}: ${_num(e.value)} cm',
                  ),
                ].join(' • '),
              ),
              trailing: IconButton(
                onPressed: () => _excluirAvaliacao(a),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              ),
            ),
          ),
    ],
    acao: IconButton(
      onPressed: _novaAvaliacao,
      tooltip: 'Nova avaliação',
      icon: const Icon(Icons.add_circle_outline),
    ),
  );

  Widget _consistencia() {
    final mt = _metas.where((m) => m.tipo == 'frequencia_treino').firstOrNull;
    final mc = _metas.where((m) => m.tipo == 'corrida').firstOrNull;
    Widget bloco(
      IconData icon,
      String valor,
      String titulo,
      String detalhe,
      double? p,
    ) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _verdePerfil),
            const SizedBox(height: 8),
            Text(
              valor,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(titulo),
            Text(
              detalhe,
              style: const TextStyle(fontSize: 12, color: _textoPerfil),
            ),
            if (p != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(
                  value: p.clamp(0, 1).toDouble(),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
          ],
        ),
      ),
    );
    return _secao('Consistência semanal', Icons.calendar_view_week_outlined, [
      const Text(
        'Registros reais concluídos nesta semana.',
        style: TextStyle(color: _textoPerfil),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          bloco(
            Icons.fitness_center,
            '$_treinosSemana',
            'treinos concluídos',
            mt == null ? 'Sem meta semanal' : 'Meta: ${_num(mt.valorAlvo)}',
            mt == null ? null : _progresso(mt),
          ),
          const SizedBox(width: 10),
          bloco(
            Icons.directions_run,
            '$_corridasSemana',
            'corridas',
            '${_num(_kmSemana)} km${mc == null ? '' : ' • meta ${_num(mc.valorAlvo)} km'}',
            mc == null ? null : _progresso(mc),
          ),
        ],
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final corpo = _carregando
        ? const Center(child: CircularProgressIndicator(color: _verdePerfil))
        : _conteudo();
    return Scaffold(
      appBar: AppBar(title: const Text('Meu perfil')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: corpo,
          ),
        ),
      ),
    );
  }

  Widget _cabecalho() {
    final nome = _nome.text.trim();
    final inicial = nome.isEmpty ? '?' : nome.characters.first.toUpperCase();
    final agora = DateTime.now();
    int? idade;
    if (_nascimento != null) {
      idade = agora.year - _nascimento!.year;
      if (agora.month < _nascimento!.month ||
          (agora.month == _nascimento!.month && agora.day < _nascimento!.day)) {
        idade--;
      }
      if (idade < 0) idade = null;
    }
    final objetivo =
        _objetivo == 'Outro' && _objetivoPersonalizado.text.trim().isNotEmpty
        ? _objetivoPersonalizado.text.trim()
        : _objetivo;
    Widget info(IconData icone, String texto) => Chip(
      avatar: Icon(icone, size: 16, color: _verdePerfil),
      label: Text(texto),
      visualDensity: VisualDensity.compact,
    );
    final altura = _altura.text.trim();
    final peso = _peso.text.trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: _verdePerfil,
                  child: Text(
                    inicial,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nome.isEmpty ? 'Complete seu perfil' : nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Objetivo: $objetivo • $_experiencia',
                        style: const TextStyle(color: _textoPerfil),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (idade != null) info(Icons.cake_outlined, '$idade anos'),
                  if (altura.isNotEmpty) info(Icons.height, '$altura cm'),
                  if (peso.isNotEmpty)
                    info(Icons.monitor_weight_outlined, '$peso kg'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conteudo() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _cabecalho(),
          _consistencia(),
          _secaoMetas(),
          _evolucao(),
          _secao('Dados pessoais', Icons.person_outline, [
            _campo('Nome', _nome),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data de nascimento'),
              subtitle: Text(
                _nascimento == null ? 'Selecionar data' : _data(_nascimento!),
              ),
              trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate:
                      _nascimento ?? DateTime(DateTime.now().year - 18),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _nascimento = d);
              },
            ),
          ]),
          _secao('Dados físicos atuais', Icons.monitor_weight_outlined, [
            Row(
              children: [
                Expanded(
                  child: _campo(
                    'Altura',
                    _altura,
                    sufixo: 'cm',
                    teclado: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _campo(
                    'Peso atual',
                    _peso,
                    sufixo: 'kg',
                    teclado: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _objetivo,
              decoration: const InputDecoration(
                labelText: 'Objetivo principal',
                border: OutlineInputBorder(),
              ),
              items: const [
                'Hipertrofia',
                'Emagrecimento',
                'Força',
                'Condicionamento físico',
                'Saúde e bem-estar',
                'Outro',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => _objetivo = v!),
            ),
            if (_objetivo == 'Outro')
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: _campo('Descreva seu objetivo', _objetivoPersonalizado),
              ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _experiencia,
              decoration: const InputDecoration(
                labelText: 'Experiência com musculação',
                border: OutlineInputBorder(),
              ),
              items: const [
                'Iniciante',
                'Intermediário',
                'Avançado',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => _experiencia = v!),
            ),
          ]),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _salvando ? null : _salvar,
              icon: _salvando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_salvando ? 'Salvando...' : 'Salvar dados atuais'),
              style: FilledButton.styleFrom(
                backgroundColor: _verdePerfil,
                foregroundColor: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nome.dispose();
    _altura.dispose();
    _peso.dispose();
    _objetivoPersonalizado.dispose();
    super.dispose();
  }
}

class _GraficoLinha extends CustomPainter {
  const _GraficoLinha(this.pontos);
  final List<double> pontos;
  @override
  void paint(Canvas canvas, Size size) {
    final minimo = pontos.reduce(math.min), maximo = pontos.reduce(math.max);
    final faixa = math.max(maximo - minimo, 1);
    final p = Path();
    for (var i = 0; i < pontos.length; i++) {
      final x = size.width * i / (pontos.length - 1);
      final y =
          size.height - ((pontos[i] - minimo) / faixa * (size.height - 12)) - 6;
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    canvas.drawPath(
      p,
      Paint()
        ..color = _verdePerfil
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    for (var i = 0; i < pontos.length; i++) {
      final x = size.width * i / (pontos.length - 1);
      final y =
          size.height - ((pontos[i] - minimo) / faixa * (size.height - 12)) - 6;
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = _verdePerfil);
    }
  }

  @override
  bool shouldRepaint(_GraficoLinha old) => old.pontos != pontos;
}
