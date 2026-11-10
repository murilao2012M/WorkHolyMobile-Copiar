import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:workholy_mobile/sincronizacao/backup_nuvem_firestore.dart';
import 'package:workholy_mobile/sincronizacao/captura_dados_locais.dart';
import 'package:workholy_mobile/sincronizacao/controle_alteracoes_sqlite.dart';

void main() {
  test('recupera os dados exatos dos dois bancos em múltiplas partes', () {
    final aleatorio = Random(42);
    final texto = List.generate(
      800000,
      (_) => String.fromCharCode(33 + aleatorio.nextInt(90)),
    ).join();
    final snapshot = DadosLocaisCapturados(
      principal: SnapshotLocal(
        versao: 12,
        dados: {'texto': texto, 'nome': 'João'},
      ),
      corridas: const SnapshotLocal(
        versao: 7,
        dados: [
          {'id': 'corrida', 'rota_json': '[]'},
        ],
      ),
    );
    final codificado = CodecBackup.codificar(snapshot);
    expect(codificado.partes.length, greaterThan(1));
    expect(
      codificado.partes.every((p) => p.length <= CodecBackup.tamanhoParte),
      isTrue,
    );
    final recuperado = CodecBackup.decodificar(
      partes: codificado.partes,
      tamanho: codificado.tamanho,
      sha256Hex: codificado.sha256Hex,
    );
    expect(recuperado.principal, snapshot.principal.dados);
    expect(recuperado.corridas, snapshot.corridas.dados);
  });

  test('rejeita partes faltantes ou adulteradas', () {
    const snapshot = DadosLocaisCapturados(
      principal: SnapshotLocal(versao: 1, dados: {'treinos': []}),
      corridas: SnapshotLocal(versao: 1, dados: []),
    );
    final codificado = CodecBackup.codificar(snapshot);
    expect(
      () => CodecBackup.decodificar(
        partes: [],
        tamanho: codificado.tamanho,
        sha256Hex: codificado.sha256Hex,
      ),
      throwsFormatException,
    );
    final adulterada = Uint8List.fromList(codificado.partes.single);
    adulterada[adulterada.length - 1] ^= 1;
    expect(
      () => CodecBackup.decodificar(
        partes: [adulterada],
        tamanho: codificado.tamanho,
        sha256Hex: codificado.sha256Hex,
      ),
      throwsFormatException,
    );
  });
}
