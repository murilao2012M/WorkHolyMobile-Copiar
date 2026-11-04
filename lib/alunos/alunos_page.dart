import 'package:flutter/material.dart';

import 'aluno.dart';

/// Lista de alunos do personal. Toque abre os treinos do aluno.
class AlunosPage extends StatelessWidget {
  final List<Aluno> alunos;
  final int Function(String alunoId) contarTreinos;
  final ValueChanged<Aluno> onAbrirTreinos;
  final Future<void> Function(Aluno aluno) onSalvar;
  final Future<void> Function(Aluno aluno) onExcluir;

  const AlunosPage({
    super.key,
    required this.alunos,
    required this.contarTreinos,
    required this.onAbrirTreinos,
    required this.onSalvar,
    required this.onExcluir,
  });

  Future<void> _editar(BuildContext context, [Aluno? existente]) async {
    final resultado = await showDialog<Aluno>(
      context: context,
      builder: (_) => FormularioAlunoDialog(existente: existente),
    );
    if (resultado != null) await onSalvar(resultado);
  }

  Future<void> _excluir(BuildContext context, Aluno aluno) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir aluno?'),
        content: Text(
          'Os treinos de "${aluno.nome}" não serão apagados: '
          'eles ficam sem aluno vinculado.',
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
    if (confirmar == true) await onExcluir(aluno);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Alunos',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton.filled(
              tooltip: 'Novo aluno',
              onPressed: () => _editar(context),
              icon: const Icon(Icons.person_add_alt_1),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${alunos.length} ${alunos.length == 1 ? 'aluno cadastrado' : 'alunos cadastrados'}',
        ),
        const SizedBox(height: 14),
        if (alunos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Text(
              'Cadastre seu primeiro aluno para montar treinos individuais.',
              textAlign: TextAlign.center,
            ),
          ),
        ...alunos.map((aluno) {
          final total = contarTreinos(aluno.id);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              onTap: () => onAbrirTreinos(aluno),
              leading: CircleAvatar(
                child: Text(
                  aluno.nome.isEmpty ? '?' : aluno.nome[0].toUpperCase(),
                ),
              ),
              title: Text(aluno.nome),
              subtitle: Text(
                [
                  if (aluno.objetivo.isNotEmpty) aluno.objetivo,
                  '$total ${total == 1 ? 'treino' : 'treinos'}',
                ].join(' • '),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (opcao) {
                  if (opcao == 'editar') _editar(context, aluno);
                  if (opcao == 'excluir') _excluir(context, aluno);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'editar', child: Text('Editar aluno')),
                  PopupMenuItem(value: 'excluir', child: Text('Excluir aluno')),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class FormularioAlunoDialog extends StatefulWidget {
  final Aluno? existente;

  const FormularioAlunoDialog({super.key, this.existente});

  @override
  State<FormularioAlunoDialog> createState() => _FormularioAlunoDialogState();
}

class _FormularioAlunoDialogState extends State<FormularioAlunoDialog> {
  late final TextEditingController _nome;
  late final TextEditingController _telefone;
  late final TextEditingController _objetivo;
  late final TextEditingController _observacoes;

  @override
  void initState() {
    super.initState();
    final a = widget.existente;
    _nome = TextEditingController(text: a?.nome ?? '');
    _telefone = TextEditingController(text: a?.telefone ?? '');
    _objetivo = TextEditingController(text: a?.objetivo ?? '');
    _observacoes = TextEditingController(text: a?.observacoes ?? '');
  }

  @override
  void dispose() {
    _nome.dispose();
    _telefone.dispose();
    _objetivo.dispose();
    _observacoes.dispose();
    super.dispose();
  }

  void _salvar() {
    final nome = _nome.text.trim();
    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome do aluno.')),
      );
      return;
    }
    final existente = widget.existente;
    final telefone = _telefone.text.trim();
    final objetivo = _objetivo.text.trim();
    final observacoes = _observacoes.text.trim();
    Navigator.of(context).pop(
      existente == null
          ? Aluno(
              nome: nome,
              telefone: telefone,
              objetivo: objetivo,
              observacoes: observacoes,
            )
          : existente.copiarCom(
              nome: nome,
              telefone: telefone,
              objetivo: objetivo,
              observacoes: observacoes,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existente == null ? 'Novo aluno' : 'Editar aluno'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nome,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _telefone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefone'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _objetivo,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Objetivo',
                hintText: 'Ex.: Hipertrofia',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _observacoes,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observações',
                hintText: 'Lesões, restrições, horários...',
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
        ElevatedButton(onPressed: _salvar, child: const Text('Salvar')),
      ],
    );
  }
}
