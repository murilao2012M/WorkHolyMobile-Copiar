import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum TipoMidia { foto, video, link }

/// Foto, vídeo ou link anexado a um exercício pelo personal.
class MidiaExercicio {
  final String id;
  final TipoMidia tipo;

  /// Caminho do arquivo no aparelho (foto/vídeo) ou URL (link).
  final String destino;
  final String legenda;

  MidiaExercicio({
    String? id,
    required this.tipo,
    required this.destino,
    this.legenda = '',
  }) : id = id ?? 'midia_${DateTime.now().microsecondsSinceEpoch}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'tipo': tipo.name,
    'destino': destino,
    if (legenda.isNotEmpty) 'legenda': legenda,
  };

  /// Retorna nulo para registros inválidos, que são ignorados na leitura.
  static MidiaExercicio? fromJson(Object? bruto) {
    if (bruto is! Map) return null;
    final destino = bruto['destino']?.toString() ?? '';
    final tipo = TipoMidia.values
        .where((t) => t.name == bruto['tipo'])
        .firstOrNull;
    if (tipo == null || destino.isEmpty) return null;
    return MidiaExercicio(
      id: bruto['id'] is String ? bruto['id'] as String : null,
      tipo: tipo,
      destino: destino,
      legenda: bruto['legenda']?.toString() ?? '',
    );
  }
}

/// Aceita apenas links http(s). Adiciona https:// quando o usuário omite.
Uri? validarLinkMidia(String texto) {
  var t = texto.trim();
  if (t.isEmpty || t.contains(RegExp(r'\s'))) return null;
  if (!t.contains('://')) t = 'https://$t';
  final uri = Uri.tryParse(t);
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      !uri.host.contains('.')) {
    return null;
  }
  return uri;
}

/// Guarda os arquivos escolhidos numa pasta própria do app, para que
/// continuem disponíveis mesmo que o original saia da galeria.
class ArmazenamentoMidia {
  ArmazenamentoMidia._();

  static Future<Directory> _pasta() async {
    final base = await getApplicationDocumentsDirectory();
    final pasta = Directory(p.join(base.path, 'midias_exercicios'));
    if (!await pasta.exists()) await pasta.create(recursive: true);
    return pasta;
  }

  static Future<String> copiar(String origem, {required String prefixo}) async {
    final pasta = await _pasta();
    final extensao = p.extension(origem);
    final destino = p.join(
      pasta.path,
      '${prefixo}_${DateTime.now().microsecondsSinceEpoch}$extensao',
    );
    await File(origem).copy(destino);
    return destino;
  }

  /// Remove o arquivo apenas se estiver na pasta do app.
  static Future<void> apagar(MidiaExercicio midia) async {
    if (midia.tipo == TipoMidia.link) return;
    try {
      final pasta = await _pasta();
      if (!p.isWithin(pasta.path, midia.destino)) return;
      final arquivo = File(midia.destino);
      if (await arquivo.exists()) await arquivo.delete();
    } on FileSystemException {
      // Arquivo já removido ou inacessível: nada a fazer.
    }
  }
}
