
import 'package:flutter/material.dart';

class TutorialPrimeiroAcessoPage extends StatefulWidget {
  const TutorialPrimeiroAcessoPage({super.key});

  @override
  State<TutorialPrimeiroAcessoPage> createState() =>
      _TutorialPrimeiroAcessoPageState();
}

class _TutorialPrimeiroAcessoPageState
    extends State<TutorialPrimeiroAcessoPage> {
  final PageController _pageController = PageController();
  int _indiceAtual = 0;

  final List<_EtapaTutorial> _etapas = const [
    _EtapaTutorial(
      icone: Icons.waving_hand_outlined,
      titulo: 'Bem-vindo ao WorkHoly!',
      descricao:
          'Organize seus treinos, acompanhe suas atividades e mantenha '
          'seu planejamento de treinamento em um só lugar.',
      dica: 'Vamos conhecer as principais funções do aplicativo.',
    ),
    _EtapaTutorial(
      icone: Icons.fitness_center,
      titulo: 'Crie seus treinos',
      descricao:
          'Acesse a área Treinos para cadastrar seus planejamentos e '
          'organizar os exercícios de cada sessão.',
      dica: 'Comece com um treino simples e adicione exercícios aos poucos.',
    ),
    _EtapaTutorial(
      icone: Icons.play_circle_outline,
      titulo: 'Realize suas sessões',
      descricao:
          'Use as funções disponíveis no treino para acompanhar sua '
          'execução e registrar suas atividades.',
      dica: 'Consulte os detalhes do treino antes de começar.',
    ),
    _EtapaTutorial(
      icone: Icons.history,
      titulo: 'Acompanhe seu histórico',
      descricao:
          'Consulte as sessões registradas para acompanhar sua rotina '
          'e visualizar suas atividades anteriores.',
      dica: 'Volte ao histórico sempre que quiser consultar seus registros.',
    ),
  ];

  void _voltar() {
    if (_indiceAtual == 0) return;

    _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _avancar() {
    if (_indiceAtual < _etapas.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop(true);
    }
  }

  void _pular() {
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    final ultimaEtapa = _indiceAtual == _etapas.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Primeiros passos'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _pular,
            child: const Text('Pular'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              Row(
                children: List.generate(
                  _etapas.length,
                  (indice) => Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: indice <= _indiceAtual
                            ? cores.primary
                            : cores.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Etapa ${_indiceAtual + 1} de ${_etapas.length}',
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: cores.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _etapas.length,
                  onPageChanged: (indice) {
                    setState(() => _indiceAtual = indice);
                  },
                  itemBuilder: (context, indice) {
                    final item = _etapas[indice];

                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight:
                              MediaQuery.sizeOf(context).height * 0.48,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 132,
                              height: 132,
                              decoration: BoxDecoration(
                                color: cores.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                item.icone,
                                size: 66,
                                color: cores.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              item.titulo,
                              textAlign: TextAlign.center,
                              style: tema.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              item.descricao,
                              textAlign: TextAlign.center,
                              style: tema.textTheme.bodyLarge?.copyWith(
                                height: 1.6,
                                color: cores.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cores.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline,
                                    color: cores.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.dica,
                                      style: tema.textTheme.bodyMedium?.copyWith(
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (_indiceAtual > 0)
                    OutlinedButton(
                      onPressed: _voltar,
                      child: const Text('Voltar'),
                    ),
                  if (_indiceAtual > 0) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _avancar,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          ultimaEtapa ? 'Começar a treinar' : 'Continuar',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EtapaTutorial {
  final IconData icone;
  final String titulo;
  final String descricao;
  final String dica;

  const _EtapaTutorial({
    required this.icone,
    required this.titulo,
    required this.descricao,
    required this.dica,
  });
}
