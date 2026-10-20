
import 'package:flutter/material.dart';

import 'workholy_aparencia.dart';

class AparenciaPage extends StatelessWidget {
  const AparenciaPage({
    super.key,
    required this.aparencia,
  });

  final WorkHolyAparencia aparencia;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: aparencia,
      builder: (context, _) {
        final tema = Theme.of(context);
        final destaque = aparencia.corDestaque;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Aparência'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Personalize seu WorkHoly',
                style: tema.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Escolha o tema e a cor que combinam com você.',
                style: tema.textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),

              Text(
                'Tema do aplicativo',
                style: tema.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              _OpcaoTema(
                titulo: 'Escuro',
                descricao: 'Fundo escuro e visual esportivo.',
                icone: Icons.dark_mode_outlined,
                selecionado: aparencia.modo == ModoAparencia.escuro,
                aoSelecionar: () =>
                    aparencia.definirModo(ModoAparencia.escuro),
              ),
              _OpcaoTema(
                titulo: 'Claro',
                descricao: 'Fundo claro e maior luminosidade.',
                icone: Icons.light_mode_outlined,
                selecionado: aparencia.modo == ModoAparencia.claro,
                aoSelecionar: () =>
                    aparencia.definirModo(ModoAparencia.claro),
              ),
              _OpcaoTema(
                titulo: 'Automático',
                descricao: 'Acompanha o tema do celular.',
                icone: Icons.brightness_auto_outlined,
                selecionado: aparencia.modo == ModoAparencia.automatico,
                aoSelecionar: () =>
                    aparencia.definirModo(ModoAparencia.automatico),
              ),

              const SizedBox(height: 28),

              Text(
                'Cor de destaque',
                style: tema.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Aplicada aos botões, seleções e elementos de destaque.',
                style: tema.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),

              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: List.generate(
                  WorkHolyAparencia.cores.length,
                  (indice) {
                    final cor = WorkHolyAparencia.cores[indice];
                    final selecionada = aparencia.indiceCor == indice;

                    const nomes = [
                      'Verde-limão',
                      'Azul',
                      'Roxo',
                      'Vermelho',
                      'Laranja',
                    ];

                    return Semantics(
                      button: true,
                      selected: selecionada,
                      label: nomes[indice],
                      child: InkWell(
                        onTap: () => aparencia.definirCor(indice),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 92,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selecionada
                                  ? cor
                                  : tema.dividerColor,
                              width: selecionada ? 2.5 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: cor,
                                child: selecionada
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.black,
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                nomes[indice],
                                textAlign: TextAlign.center,
                                style: tema.textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'Prévia',
                style: tema.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: destaque,
                            foregroundColor: Colors.black,
                            child: const Icon(Icons.fitness_center),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Meu treinamento',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text('Exemplo de cartão'),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.check_circle,
                            color: destaque,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: 0.7,
                          minHeight: 8,
                          color: destaque,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.check),
                          label: const Text('Botão de exemplo'),
                          style: FilledButton.styleFrom(
                            backgroundColor: destaque,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              OutlinedButton.icon(
                onPressed: () async {
                  await aparencia.definirModo(ModoAparencia.escuro);
                  await aparencia.definirCor(0);
                },
                icon: const Icon(Icons.restart_alt),
                label: const Text('Restaurar aparência padrão'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OpcaoTema extends StatelessWidget {
  const _OpcaoTema({
    required this.titulo,
    required this.descricao,
    required this.icone,
    required this.selecionado,
    required this.aoSelecionar,
  });

  final String titulo;
  final String descricao;
  final IconData icone;
  final bool selecionado;
  final VoidCallback aoSelecionar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icone),
        title: Text(titulo),
        subtitle: Text(descricao),
        trailing: Icon(
          selecionado
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
          color: selecionado ? tema.colorScheme.primary : null,
        ),
        selected: selecionado,
        onTap: aoSelecionar,
      ),
    );
  }
}