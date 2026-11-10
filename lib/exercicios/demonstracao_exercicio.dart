import 'package:flutter/material.dart' hide Icon;

import '../painel/w_icone.dart';

import 'biblioteca_exercicios.dart';

class DemonstracaoExercicio extends StatelessWidget {
  const DemonstracaoExercicio({
    super.key,
    required this.catalogoId,
    required this.nomeExercicio,
    required this.carregarCatalogo,
    required this.habilitado,
    required this.onSelecionar,
  });

  final String? catalogoId;
  final String nomeExercicio;
  final Future<List<ExercicioPredefinido>> Function() carregarCatalogo;
  final bool habilitado;
  final Future<void> Function(String) onSelecionar;

  Future<void> _selecionar(BuildContext context) async {
    final escolhido = await showModalBottomSheet<ExercicioPredefinido>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SelecionarDemonstracao(
        nomeExercicio: nomeExercicio,
        carregarCatalogo: carregarCatalogo,
      ),
    );
    if (escolhido == null || !context.mounted) return;
    await onSelecionar(escolhido.id);
  }

  @override
  Widget build(BuildContext context) {
    if (catalogoId == null || catalogoId!.isEmpty) {
      return _semDemonstracao(
        context,
        'Este exercício ainda não está vinculado a uma demonstração.',
      );
    }

    return FutureBuilder<List<ExercicioPredefinido>>(
      future: carregarCatalogo(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Não foi possível carregar as demonstrações do catálogo.',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          );
        }
        ExercicioPredefinido? exercicio;
        for (final item in snapshot.data!) {
          if (item.id == catalogoId) {
            exercicio = item;
            break;
          }
        }
        if (exercicio == null) {
          return _semDemonstracao(
            context,
            'A demonstração vinculada não foi encontrada no catálogo.',
          );
        }

        final imagens = exercicio.caminhosImagensAssets;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Como executar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (exercicio.nome != nomeExercicio)
                Text('Demonstração: ${exercicio.nome}'),
              const SizedBox(height: 8),
              if (imagens.isEmpty)
                const Text('Este exercício não possui imagens no catálogo.')
              else ...[
                SizedBox(
                  height: 190,
                  child: PageView.builder(
                    key: ValueKey('imagens-${exercicio.id}'),
                    itemCount: imagens.length,
                    itemBuilder: (context, indice) => ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: Image.asset(
                          imagens[indice],
                          fit: BoxFit.contain,
                          width: double.infinity,
                          semanticLabel:
                              'Demonstração de ${exercicio!.nome}, imagem ${indice + 1} de ${imagens.length}',
                          errorBuilder: (context, erro, stackTrace) {
                            debugPrint(
                              'Erro ao carregar imagem ${imagens[indice]}: $erro',
                            );
                            return const Text(
                              'Imagem indisponível neste aparelho.',
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                if (imagens.length > 1)
                  Text(
                    'Deslize para ver as ${imagens.length} imagens do movimento.',
                  ),
              ],
              if (exercicio.instrucoes.isNotEmpty)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Ver instruções'),
                  children: [
                    for (final entrada in exercicio.instrucoes.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('${entrada.$1 + 1}. ${entrada.$2}'),
                        ),
                      ),
                  ],
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Este exercício não possui instruções no catálogo.',
                  ),
                ),
              const Text(
                'Imagens e instruções: Free Exercise DB. Revise a execução com um profissional.',
                style: TextStyle(fontSize: 12),
              ),
              TextButton.icon(
                onPressed: habilitado ? () => _selecionar(context) : null,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Alterar demonstração'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _semDemonstracao(BuildContext context, String mensagem) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(mensagem),
          TextButton.icon(
            onPressed: habilitado ? () => _selecionar(context) : null,
            icon: const Icon(Icons.image_search),
            label: const Text('Escolher demonstração'),
          ),
        ],
      ),
    );
  }
}

class _SelecionarDemonstracao extends StatefulWidget {
  const _SelecionarDemonstracao({
    required this.nomeExercicio,
    required this.carregarCatalogo,
  });

  final String nomeExercicio;
  final Future<List<ExercicioPredefinido>> Function() carregarCatalogo;

  @override
  State<_SelecionarDemonstracao> createState() =>
      _SelecionarDemonstracaoState();
}

class _SelecionarDemonstracaoState extends State<_SelecionarDemonstracao> {
  late final Future<List<ExercicioPredefinido>> _catalogo;
  String _busca = '';

  @override
  void initState() {
    super.initState();
    _catalogo = widget.carregarCatalogo();
  }

  Future<void> _confirmar(ExercicioPredefinido item) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Usar esta demonstração?'),
        content: Text(
          'Vincular "${item.nome}" (${item.grupo}) ao exercício '
          '"${widget.nomeExercicio}" nesta sessão? Confira se são o mesmo movimento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Usar demonstração'),
          ),
        ],
      ),
    );
    if (confirmar == true && mounted) Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final altura = MediaQuery.sizeOf(context).height;
    final teclado = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: teclado),
      child: SizedBox(
        height: (altura * 0.8 - teclado).clamp(180.0, altura * 0.8),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Escolher demonstração',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (valor) =>
                    setState(() => _busca = valor.trim().toLowerCase()),
                decoration: const InputDecoration(
                  labelText: 'Pesquisar exercício',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<ExercicioPredefinido>>(
                future: _catalogo,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Não foi possível carregar o catálogo.'),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final resultados = snapshot.data!
                      .where(
                        (item) =>
                            '${item.nome} ${item.grupo} ${item.equipamento}'
                                .toLowerCase()
                                .contains(_busca),
                      )
                      .toList();
                  if (resultados.isEmpty) {
                    return const Center(
                      child: Text('Nenhum exercício encontrado.'),
                    );
                  }
                  return ListView.builder(
                    itemCount: resultados.length,
                    itemBuilder: (context, indice) {
                      final item = resultados[indice];
                      return ListTile(
                        title: Text(item.nome),
                        subtitle: Text(
                          '${item.grupo} • ${item.equipamentoParaFiltro}'
                          '${item.imagens.isEmpty ? ' • Sem imagens' : ''}',
                        ),
                        onTap: () => _confirmar(item),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
