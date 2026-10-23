import 'package:flutter/material.dart';

const _verdePremium = Color(0xFFB7F34A);
const _textoPremium = Color(0xFFA4AAA0);

class PlanoPremiumPage extends StatelessWidget {
  const PlanoPremiumPage({super.key, this.recurso});

  final String? recurso;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WorkHoly Premium')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(
            Icons.workspace_premium_outlined,
            size: 64,
            color: _verdePremium,
          ),
          const SizedBox(height: 16),
          const Text(
            'Evolua com o Premium',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            recurso == null
                ? 'Desbloqueie os recursos avançados do WorkHoly.'
                : 'O recurso “$recurso” faz parte do WorkHoly Premium.',
            style: const TextStyle(color: _textoPremium),
          ),
          const SizedBox(height: 28),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Premium',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'R\$ 9,90',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: _verdePremium,
                    ),
                  ),
                  Text('por mês', style: TextStyle(color: _textoPremium)),
                  SizedBox(height: 18),
                  _Beneficio('Biblioteca de exercícios completa'),
                  _Beneficio('Metas pessoais com prazo'),
                  _Beneficio('Avaliações físicas com histórico'),
                  _Beneficio('Gráficos de desempenho e evolução'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'A assinatura será liberada quando o app estiver no Google Play.',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Disponível em breve no Google Play'),
            style: FilledButton.styleFrom(
              backgroundColor: _verdePremium,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'A compra será feita com segurança pelo Google Play quando o aplicativo for publicado.',
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
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        const Icon(Icons.check_circle, color: _verdePremium, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(texto)),
      ],
    ),
  );
}
