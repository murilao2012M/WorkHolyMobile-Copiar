import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dados/workholy_banco.dart';
import '../dados/workholy_modelos.dart';
import '../preferencias/unidade_carga.dart';
import 'alunos_modelos.dart';

class AlunosPage extends StatefulWidget {
  const AlunosPage({
    super.key,
    required this.treinos,
    required this.exercicios,
    required this.itensTreino,
    required this.sessoes,
    required this.onIniciarTreino,
    required this.onDadosAlterados,
  });

  final List<Treino> treinos;
  final List<Exercicio> exercicios;
  final List<ItemTreino> itensTreino;
  final List<SessaoTreino> sessoes;
  final Future<void> Function(String treinoId, String alunoId) onIniciarTreino;
  final Future<void> Function() onDadosAlterados;

  @override
  State<AlunosPage> createState() => _AlunosPageState();
}

class _AlunosPageState extends State<AlunosPage> {
  final _busca = TextEditingController();
  List<Aluno> _alunos = const [];
  String _filtro = 'todos';
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void didUpdateWidget(covariant AlunosPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.treinos, widget.treinos) ||
        !identical(oldWidget.exercicios, widget.exercicios) ||
        !identical(oldWidget.itensTreino, widget.itensTreino) ||
        !identical(oldWidget.sessoes, widget.sessoes)) {
      _carregar();
    }
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final alunos = await WorkHolyBanco.instancia.listarAlunos();
      if (!mounted) return;
      setState(() {
        _alunos = alunos;
        _erro = null;
        _carregando = false;
      });
    } catch (erro, stackTrace) {
      debugPrint('Erro ao carregar alunos: $erro');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível carregar a lista de alunos.';
        _carregando = false;
      });
    }
  }

  List<Aluno> get _filtrados {
    final termo = _busca.text.trim().toLowerCase();
    return _alunos.where((aluno) {
      final correspondeStatus = _filtro == 'todos' || aluno.status == _filtro;
      final correspondeTexto =
          termo.isEmpty ||
          aluno.nome.toLowerCase().contains(termo) ||
          aluno.email.toLowerCase().contains(termo) ||
          aluno.telefone.toLowerCase().contains(termo);
      return correspondeStatus && correspondeTexto;
    }).toList();
  }

  Future<void> _novoAluno() async {
    final aluno = await showDialog<Aluno>(
      context: context,
      builder: (_) => _FormularioAluno(treinos: widget.treinos),
    );
    if (aluno == null || !mounted) return;

    try {
      await WorkHolyBanco.instancia.salvarAluno(aluno);
      await _carregar();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Aluno cadastrado.')));
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível cadastrar o aluno: $erro')),
      );
    }
  }

  Future<void> _abrirAluno(Aluno aluno) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AlunoDetalhesPage(
          aluno: aluno,
          treinos: widget.treinos,
          exercicios: widget.exercicios,
          itensTreino: widget.itensTreino,
          sessoesIniciais: widget.sessoes
              .where((sessao) => sessao.alunoId == aluno.id)
              .toList(),
          onIniciarTreino: widget.onIniciarTreino,
          onExcluir: () async {
            await WorkHolyBanco.instancia.excluirAluno(aluno.id);
            await widget.onDadosAlterados();
          },
        ),
      ),
    );
    if (mounted) await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final filtrados = _filtrados;

    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 44),
              const SizedBox(height: 12),
              Text(_erro!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  setState(() => _carregando = true);
                  _carregar();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Alunos',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
              ),
            ),
            FilledButton.icon(
              onPressed: _novoAluno,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Cadastrar'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${_alunos.where((aluno) => aluno.status == 'ativo').length} ativos • '
          '${_alunos.length} cadastrados',
          style: TextStyle(color: cores.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _busca,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Buscar por nome, e-mail ou telefone',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _busca.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpar busca',
                    onPressed: () {
                      _busca.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'todos', label: Text('Todos')),
            ButtonSegment(value: 'ativo', label: Text('Ativos')),
            ButtonSegment(value: 'pausado', label: Text('Pausados')),
            ButtonSegment(value: 'inativo', label: Text('Inativos')),
          ],
          selected: {_filtro},
          showSelectedIcon: false,
          onSelectionChanged: (valores) =>
              setState(() => _filtro = valores.first),
        ),
        const SizedBox(height: 12),
        if (filtrados.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    _alunos.isEmpty ? Icons.groups_outlined : Icons.search_off,
                    size: 42,
                    color: cores.primary,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _alunos.isEmpty
                        ? 'Você ainda não cadastrou alunos.'
                        : 'Nenhum aluno corresponde aos filtros.',
                    textAlign: TextAlign.center,
                  ),
                  if (_alunos.isEmpty) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _novoAluno,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Cadastrar primeiro aluno'),
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          ...filtrados.map((aluno) {
            final treinosAtribuidos = aluno.treinoIds
                .where((id) => widget.treinos.any((treino) => treino.id == id))
                .length;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: () => _abrirAluno(aluno),
                leading: CircleAvatar(
                  backgroundColor: cores.primaryContainer,
                  foregroundColor: cores.onPrimaryContainer,
                  child: Text(
                    aluno.nome.trim().isEmpty
                        ? '?'
                        : aluno.nome.trim()[0].toUpperCase(),
                  ),
                ),
                title: Text(
                  aluno.nome,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  [
                    _rotuloStatus(aluno.status),
                    if (treinosAtribuidos > 0)
                      '$treinosAtribuidos ${treinosAtribuidos == 1 ? 'treino' : 'treinos'} atribuídos',
                    if (aluno.telefone.isNotEmpty) aluno.telefone,
                  ].join(' • '),
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
            );
          }),
      ],
    );
  }
}

String _rotuloStatus(String status) => switch (status) {
  'pausado' => 'Pausado',
  'inativo' => 'Inativo',
  _ => 'Ativo',
};

class _FormularioAluno extends StatefulWidget {
  const _FormularioAluno({required this.treinos, this.aluno});

  final List<Treino> treinos;
  final Aluno? aluno;

  @override
  State<_FormularioAluno> createState() => _FormularioAlunoState();
}

class _FormularioAlunoState extends State<_FormularioAluno> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _telefone;
  late final TextEditingController _email;
  late final TextEditingController _objetivo;
  late final TextEditingController _disponibilidade;
  late final TextEditingController _preferencias;
  late final TextEditingController _observacoes;
  late DateTime _inicio;
  late String _status;
  late String _nivel;
  late Set<String> _treinoIds;

  static const _niveis = ['Iniciante', 'Intermediário', 'Avançado'];

  @override
  void initState() {
    super.initState();
    final aluno = widget.aluno;
    _nome = TextEditingController(text: aluno?.nome ?? '');
    _telefone = TextEditingController(text: aluno?.telefone ?? '');
    _email = TextEditingController(text: aluno?.email ?? '');
    _objetivo = TextEditingController(text: aluno?.objetivo ?? '');
    _disponibilidade = TextEditingController(
      text: aluno?.disponibilidade ?? '',
    );
    _preferencias = TextEditingController(text: aluno?.preferencias ?? '');
    _observacoes = TextEditingController(text: aluno?.observacoes ?? '');
    _inicio = aluno?.inicio ?? DateTime.now();
    _status = aluno?.status ?? 'ativo';
    _nivel = _niveis.contains(aluno?.nivel) ? aluno!.nivel : _niveis.first;
    final treinosValidos = widget.treinos.map((treino) => treino.id).toSet();
    _treinoIds = (aluno?.treinoIds ?? const <String>[])
        .where(treinosValidos.contains)
        .toSet();
  }

  @override
  void dispose() {
    _nome.dispose();
    _telefone.dispose();
    _email.dispose();
    _objetivo.dispose();
    _disponibilidade.dispose();
    _preferencias.dispose();
    _observacoes.dispose();
    super.dispose();
  }

  Future<void> _escolherInicio() async {
    final hoje = DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: _inicio.isAfter(hoje) ? hoje : _inicio,
      firstDate: DateTime(1900),
      lastDate: hoje,
    );
    if (data != null) setState(() => _inicio = data);
  }

  void _salvar() {
    if (!_formKey.currentState!.validate()) return;
    final anterior = widget.aluno;
    Navigator.pop(
      context,
      Aluno(
        id: anterior?.id ?? novoId('aluno'),
        nome: _nome.text.trim(),
        telefone: _telefone.text.trim(),
        email: _email.text.trim(),
        inicio: _inicio,
        status: _status,
        objetivo: _objetivo.text.trim(),
        nivel: _nivel,
        disponibilidade: _disponibilidade.text.trim(),
        preferencias: _preferencias.text.trim(),
        observacoes: _observacoes.text.trim(),
        treinoIds: _treinoIds.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final disponiveis = widget.treinos;

    return AlertDialog(
      title: Text(widget.aluno == null ? 'Cadastrar aluno' : 'Editar aluno'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nome,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nome *'),
                  validator: (valor) => valor == null || valor.trim().isEmpty
                      ? 'Informe o nome do aluno.'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _telefone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefone'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail'),
                  validator: (valor) {
                    if (valor == null ||
                        valor.trim().isEmpty ||
                        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(valor.trim())) {
                      return null;
                    }
                    return 'Informe um e-mail válido.';
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Data de início'),
                  subtitle: Text(_formatarData(_inicio)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _escolherInicio,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'ativo', child: Text('Ativo')),
                    DropdownMenuItem(value: 'pausado', child: Text('Pausado')),
                    DropdownMenuItem(value: 'inativo', child: Text('Inativo')),
                  ],
                  onChanged: (valor) {
                    if (valor != null) setState(() => _status = valor);
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _objetivo,
                  decoration: const InputDecoration(
                    labelText: 'Objetivo de treino',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _nivel,
                  decoration: const InputDecoration(
                    labelText: 'Nível de experiência',
                  ),
                  items: _niveis
                      .map(
                        (nivel) =>
                            DropdownMenuItem(value: nivel, child: Text(nivel)),
                      )
                      .toList(),
                  onChanged: (valor) {
                    if (valor != null) setState(() => _nivel = valor);
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _disponibilidade,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Disponibilidade / rotina',
                    hintText: 'Ex.: segunda, quarta e sexta à noite',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _preferencias,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Preferências de treino',
                    hintText: 'Ex.: prefere halteres; evitar corrida',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _observacoes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Observações gerais',
                  ),
                ),
                if (disponiveis.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Treinos atribuídos',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...disponiveis.map(
                    (treino) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _treinoIds.contains(treino.id),
                      title: Text(treino.nome),
                      subtitle: treino.objetivo.isEmpty
                          ? null
                          : Text(treino.objetivo),
                      onChanged: (selecionado) => setState(() {
                        if (selecionado == true) {
                          _treinoIds.add(treino.id);
                        } else {
                          _treinoIds.remove(treino.id);
                        }
                      }),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _salvar, child: const Text('Salvar')),
      ],
    );
  }
}

class AlunoDetalhesPage extends StatefulWidget {
  const AlunoDetalhesPage({
    super.key,
    required this.aluno,
    required this.treinos,
    required this.exercicios,
    required this.itensTreino,
    required this.sessoesIniciais,
    required this.onIniciarTreino,
    required this.onExcluir,
  });

  final Aluno aluno;
  final List<Treino> treinos;
  final List<Exercicio> exercicios;
  final List<ItemTreino> itensTreino;
  final List<SessaoTreino> sessoesIniciais;
  final Future<void> Function(String treinoId, String alunoId) onIniciarTreino;
  final Future<void> Function() onExcluir;

  @override
  State<AlunoDetalhesPage> createState() => _AlunoDetalhesPageState();
}

class _AlunoDetalhesPageState extends State<AlunoDetalhesPage> {
  late Aluno _aluno;
  late List<SessaoTreino> _sessoes;
  List<AnotacaoAluno> _anotacoes = const [];
  bool _carregandoAnotacoes = true;

  @override
  void initState() {
    super.initState();
    _aluno = widget.aluno;
    _sessoes = widget.sessoesIniciais;
    _carregarAnotacoes();
  }

  Future<void> _carregarAnotacoes() async {
    try {
      final anotacoes = await WorkHolyBanco.instancia.listarAnotacoesAluno(
        _aluno.id,
      );
      if (!mounted) return;
      setState(() {
        _anotacoes = anotacoes;
        _carregandoAnotacoes = false;
      });
    } catch (erro, stackTrace) {
      debugPrint('Erro ao carregar anotações do aluno: $erro');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _carregandoAnotacoes = false);
      _mensagem('Não foi possível carregar as anotações.');
    }
  }

  Future<void> _atualizarSessoes() async {
    try {
      final dados = await WorkHolyBanco.instancia.carregarDadosTreino();
      final sessoes = <SessaoTreino>[];
      for (final registro in dados.sessoesTreino) {
        try {
          final sessao = SessaoTreino.fromJson(registro);
          if (sessao.alunoId == _aluno.id) sessoes.add(sessao);
        } on FormatException catch (erro) {
          debugPrint('Sessão inválida ignorada no perfil do aluno: $erro');
        } on TypeError catch (erro) {
          debugPrint('Sessão inválida ignorada no perfil do aluno: $erro');
        }
      }
      if (mounted) setState(() => _sessoes = sessoes);
    } catch (erro) {
      if (mounted) _mensagem('Não foi possível atualizar o histórico: $erro');
    }
  }

  void _mensagem(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _editarAluno() async {
    final atualizado = await showDialog<Aluno>(
      context: context,
      builder: (_) => _FormularioAluno(treinos: widget.treinos, aluno: _aluno),
    );
    if (atualizado == null || !mounted) return;
    try {
      await WorkHolyBanco.instancia.salvarAluno(atualizado);
      setState(() => _aluno = atualizado);
      _mensagem('Cadastro atualizado.');
    } catch (erro) {
      _mensagem('Não foi possível atualizar o cadastro: $erro');
    }
  }

  Future<void> _novaAnotacao() async {
    final controller = TextEditingController();
    try {
      final texto = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Anotação privada do treinador'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 7,
            decoration: const InputDecoration(
              hintText: 'Registre um acompanhamento deste aluno',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Salvar anotação'),
            ),
          ],
        ),
      );
      if (texto == null || texto.trim().isEmpty || !mounted) return;
      await WorkHolyBanco.instancia.salvarAnotacaoAluno(
        AnotacaoAluno(
          id: novoId('anotacao-aluno'),
          alunoId: _aluno.id,
          texto: texto.trim(),
          criadaEm: DateTime.now(),
        ),
      );
      await _carregarAnotacoes();
    } catch (erro) {
      if (mounted) _mensagem('Não foi possível salvar a anotação: $erro');
    } finally {
      controller.dispose();
    }
  }

  Future<void> _excluirAnotacao(AnotacaoAluno anotacao) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir anotação?'),
        content: const Text('Esta ação não pode ser desfeita.'),
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
    if (confirmar != true) return;
    try {
      await WorkHolyBanco.instancia.excluirAnotacaoAluno(anotacao.id);
      await _carregarAnotacoes();
    } catch (erro) {
      if (mounted) _mensagem('Não foi possível excluir a anotação: $erro');
    }
  }

  Future<void> _excluirAluno() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir cadastro do aluno?'),
        content: Text(
          'O cadastro e as anotações privadas de ${_aluno.nome} serão '
          'removidos. O histórico de treinos será preservado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir cadastro'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    try {
      await widget.onExcluir();
      if (mounted) Navigator.pop(context);
    } catch (erro) {
      if (mounted) _mensagem('Não foi possível excluir o cadastro: $erro');
    }
  }

  Future<void> _compartilharTreino(Treino treino) async {
    final itens = widget.itensTreino
        .where(
          (item) =>
              item.treinoId == treino.id &&
              widget.exercicios.any(
                (exercicio) => exercicio.id == item.exercicioId,
              ),
        )
        .toList();
    final linhas = <String>[
      'Treino de ${_aluno.nome}: ${treino.nome}',
      if (treino.objetivo.trim().isNotEmpty) 'Objetivo: ${treino.objetivo}',
      '',
      ...itens.map((item) {
        final exercicio = widget.exercicios.firstWhere(
          (registro) => registro.id == item.exercicioId,
        );
        final carga = PreferenciaUnidadeCarga.instancia.formatar(
          item.cargaKg,
          pesoCorporal: item.pesoCorporal,
        );
        return '• ${exercicio.nome}: ${item.series} x ${item.repeticoes} '
            '($carga; descanso ${item.descansoSegundos}s)';
      }),
    ];
    try {
      final compartilhado =
          await const MethodChannel('br.com.workholyia.workholy_mobile/sharing')
              .invokeMethod<bool>('compartilharTexto', {
                'titulo': 'Treino de ${_aluno.nome}',
                'texto': linhas.join('\n'),
              });
      if (!mounted) return;
      if (compartilhado != true) {
        _mensagem('O compartilhamento foi cancelado.');
      }
    } on PlatformException catch (erro) {
      if (mounted) {
        _mensagem('Não foi possível compartilhar o treino: ${erro.message}');
      }
    } on MissingPluginException {
      if (mounted) _mensagem('Compartilhamento disponível somente no Android.');
    }
  }

  String _duracao(SessaoTreino sessao) {
    final fim = sessao.fim ?? DateTime.now();
    final minutos = fim.difference(sessao.inicio).inMinutes;
    if (minutos < 60) return '$minutos min';
    return '${minutos ~/ 60}h ${minutos % 60}min';
  }

  Map<String, double> get _recordes {
    final recordes = <String, double>{};
    for (final sessao in _sessoes.where((sessao) => sessao.finalizada)) {
      for (final serie in sessao.series.where((serie) => serie.concluida)) {
        final anterior = recordes[serie.nomeExercicio] ?? 0;
        if (serie.cargaKg > anterior) {
          recordes[serie.nomeExercicio] = serie.cargaKg;
        }
      }
    }
    return recordes;
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final sessoesConcluidas =
        _sessoes.where((sessao) => sessao.finalizada).toList()
          ..sort((a, b) => b.inicio.compareTo(a.inicio));
    final hoje = DateTime.now();
    final inicioSemana = DateTime(
      hoje.year,
      hoje.month,
      hoje.day,
    ).subtract(Duration(days: hoje.weekday - 1));
    final sessoesSemana = sessoesConcluidas
        .where((sessao) => !sessao.fim!.isBefore(inicioSemana))
        .length;
    final treinosAtribuidos = widget.treinos
        .where((treino) => _aluno.treinoIds.contains(treino.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_aluno.nome),
        actions: [
          IconButton(
            tooltip: 'Editar aluno',
            onPressed: _editarAluno,
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (valor) {
              if (valor == 'excluir') _excluirAluno();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'excluir', child: Text('Excluir cadastro')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Chip(
                        avatar: Icon(
                          _aluno.status == 'ativo'
                              ? Icons.check_circle_outline
                              : _aluno.status == 'pausado'
                              ? Icons.pause_circle_outline
                              : Icons.remove_circle_outline,
                          size: 18,
                        ),
                        label: Text(_rotuloStatus(_aluno.status)),
                      ),
                      const Spacer(),
                      Text(
                        'Desde ${_formatarData(_aluno.inicio)}',
                        style: TextStyle(color: cores.onSurfaceVariant),
                      ),
                    ],
                  ),
                  if (_aluno.telefone.isNotEmpty ||
                      _aluno.email.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    if (_aluno.telefone.isNotEmpty)
                      Text('Telefone: ${_aluno.telefone}'),
                    if (_aluno.email.isNotEmpty)
                      Text('E-mail: ${_aluno.email}'),
                  ],
                  if (_aluno.objetivo.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('Objetivo: ${_aluno.objetivo}'),
                  ],
                  if (_aluno.nivel.isNotEmpty)
                    Text('Experiência: ${_aluno.nivel}'),
                  if (_aluno.disponibilidade.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Rotina: ${_aluno.disponibilidade}'),
                  ],
                  if (_aluno.preferencias.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Preferências: ${_aluno.preferencias}'),
                  ],
                  if (_aluno.observacoes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Observações: ${_aluno.observacoes}'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _IndicadorAluno(
                  rotulo: 'Treinos concluídos',
                  valor: '${sessoesConcluidas.length}',
                  icone: Icons.fitness_center,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _IndicadorAluno(
                  rotulo: 'Nesta semana',
                  valor: '$sessoesSemana',
                  icone: Icons.calendar_month,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _TituloSecaoAluno(
            titulo: 'Treinos atribuídos',
            detalhe: '${treinosAtribuidos.length} disponíveis',
          ),
          const SizedBox(height: 8),
          if (treinosAtribuidos.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Edite o cadastro para atribuir treinos já existentes.',
                  style: TextStyle(color: cores.onSurfaceVariant),
                ),
              ),
            )
          else
            ...treinosAtribuidos.map((treino) {
              final podeTreinar = _aluno.status == 'ativo';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(treino.nome),
                      subtitle: treino.objetivo.isEmpty
                          ? null
                          : Text(treino.objetivo),
                      trailing: IconButton(
                        tooltip: 'Compartilhar treino',
                        onPressed: () => _compartilharTreino(treino),
                        icon: const Icon(Icons.share_outlined),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: podeTreinar
                              ? () async {
                                  await widget.onIniciarTreino(
                                    treino.id,
                                    _aluno.id,
                                  );
                                  await _atualizarSessoes();
                                }
                              : null,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(
                            podeTreinar
                                ? 'Registrar treino do aluno'
                                : 'Aluno ${_rotuloStatus(_aluno.status).toLowerCase()}',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 16),
          _TituloSecaoAluno(
            titulo: 'Histórico individual',
            detalhe: '${sessoesConcluidas.length} concluídos',
          ),
          const SizedBox(height: 8),
          if (sessoesConcluidas.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Os treinos registrados para este aluno aparecerão aqui.',
                  style: TextStyle(color: cores.onSurfaceVariant),
                ),
              ),
            )
          else
            ...sessoesConcluidas.map(
              (sessao) => Card(
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(sessao.nomeTreino),
                  subtitle: Text(
                    '${_formatarData(sessao.inicio)} • '
                    '${sessao.seriesConcluidas}/${sessao.series.length} séries • '
                    '${_duracao(sessao)}',
                  ),
                  isThreeLine: true,
                ),
              ),
            ),
          if (_recordes.isNotEmpty) ...[
            const SizedBox(height: 16),
            const _TituloSecaoAluno(titulo: 'Maiores cargas registradas'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: _recordes.entries
                    .map(
                      (item) => ListTile(
                        dense: true,
                        title: Text(item.key),
                        trailing: Text(
                          PreferenciaUnidadeCarga.instancia.formatar(
                            item.value,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _TituloSecaoAluno(
            titulo: 'Anotações do treinador',
            detalhe: 'Privadas neste aparelho',
            acao: IconButton(
              tooltip: 'Nova anotação',
              onPressed: _novaAnotacao,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ),
          const SizedBox(height: 8),
          if (_carregandoAnotacoes)
            const Center(child: CircularProgressIndicator())
          else if (_anotacoes.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Nenhuma anotação registrada.',
                  style: TextStyle(color: cores.onSurfaceVariant),
                ),
              ),
            )
          else
            ..._anotacoes.map(
              (anotacao) => Card(
                child: ListTile(
                  title: Text(anotacao.texto),
                  subtitle: Text(_formatarDataHora(anotacao.criadaEm)),
                  trailing: IconButton(
                    tooltip: 'Excluir anotação',
                    onPressed: () => _excluirAnotacao(anotacao),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IndicadorAluno extends StatelessWidget {
  const _IndicadorAluno({
    required this.rotulo,
    required this.valor,
    required this.icone,
  });

  final String rotulo;
  final String valor;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, color: cores.primary),
            const SizedBox(height: 8),
            Text(
              valor,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(rotulo, style: TextStyle(color: cores.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _TituloSecaoAluno extends StatelessWidget {
  const _TituloSecaoAluno({required this.titulo, this.detalhe, this.acao});

  final String titulo;
  final String? detalhe;
  final Widget? acao;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (detalhe case final detalhe?)
              Text(
                detalhe,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
      ?acao,
    ],
  );
}

String _formatarData(DateTime data) =>
    '${data.day.toString().padLeft(2, '0')}/'
    '${data.month.toString().padLeft(2, '0')}/${data.year}';

String _formatarDataHora(DateTime data) =>
    '${_formatarData(data)} ${data.hour.toString().padLeft(2, '0')}:'
    '${data.minute.toString().padLeft(2, '0')}';
