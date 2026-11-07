import 'package:flutter/material.dart';

class PlanoPremiumPage extends StatelessWidget {
  const PlanoPremiumPage({super.key, this.recurso});

  final String? recurso;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Moveria Premium')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            Icons.workspace_premium_outlined,
            size: 64,
            color: cores.primary,
          ),
          const SizedBox(height: 16),
          const Text(
            'Evolua com o Premium',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            recurso == null
                ? 'Desbloqueie os recursos avançados do Moveria.'
                : 'O recurso “$recurso” faz parte do Moveria Premium.',
            style: TextStyle(color: cores.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          Card(
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
                      color: cores.primary,
                    ),
                  ),
                  Text(
                    'por mês',
                    style: TextStyle(color: cores.onSurfaceVariant),
                  ),
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
              backgroundColor: cores.primary,
              foregroundColor: cores.onPrimary,
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'A compra será feita com segurança pelo Google Play quando o aplicativo for publicado.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cores.onSurfaceVariant, fontSize: 12),
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
        Icon(
          Icons.check_circle,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(texto)),
      ],
    ),
  );
}
