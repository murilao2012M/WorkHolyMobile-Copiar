import 'package:flutter/material.dart';

import 'coordenador_backup.dart';
import '../edicao_app.dart';
import 'sincronizacao_usuario.dart';

class BackupAviso extends StatefulWidget {
  const BackupAviso({
    super.key,
    required this.restaurar,
    this.recursoDisponivel = SincronizacaoUsuario.habilitado,
  });

  final Future<void> Function(String versao, String? remota) restaurar;
  final bool recursoDisponivel;

  @override
  State<BackupAviso> createState() => _BackupAvisoState();
}

class _BackupAvisoState extends State<BackupAviso> {
  final _servico = SincronizacaoUsuario.instancia;

  Future<void> _ativar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Ativar backup na nuvem?'),
        content: Text(
          EdicaoApp.personal
              ? 'Os dados dos alunos, treinos, sessões e avaliações serão '
                    'enviados ao Firebase vinculado à sua conta. Fotos e '
                    'vídeos ficam apenas neste aparelho e não fazem parte do '
                    'backup. As versões anteriores serão preservadas. O '
                    'backup depende de conexão com a internet.'
              : 'O perfil, os treinos e as corridas, incluindo rotas, serão '
                    'enviados ao Firebase vinculado à sua conta. As versões '
                    'anteriores serão preservadas. O backup depende de '
                    'conexão com a internet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Ativar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    await _tentar(_servico.ativar);
  }

  Future<void> _tentar(Future<void> Function() operacao) async {
    try {
      await operacao();
    } on ConflitoBackup {
      // O aviso de conflito oferece a escolha explícita.
    } on BackupLegadoEncontrado {
      // O aviso permanente informa que os dados antigos ainda não foram migrados.
    } catch (erro, stackTrace) {
      debugPrint('Operação de backup não concluída: $erro');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível concluir o backup. Verifique a conexão e tente novamente.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _resolver(EstadoBackup estado) async {
    final escolha = await showDialog<String>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Dados diferentes entre aparelhos'),
        content: const Text(
          'Há uma versão na nuvem diferente da reconhecida neste aparelho. '
          'Escolha qual versão usar. Antes de restaurar, uma cópia dos dados '
          'deste aparelho será preservada na nuvem.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(contexto, 'local'),
            child: const Text('Usar este aparelho'),
          ),
          if (estado.versaoRemota != null)
            FilledButton(
              onPressed: () => Navigator.pop(contexto, 'nuvem'),
              child: const Text('Usar a nuvem'),
            ),
        ],
      ),
    );
    if (!mounted || escolha == null) return;
    if (escolha == 'local') {
      await _tentar(() => _servico.escolherDadosLocais(estado.versaoRemota));
    } else {
      await _confirmarRestauracao(estado.versaoRemota!, estado.versaoRemota);
    }
  }

  Future<void> _listarBackups() async {
    try {
      final remota = await _servico.versaoAtual();
      final versoes = await _servico.listarVersoes();
      if (!mounted) return;
      final escolhida = await showDialog<String>(
        context: context,
        builder: (contexto) => AlertDialog(
          title: const Text('Versões na nuvem'),
          content: SizedBox(
            width: double.maxFinite,
            child: versoes.isEmpty
                ? const Text('Nenhum backup disponível.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: versoes.length,
                    itemBuilder: (contexto, indice) {
                      final versao = versoes[indice];
                      final data = versao.criadaEm.toLocal();
                      final descricao =
                          '${data.day.toString().padLeft(2, '0')}/'
                          '${data.month.toString().padLeft(2, '0')}/${data.year} '
                          '${data.hour.toString().padLeft(2, '0')}:'
                          '${data.minute.toString().padLeft(2, '0')}';
                      return ListTile(
                        title: Text(descricao),
                        subtitle: Text(
                          versao.id == remota
                              ? 'Versão atual'
                              : 'Versão preservada',
                        ),
                        onTap: () => Navigator.pop(contexto, versao.id),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contexto),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
      if (escolhida != null && mounted) {
        await _confirmarRestauracao(escolhida, remota);
      }
    } catch (erro, stackTrace) {
      debugPrint('Não foi possível listar backups: $erro');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível carregar os backups. Verifique a conexão.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmarRestauracao(String versao, String? remota) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Restaurar esta versão?'),
        content: const Text(
          'Os dados deste aparelho serão substituídos após uma cópia deles '
          'ser preservada na nuvem. Finalize qualquer corrida aberta antes '
          'de continuar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmar == true && mounted) {
      await widget.restaurar(versao, remota);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.recursoDisponivel) {
      final cores = Theme.of(context).colorScheme;
      return Container(
        width: double.infinity,
        color: cores.errorContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(
          'Backup na nuvem em preparação. As alterações ficam somente neste '
          'aparelho; não desinstale o aplicativo.',
          style: TextStyle(color: cores.onErrorContainer),
        ),
      );
    }
    return ValueListenableBuilder<EstadoBackup>(
      valueListenable: _servico.estado,
      builder: (context, estado, _) {
        final mensagem = switch (estado.situacao) {
          SituacaoBackup.desativado =>
            'Backup desativado. Seus dados ficam somente neste aparelho.',
          SituacaoBackup.pendente => 'Alterações aguardam backup na nuvem.',
          SituacaoBackup.enviando => 'Operação de backup em andamento.',
          SituacaoBackup.concluido => 'Último backup concluído. Alterações posteriores podem estar pendentes.',
          SituacaoBackup.conflito =>
            'Há um conflito entre os dados deste aparelho e da nuvem.',
          SituacaoBackup.legado =>
            'Backup antigo encontrado. A migração ainda não está disponível; '
                'seus dados permanecem no aparelho e na cópia antiga.',
          SituacaoBackup.falhou =>
            'O backup não foi concluído. Seus dados permanecem neste aparelho.',
        };
        final cores = Theme.of(context).colorScheme;
        return Container(
          width: double.infinity,
          color: estado.situacao == SituacaoBackup.concluido
              ? cores.secondaryContainer
              : cores.errorContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mensagem),
              Wrap(
                spacing: 8,
                children: [
                  if (estado.situacao == SituacaoBackup.desativado)
                    TextButton(
                      onPressed: _ativar,
                      child: const Text('Ativar backup'),
                    )
                  else ...[
                    if (estado.situacao == SituacaoBackup.conflito)
                      TextButton(
                        onPressed: () => _resolver(estado),
                        child: const Text('Resolver conflito'),
                      )
                    else
                      TextButton(
                        onPressed:
                            estado.situacao == SituacaoBackup.enviando ||
                                estado.situacao == SituacaoBackup.legado
                            ? null
                            : () => _tentar(_servico.sincronizarAgora),
                        child: const Text('Enviar agora'),
                      ),
                    TextButton(
                      onPressed:
                          estado.situacao == SituacaoBackup.enviando ||
                              estado.situacao == SituacaoBackup.legado
                          ? null
                          : _listarBackups,
                      child: const Text('Restaurar backup'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
