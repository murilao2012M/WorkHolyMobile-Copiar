import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'midia_exercicio.dart';

/// Faixa horizontal com as mídias do exercício. Toque abre em tela cheia.
class MidiasDoExercicio extends StatelessWidget {
  final List<MidiaExercicio> midias;
  final void Function(MidiaExercicio midia)? onRemover;

  const MidiasDoExercicio({super.key, required this.midias, this.onRemover});

  @override
  Widget build(BuildContext context) {
    if (midias.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(top: 6, right: 6),
        itemCount: midias.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final midia = midias[i];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              InkWell(
                onTap: () => abrirMidia(context, midia),
                child: _Miniatura(midia: midia),
              ),
              if (onRemover != null)
                Positioned(
                  top: -8,
                  right: -8,
                  child: IconButton(
                    tooltip: 'Remover',
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onRemover!(midia),
                    icon: const Icon(Icons.cancel, color: Colors.redAccent),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Miniatura extends StatelessWidget {
  final MidiaExercicio midia;

  const _Miniatura({required this.midia});

  @override
  Widget build(BuildContext context) {
    final Widget conteudo;
    switch (midia.tipo) {
      case TipoMidia.foto:
        conteudo = Image.file(
          File(midia.destino),
          fit: BoxFit.cover,
          width: 78,
          height: 78,
          cacheWidth: 240,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
        );
      case TipoMidia.video:
        conteudo = const Icon(Icons.play_circle_outline, size: 36);
      case TipoMidia.link:
        conteudo = const Icon(Icons.link, size: 32);
    }
    return Container(
      width: 78,
      height: 78,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      alignment: Alignment.center,
      child: conteudo,
    );
  }
}

Future<void> abrirMidia(BuildContext context, MidiaExercicio midia) async {
  switch (midia.tipo) {
    case TipoMidia.foto:
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => _FotoTelaCheia(midia: midia)),
      );
    case TipoMidia.video:
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => _VideoTelaCheia(midia: midia)),
      );
    case TipoMidia.link:
      final uri = validarLinkMidia(midia.destino);
      final abriu =
          uri != null &&
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!abriu && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o link.')),
        );
      }
  }
}

class _FotoTelaCheia extends StatelessWidget {
  final MidiaExercicio midia;

  const _FotoTelaCheia({required this.midia});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(midia.legenda.isEmpty ? 'Foto' : midia.legenda),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(
            File(midia.destino),
            errorBuilder: (_, _, _) =>
                const Text('Não foi possível abrir a foto.'),
          ),
        ),
      ),
    );
  }
}

class _VideoTelaCheia extends StatefulWidget {
  final MidiaExercicio midia;

  const _VideoTelaCheia({required this.midia});

  @override
  State<_VideoTelaCheia> createState() => _VideoTelaCheiaState();
}

class _VideoTelaCheiaState extends State<_VideoTelaCheia> {
  VideoPlayerController? _controller;
  Object? _erro;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    try {
      final controller = VideoPlayerController.file(File(widget.midia.destino));
      _controller = controller;
      await controller.initialize();
      if (!mounted) return;
      await controller.setLooping(true);
      await controller.play();
      if (mounted) setState(() {});
    } catch (erro) {
      if (mounted) setState(() => _erro = erro);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.midia.legenda.isEmpty ? 'Vídeo' : widget.midia.legenda,
        ),
      ),
      body: Center(
        child: _erro != null
            ? const Text('Não foi possível reproduzir o vídeo.')
            : controller == null || !controller.value.isInitialized
            ? const CircularProgressIndicator()
            : AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
      ),
      floatingActionButton: controller?.value.isInitialized == true
          ? FloatingActionButton(
              onPressed: () {
                final player = _controller;
                if (player == null) return;
                setState(() {
                  player.value.isPlaying ? player.pause() : player.play();
                });
              },
              child: Icon(
                controller?.value.isPlaying == true
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
            )
          : null,
    );
  }
}
