import 'package:flutter/material.dart';

import '../alunos/aluno.dart';
import '../lembretes/lembretes_treino.dart';
import 'agendamento.dart';
import 'avisos_agenda.dart';

String formatarHora(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String formatarDiaCurto(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Horários marcados dos alunos. Salva sozinha e avisa quando a lista muda.
class AgendaPage extends StatefulWidget {
  final List<Aluno> alunos;
  final VoidCallback onAlterou;

  const AgendaPage({super.key, required this.alunos, required this.onAlterou});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  List<Agendamento> _agenda = [];
  bool _carregando = true;
  int _aviso = avisoAgendaPadrao;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final lista = await AgendaRepositorio.instancia.carregar();
    final aviso = await LembretesTreino.instancia.lerAvisoAgenda();
    if (mounted) {
      setState(() {
        _agenda = lista;
        _aviso = aviso;
        _carregando = false;
      });
    }
  }

  Future<void> _escolherAviso() async {
    final escolhido = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Avisar no celular'),
        children: [
          RadioGroup<int>(
            groupValue: _aviso,
            onChanged: (v) => Navigator.of(ctx).pop(v),
            child: Column(
              children: [
                for (final m in avisoAgendaOpcoes)
                  RadioListTile<int>(
                    value: m,
                    title: Text(rotuloAvisoAgenda(m)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (escolhido == null || escolhido == _aviso) return;
    await LembretesTreino.instancia.salvarAvisoAgenda(escolhido);
    if (mounted) setState(() => _aviso = escolhido);
    widget.onAlterou();
  }

  Future<void> _persistir(List<Agendamento> nova) async {
    await AgendaRepositorio.instancia.salvar(nova);
    if (mounted) setState(() => _agenda = nova);
    widget.onAlterou();
  }

  String _nomeAluno(String id) {
    for (final a in widget.alunos) {
      if (a.id == id) return a.nome;
    }
    return 'Aluno removido';
  }

  Future<void> _editar([Agendamento? existente]) async {
    final resultado = await showDialog<Agendamento>(
      context: context,
      builder: (_) => FormularioAgendamentoDialog(
        alunos: widget.alunos,
        existente: existente,
      ),
    );
    if (resultado == null) return;
    await _persistir([..._agenda.where((a) => a.id != resultado.id), resultado]);
  }

  Future<void> _excluir(Agendamento agendamento) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir horário?'),
        content: Text(
          '${_nomeAluno(agendamento.alunoId)} • '
          '${formatarDiaCurto(agendamento.inicio)} às ${formatarHora(agendamento.inicio)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await _persistir(_agenda.where((a) => a.id != agendamento.id).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final grupos = agruparPorDia(_agenda, DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda dos alunos'),
        actions: [
          TextButton.icon(
            onPressed: _escolherAviso,
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text(rotuloAvisoAgenda(_aviso)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.alunos.isEmpty ? null : () => _editar(),
        icon: const Icon(Icons.add),
        label: const Text('Novo horário'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 90),
              children: [
                if (widget.alunos.isEmpty)
                  const Text('Cadastre um aluno antes de marcar horários.')
                else if (grupos.isEmpty)
                  const Text('Nenhum horário marcado a partir de hoje.'),
                for (final entrada in grupos.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                    child: Text(
                      formatarDiaCurto(entrada.key),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  for (final a in entrada.value)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => _editar(a),
                        leading: Text(
                          formatarHora(a.inicio),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        title: Text(_nomeAluno(a.alunoId)),
                        subtitle: Text(
                          [
                            if (a.local.isNotEmpty) a.local,
                            if (a.observacoes.isNotEmpty) a.observacoes,
                          ].join(' • '),
                        ),
                        trailing: IconButton(
                          tooltip: 'Excluir horário',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _excluir(a),
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

class FormularioAgendamentoDialog extends StatefulWidget {
  final List<Aluno> alunos;
  final Agendamento? existente;

  const FormularioAgendamentoDialog({
    super.key,
    required this.alunos,
    this.existente,
  });

  @override
  State<FormularioAgendamentoDialog> createState() =>
      _FormularioAgendamentoDialogState();
}

class _FormularioAgendamentoDialogState
    extends State<FormularioAgendamentoDialog> {
  late String? _alunoId;
  late DateTime _data;
  late TimeOfDay _hora;
  late final TextEditingController _local;
  late final TextEditingController _observacoes;

  @override
  void initState() {
    super.initState();
    final e = widget.existente;
    final agora = DateTime.now();
    _alunoId = widget.alunos.any((a) => a.id == e?.alunoId)
        ? e!.alunoId
        : (widget.alunos.length == 1 ? widget.alunos.first.id : null);
    _data = e == null
        ? DateTime(agora.year, agora.month, agora.day)
        : DateTime(e.inicio.year, e.inicio.month, e.inicio.day);
    _hora = e == null
        ? const TimeOfDay(hour: 8, minute: 0)
        : TimeOfDay(hour: e.inicio.hour, minute: e.inicio.minute);
    _local = TextEditingController(text: e?.local ?? '');
    _observacoes = TextEditingController(text: e?.observacoes ?? '');
  }

  @override
  void dispose() {
    _local.dispose();
    _observacoes.dispose();
    super.dispose();
  }

  Future<void> _escolherData() async {
    final hoje = DateTime.now();
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(hoje.year - 1),
      lastDate: DateTime(hoje.year + 3),
    );
    if (escolhida != null) setState(() => _data = escolhida);
  }

  Future<void> _escolherHora() async {
    final escolhida = await showTimePicker(
      context: context,
      initialTime: _hora,
    );
    if (escolhida != null) setState(() => _hora = escolhida);
  }

  void _salvar() {
    if (_alunoId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Escolha o aluno.')));
      return;
    }
    Navigator.of(context).pop(
      Agendamento(
        id: widget.existente?.id,
        alunoId: _alunoId!,
        inicio: DateTime(
          _data.year,
          _data.month,
          _data.day,
          _hora.hour,
          _hora.minute,
        ),
        local: _local.text.trim(),
        observacoes: _observacoes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existente == null ? 'Novo horário' : 'Editar horário'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _alunoId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Aluno'),
              items: [
                for (final a in widget.alunos)
                  DropdownMenuItem(value: a.id, child: Text(a.nome)),
              ],
              onChanged: (v) => setState(() => _alunoId = v),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _escolherData,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(formatarDiaCurto(_data)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _escolherHora,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(
                      '${_hora.hour.toString().padLeft(2, '0')}:'
                      '${_hora.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _local,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Local do treino',
                hintText: 'Ex.: Academia Central, Praça, casa do aluno',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _observacoes,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Observações'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _salvar, child: const Text('Salvar')),
      ],
    );
  }
}
