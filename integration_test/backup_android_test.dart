import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:workholy_mobile/corrida/corrida_banco.dart';
import 'package:workholy_mobile/dados/workholy_banco.dart';
import 'package:workholy_mobile/sincronizacao/backup_nuvem_firestore.dart';
import 'package:workholy_mobile/sincronizacao/captura_dados_locais.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Firestore e restauração dos dois bancos no Android', (
    tester,
  ) async {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'emulador',
        appId: '1:123456789:android:emulador',
        messagingSenderId: '123456789',
        projectId: 'demo-workholy',
      ),
    );
    final auth = FirebaseAuth.instance;
    await auth.useAuthEmulator('10.0.2.2', 9099);
    final firestore = FirebaseFirestore.instance;
    firestore.useFirestoreEmulator('10.0.2.2', 8080);
    final email =
        'backup-${DateTime.now().microsecondsSinceEpoch}@example.test';
    const senha = 'senha-de-teste';
    final credencial = await auth.createUserWithEmailAndPassword(
      email: email,
      password: senha,
    );
    final uid = credencial.user!.uid;
    final diretorio = await Directory.systemTemp.createTemp(
      'workholy_android_backup_',
    );
    final principal = WorkHolyBanco.paraTestes(
      caminho: p.join(diretorio.path, 'dados.db'),
    );
    final corridas = CorridaBanco.paraTestes(
      caminho: p.join(diretorio.path, 'corridas.db'),
    );
    try {
      await principal.salvarDadosTreino(
        treinos: [
          {'id': 'treino-nuvem', 'nome': 'Treino'},
        ],
        exercicios: [
          {'id': 'exercicio', 'nome': 'Exercício', 'grupo': 'Pernas'},
        ],
        itensTreino: [],
        sessoesTreino: [],
      );
      await corridas.criar('corrida-nuvem', 1234);
      await corridas.atualizar(
        id: 'corrida-nuvem',
        duracaoSegundos: 120,
        distanciaMetros: 500,
        estado: 'finalizada',
        rota: [
          {'lat': -23.5, 'lon': -46.6},
        ],
      );
      final captura = await CapturaDadosLocais.dosBancos(
        principal,
        corridas,
      ).capturar();
      final nuvem = BackupNuvemFirestore(firestore: firestore, uid: uid);
      expect(await nuvem.existeBackupLegado(), isFalse);
      final versao = await nuvem.guardarVersao(captura);
      expect(await nuvem.versaoAtual(), isNull);
      expect(await nuvem.publicarVersao(versao, versaoEsperada: null), isTrue);
      expect(await nuvem.versaoAtual(), versao);
      final copia = await nuvem.carregarVersao(versao);
      expect(copia.principal, captura.principal.dados);
      expect(copia.corridas, captura.corridas.dados);
      expect(
        await nuvem.publicarVersao('outra', versaoEsperada: null),
        isFalse,
      );

      await principal.salvarDadosTreino(
        treinos: [
          {'id': 'treino-local', 'nome': 'Alterado'},
        ],
        exercicios: [],
        itensTreino: [],
        sessoesTreino: [],
      );
      final antesPrincipal = await principal.versaoAlteracoes();
      final antesCorridas = await corridas.versaoAlteracoes();
      await principal.restaurarDadosComCorridas(
        dados: copia.principal,
        corridas: copia.corridas,
        caminhoBancoCorridas: (await corridas.database).path,
        versaoPrincipalEsperada: antesPrincipal,
        versaoCorridasEsperada: antesCorridas,
      );
      expect(
        (await principal.carregarDadosTreino()).treinos.single['id'],
        'treino-nuvem',
      );
      expect((await corridas.listar()).single['id'], 'corrida-nuvem');

      await auth.signOut();
      await auth.createUserWithEmailAndPassword(
        email: 'outro-${DateTime.now().microsecondsSinceEpoch}@example.test',
        password: senha,
      );
      await expectLater(
        nuvem.versaoAtual(),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    } finally {
      await (await principal.database).close();
      await corridas.fechar();
      await diretorio.delete(recursive: true);
      await auth.signOut();
    }
  });
}
