import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

import 'captura_dados_locais.dart';

class BackupCodificado {
  const BackupCodificado({
    required this.partes,
    required this.sha256Hex,
    required this.tamanho,
  });

  final List<Uint8List> partes;
  final String sha256Hex;
  final int tamanho;
}

/// Serializa os dois bancos em partes menores que o limite de documento.
class CodecBackup {
  static const tamanhoParte = 450 * 1024;
  static const limiteBytesComprimidos = 100 * 1024 * 1024;
  static const limiteBytesDescomprimidos = 256 * 1024 * 1024;

  static BackupCodificado codificar(DadosLocaisCapturados snapshot) {
    final json = jsonEncode({
      'formato': 1,
      'principal': snapshot.principal.dados,
      'corridas': snapshot.corridas.dados,
    });
    final original = utf8.encode(json);
    if (original.length > limiteBytesDescomprimidos) {
      throw StateError('Os dados excedem o tamanho suportado pelo backup.');
    }
    final compactado = gzip.encode(original);
    if (compactado.length > limiteBytesComprimidos) {
      throw StateError('O backup excede o tamanho suportado.');
    }
    final partes = <Uint8List>[];
    for (var inicio = 0; inicio < compactado.length; inicio += tamanhoParte) {
      final fim = (inicio + tamanhoParte).clamp(0, compactado.length);
      partes.add(Uint8List.fromList(compactado.sublist(inicio, fim)));
    }
    return BackupCodificado(
      partes: partes,
      sha256Hex: sha256.convert(compactado).toString(),
      tamanho: compactado.length,
    );
  }

  static ({Map<String, dynamic> principal, List<Map<String, dynamic>> corridas})
  decodificar({
    required List<Uint8List> partes,
    required int tamanho,
    required String sha256Hex,
  }) {
    if (partes.isEmpty ||
        tamanho <= 0 ||
        tamanho > limiteBytesComprimidos ||
        partes.any((parte) => parte.isEmpty || parte.length > tamanhoParte)) {
      throw const FormatException('Partes de backup inválidas.');
    }
    final tamanhoRecebido = partes.fold<int>(
      0,
      (total, parte) => total + parte.length,
    );
    if (tamanhoRecebido != tamanho) {
      throw const FormatException('O backup está incompleto.');
    }
    final bytes = BytesBuilder(copy: false);
    for (final parte in partes) {
      bytes.add(parte);
    }
    final compactado = bytes.takeBytes();
    if (sha256.convert(compactado).toString() != sha256Hex) {
      throw const FormatException(
        'A verificação de integridade do backup falhou.',
      );
    }
    final sink = _SaidaDescompactadaLimitada();
    final decodificador = gzip.decoder.startChunkedConversion(sink);
    decodificador.add(compactado);
    decodificador.close();
    final original = sink.bytes.takeBytes();
    final conteudo = jsonDecode(utf8.decode(original));
    if (conteudo is! Map ||
        conteudo['formato'] != 1 ||
        conteudo['principal'] is! Map ||
        conteudo['corridas'] is! List ||
        (conteudo['corridas'] as List).any((item) => item is! Map)) {
      throw const FormatException('Formato de backup inválido.');
    }
    return (
      principal: Map<String, dynamic>.from(conteudo['principal'] as Map),
      corridas: (conteudo['corridas'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
    );
  }
}

class _SaidaDescompactadaLimitada implements Sink<List<int>> {
  final BytesBuilder bytes = BytesBuilder(copy: false);
  int _tamanho = 0;

  @override
  void add(List<int> dados) {
    _tamanho += dados.length;
    if (_tamanho > CodecBackup.limiteBytesDescomprimidos) {
      throw const FormatException(
        'Backup descompactado excede o tamanho permitido.',
      );
    }
    bytes.add(dados);
  }

  @override
  void close() {}
}

abstract interface class RepositorioBackupNuvem {
  Future<String?> versaoAtual();
  Future<bool> existeBackupLegado();
  Future<String> guardarVersao(DadosLocaisCapturados snapshot);
  Future<
    ({Map<String, dynamic> principal, List<Map<String, dynamic>> corridas})
  >
  carregarVersao(String id);
  Future<bool> publicarVersao(String id, {required String? versaoEsperada});
}

/// Repositório isolado do formato legado; versões existentes nunca são apagadas.
class BackupNuvemFirestore implements RepositorioBackupNuvem {
  BackupNuvemFirestore({required this.firestore, required this.uid}) {
    if (uid.trim().isEmpty || uid.contains('/')) {
      throw ArgumentError.value(uid, 'uid');
    }
  }

  final FirebaseFirestore firestore;
  final String uid;
  static const _limiteRede = Duration(seconds: 25);

  DocumentReference<Map<String, dynamic>> get _conta =>
      firestore.collection('workholy_backups').doc(uid);

  CollectionReference<Map<String, dynamic>> get _versoes =>
      _conta.collection('versoes');

  @override
  Future<bool> existeBackupLegado() async {
    final contaLegada = firestore.collection('users').doc(uid);
    final principal = await contaLegada
        .collection('dados')
        .doc('principal')
        .get(const GetOptions(source: Source.server))
        .timeout(_limiteRede);
    if (principal.exists) return true;
    final corridas = await contaLegada
        .collection('corridas')
        .limit(1)
        .get(const GetOptions(source: Source.server))
        .timeout(_limiteRede);
    return corridas.docs.isNotEmpty;
  }

  Future<List<({String id, DateTime criadaEm})>> listarVersoes() async {
    final resultado = await _versoes
        .orderBy('criadoEm', descending: true)
        .get(const GetOptions(source: Source.server))
        .timeout(_limiteRede);
    return resultado.docs.map((documento) {
      final data = documento.data()['criadoEm'];
      if (data is! Timestamp) {
        throw const FormatException('Data de backup inválida.');
      }
      return (id: documento.id, criadaEm: data.toDate());
    }).toList();
  }

  @override
  Future<String?> versaoAtual() async {
    final doc = await _conta
        .get(const GetOptions(source: Source.server))
        .timeout(_limiteRede);
    if (!doc.exists) return null;
    final versao = doc.data()?['versao'];
    if (versao is! String || versao.isEmpty) {
      throw const FormatException('Identificador de backup remoto inválido.');
    }
    return versao;
  }

  @override
  Future<String> guardarVersao(DadosLocaisCapturados snapshot) async {
    final codificado = CodecBackup.codificar(snapshot);
    final versao = _versoes.doc();
    for (var i = 0; i < codificado.partes.length; i++) {
      await versao
          .collection('partes')
          .doc('$i')
          .set({'dados': Blob(codificado.partes[i])})
          .timeout(_limiteRede);
    }
    await versao
        .set({
          'formato': 1,
          'partes': codificado.partes.length,
          'tamanho': codificado.tamanho,
          'sha256': codificado.sha256Hex,
          'criadoEm': FieldValue.serverTimestamp(),
        })
        .timeout(_limiteRede);
    // Confere no servidor, não apenas no cache offline, antes de publicar.
    await carregarVersao(versao.id);
    return versao.id;
  }

  @override
  Future<
    ({Map<String, dynamic> principal, List<Map<String, dynamic>> corridas})
  >
  carregarVersao(String id) async {
    if (id.isEmpty || id.contains('/')) throw ArgumentError.value(id, 'id');
    final versao = _versoes.doc(id);
    final documento = await versao
        .get(const GetOptions(source: Source.server))
        .timeout(_limiteRede);
    final dados = documento.data();
    if (dados == null ||
        dados['formato'] != 1 ||
        dados['partes'] is! int ||
        dados['tamanho'] is! int ||
        dados['sha256'] is! String) {
      throw const FormatException('Metadados do backup inválidos.');
    }
    final quantidade = dados['partes'] as int;
    final tamanho = dados['tamanho'] as int;
    if (quantidade < 1 ||
        quantidade >
            (CodecBackup.limiteBytesComprimidos / CodecBackup.tamanhoParte)
                .ceil() ||
        tamanho <= 0 ||
        tamanho > CodecBackup.limiteBytesComprimidos ||
        quantidade != (tamanho / CodecBackup.tamanhoParte).ceil()) {
      throw const FormatException('Tamanho do backup inválido.');
    }
    final partes = <Uint8List>[];
    for (var i = 0; i < quantidade; i++) {
      final parte = await versao
          .collection('partes')
          .doc('$i')
          .get(const GetOptions(source: Source.server))
          .timeout(_limiteRede);
      final bytes = parte.data()?['dados'];
      if (bytes is! Blob) {
        throw const FormatException('Parte do backup não encontrada.');
      }
      partes.add(bytes.bytes);
    }
    return CodecBackup.decodificar(
      partes: partes,
      tamanho: tamanho,
      sha256Hex: dados['sha256'] as String,
    );
  }

  /// Publica apenas se nenhuma outra versão foi publicada desde a leitura.
  @override
  Future<bool> publicarVersao(
    String id, {
    required String? versaoEsperada,
  }) async {
    if (id.isEmpty || id.contains('/')) throw ArgumentError.value(id, 'id');
    return firestore
        .runTransaction((transacao) async {
          final atual = await transacao.get(_conta);
          final valor = atual.data()?['versao'];
          if (atual.exists && (valor is! String || valor.isEmpty)) {
            throw const FormatException(
              'Identificador de backup remoto inválido.',
            );
          }
          if (valor == id) return true;
          if (valor != versaoEsperada) return false;
          transacao.set(_conta, {
            'versao': id,
            'atualizadoEm': FieldValue.serverTimestamp(),
          });
          return true;
        })
        .timeout(_limiteRede);
  }
}
