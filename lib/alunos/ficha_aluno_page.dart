import 'package:flutter/material.dart';

import 'aluno.dart';
import 'resumo_aluno.dart';

class TreinoDoAluno {
  final String id;
  final String nome;
  final String objetivo;
  final int exercicios;

  const TreinoDoAluno(this.id, this.nome, this.objetivo, this.exercicios);
}

/// Ficha do aluno: treinos, histórico de sessões e evolução de carga.
class FichaAlunoPage extends StatelessWidget {
  final Aluno aluno;
  final List<TreinoDoAluno> treinos;
  final List<SessaoAluno> sessoes;
  final ValueChanged<String> onAbrirTreino;
  final VoidCallback onNovoTreino;

  const FichaAlunoPage({
    super.key,
    required this.aluno,
    required this.treinos,
    required this.sessoes,
    required this.onAbrirTreino,
    required this.onNovoTreino,
  });

  static String _data(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _kg(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final resumo = calcularResumoAluno(sessoes, DateTime.now());
    final recentes = [...sessoes]..sort((a, b) => b.inicio.compareTo(a.inicio));
    final estilo = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(aluno.nome)),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (aluno.objetivo.isNotEmpty) Text('Objetivo: ${aluno.objetivo}'),
          if (aluno.telefone.isNotEmpty) Text('Telefone: ${aluno.telefone}'),
          if (aluno.observacoes.isNotEmpty)
            Text('Observações: ${aluno.observacoes}'),
          const SizedBox(height: 16),
          Text('Resumo', style: estilo.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Indicador('Sessões', '${resumo.totalSessoes}'),
              _Indicador(
                'Último treino',
                resumo.ultimaSessao == null
                    ? '—'
                    : _data(resumo.ultimaSessao!),
              ),
              _Indicador('Volume total', '${_kg(resumo.volumeTotalKg)} kg'),
            ],
          ),
          const SizedBox(height: 18),
          Text('Frequência (últimas 4 semanas)', style: estilo.titleMedium),
          const SizedBox(height: 8),
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${i == 3 ? 'Esta semana' : 'Há ${3 - i} semana${3 - i == 1 ? '' : 's'}'}: '
                '${resumo.sessoesPorSemana[i]} '
                '${resumo.sessoesPorSemana[i] == 1 ? 'sessão' : 'sessões'}',
              ),
            ),
          const SizedBox(height: 18),
          Text('Evolução de carga', style: estilo.titleMedium),
          const SizedBox(height: 8),
          if (resumo.evolucao.isEmpty)
            const Text(
              'Aparece quando o mesmo exercício for feito com carga em '
              'pelo menos duas sessões.',
            )
          else
            ...resumo.evolucao.map(
              (e) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(e.nome),
                subtitle: Text(
                  '${_kg(e.cargaInicial)} kg → ${_kg(e.cargaAtual)} kg',
                ),
                trailing: Text(
                  '${e.diferenca >= 0 ? '+' : ''}${_kg(e.diferenca)} kg',
                ),
              ),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: Text('Treinos', style: estilo.titleMedium)),
              TextButton.icon(
                onPressed: onNovoTreino,
                icon: const Icon(Icons.add),
                label: const Text('Novo treino'),
              ),
            ],
          ),
          if (treinos.isEmpty)
            const Text('Nenhum treino vinculado a este aluno.')
          else
            ...treinos.map(
              (t) => Card(
                child: ListTile(
                  onTap: () => onAbrirTreino(t.id),
                  title: Text(t.nome),
                  subtitle: Text(
                    [
                      if (t.objetivo.isNotEmpty) t.objetivo,
                      '${t.exercicios} ${t.exercicios == 1 ? 'exercício' : 'exercícios'}',
                    ].join(' • '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            ),
          const SizedBox(height: 18),
          Text('Histórico', style: estilo.titleMedium),
          const SizedBox(height: 8),
          if (recentes.isEmpty)
            const Text('Nenhuma sessão finalizada ainda.')
          else
            ...recentes
                .take(30)
                .map(
                  (s) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.nomeTreino),
                    subtitle: Text(
                      '${_data(s.inicio)} • ${s.fim.difference(s.inicio).inMinutes} min • '
                      '${s.seriesConcluidas} séries • ${_kg(s.volumeKg)} kg',
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _Indicador extends StatelessWidget {
  final String rotulo;
  final String valor;

  const _Indicador(this.rotulo, this.valor);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: Theme.of(context).textTheme.bodySmall),
          Text(valor, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
