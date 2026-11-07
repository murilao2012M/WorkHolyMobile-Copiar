import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dados/backup_treino.dart';
import '../dados/backup_google_drive.dart';
import '../dados/workholy_textos.dart';

class BackupTreinoPage extends StatefulWidget {
  const BackupTreinoPage({super.key, required this.onBackupRestaurado});

  final Future<void> Function() onBackupRestaurado;

  @override
  State<BackupTreinoPage> createState() => _BackupTreinoPageState();
}

class _BackupTreinoPageState extends State<BackupTreinoPage> {
  bool _processando = false;

  Future<void> _salvarNoGoogleDrive() async {
    setState(() => _processando = true);
    try {
      final backup = await BackupTreino.exportar();
      final agora = DateTime.now();
      final data =
          '${agora.year.toString().padLeft(4, '0')}'
          '${agora.month.toString().padLeft(2, '0')}'
          '${agora.day.toString().padLeft(2, '0')}_'
          '${agora.hour.toString().padLeft(2, '0')}'
          '${agora.minute.toString().padLeft(2, '0')}'
          '${agora.second.toString().padLeft(2, '0')}';
      final salvo = await BackupGoogleDrive.salvar(
        backup,
        'moveria_backup_$data.json',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            salvo
                ? 'Backup salvo no local escolhido.'
                : 'Salvamento cancelado.',
          ),
        ),
      );
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar o backup: $erro')),
      );
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _exportar() async {
    setState(() => _processando = true);
    try {
      final backup = await BackupTreino.exportar();
      await Clipboard.setData(ClipboardData(text: backup));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Backup copiado. Cole o JSON em um arquivo ou local seguro.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível exportar o backup: $erro')),
      );
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _exportarCsv() async {
    setState(() => _processando = true);
    try {
      final csv = await BackupTreino.exportarCsv();
      await Clipboard.setData(ClipboardData(text: csv));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Histórico CSV copiado para a área de transferência.'),
        ),
      );
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível exportar o CSV: $erro')),
      );
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _restaurar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(WorkHolyTextos.confirmarRestauracao),
        content: const Text(
          'Os treinos, exercícios, associações e sessões atuais serão '
          'substituídos pelo conteúdo do backup copiado. Esta ação não pode '
          'ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(WorkHolyTextos.cancelar),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(WorkHolyTextos.restaurar),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _processando = true);
    try {
      final conteudo = await Clipboard.getData(Clipboard.kTextPlain);
      if (conteudo?.text == null || conteudo!.text!.trim().isEmpty) {
        throw const FormatException('A área de transferência está vazia.');
      }
      await BackupTreino.importar(conteudo.text!);
      await widget.onBackupRestaurado();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup restaurado com sucesso.')),
      );
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível restaurar o backup: $erro')),
      );
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup e exportação')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Proteja seu histórico',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'O backup inclui treinos, exercícios, sessões, anotações e '
            'corridas concluídas. Ao salvar, escolha Google Drive na janela '
            'de arquivos e selecione a pasta de destino. '
            'A restauração substitui esses dados no aparelho.',
          ),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: const Text('Salvar backup no Google Drive'),
                  subtitle: const Text(
                    'Escolha o Drive e a pasta na janela do Android',
                  ),
                  onTap: _processando ? null : _salvarNoGoogleDrive,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.copy_all_outlined),
                  title: const Text('Copiar backup JSON'),
                  subtitle: const Text(
                    'Copia o backup completo para a área de transferência',
                  ),
                  onTap: _processando ? null : _exportar,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.table_view_outlined),
                  title: const Text('Copiar histórico CSV'),
                  subtitle: const Text(
                    'Exporta sessões de musculação e corridas',
                  ),
                  onTap: _processando ? null : _exportarCsv,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore_outlined),
                  title: const Text('Restaurar da área de transferência'),
                  subtitle: const Text(
                    'Importa um backup do Moveria ou uma cópia legada',
                  ),
                  onTap: _processando ? null : _restaurar,
                ),
              ],
            ),
          ),
          if (_processando) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}
