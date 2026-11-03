import 'package:flutter/material.dart' hide Icon;

import '../painel/w_icone.dart';

const _verdePremium = Color(0xFFC6F432);
const _textoPremium = Color(0xFF9AA0AB);

class PlanoPremiumPage extends StatelessWidget {
  const PlanoPremiumPage({super.key, this.recurso});

  final String? recurso;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WorkHoly')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.workspace_premium, size: 64, color: _verdePremium),
          const SizedBox(height: 16),
          const Text(
            'Todos os recursos liberados!',
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            recurso == null
                ? 'Aproveite gratuitamente todos os recursos do WorkHoly.'
                : 'O recurso "$recurso" está liberado gratuitamente para você.',
            style: const TextStyle(color: _textoPremium),
          ),
          const SizedBox(height: 24),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Beneficio('Biblioteca completa de exercícios'),
                  _Beneficio('Metas pessoais'),
                  _Beneficio('Avaliações físicas e histórico'),
                  _Beneficio('Gráficos de desempenho e evolução'),
                  _Beneficio('Todos os recursos de treinamento'),
                  _Beneficio('WorkFit e recursos disponíveis no aplicativo'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Aproveitar recursos gratuitos'),
            style: FilledButton.styleFrom(
              backgroundColor: _verdePremium,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Nesta fase, todos os recursos estão disponíveis gratuitamente.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _textoPremium, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Beneficio extends StatelessWidget {
  const _Beneficio(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        const Icon(Icons.check_circle, color: _verdePremium, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(texto)),
      ],
    ),
  );
}
