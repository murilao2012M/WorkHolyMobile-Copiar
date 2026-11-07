import 'dart:io';

import 'package:flutter/services.dart';

class BackupGoogleDrive {
  const BackupGoogleDrive._();

  static const MethodChannel _canal = MethodChannel(
    'br.com.workholyia.workholy_mobile/backup',
  );

  static Future<bool> salvar(String conteudo, String nomeArquivo) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'Salvar no Google Drive está disponível nesta versão para Android.',
      );
    }

    final salvo = await _canal.invokeMethod<bool>('salvarBackup', {
      'conteudo': conteudo,
      'nomeArquivo': nomeArquivo,
    });
    if (salvo == null) {
      throw StateError('O Android não confirmou o salvamento do backup.');
    }
    return salvo;
  }
}
