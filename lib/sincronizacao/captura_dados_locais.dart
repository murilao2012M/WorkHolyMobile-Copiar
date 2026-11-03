import '../corrida/corrida_banco.dart';
import '../dados/workholy_banco.dart';
import 'controle_alteracoes_sqlite.dart';

class DadosLocaisCapturados {
  const DadosLocaisCapturados({
    required this.principal,
    required this.corridas,
  });

  final SnapshotLocal<Map<String, dynamic>> principal;
  final SnapshotLocal<List<Map<String, dynamic>>> corridas;
}

class DadosLocaisEmAlteracao implements Exception {
  const DadosLocaisEmAlteracao();
}

/// Obtém uma cópia consistente sem presumir que os dois bancos são atômicos.
///
/// O resultado não garante que os dados permaneçam inalterados depois da
/// captura: um futuro envio deve comparar as versões novamente ao confirmá-lo.
class CapturaDadosLocais {
  CapturaDadosLocais({
    required this.capturarPrincipal,
    required this.capturarCorridas,
    required this.lerVersaoPrincipal,
    required this.lerVersaoCorridas,
  });

  factory CapturaDadosLocais.dosBancos(
    WorkHolyBanco principal,
    CorridaBanco corridas,
  ) => CapturaDadosLocais(
    capturarPrincipal: principal.exportarDadosDoUsuarioComVersao,
    capturarCorridas: corridas.exportarDadosDoUsuarioComVersao,
    lerVersaoPrincipal: principal.versaoAlteracoes,
    lerVersaoCorridas: corridas.versaoAlteracoes,
  );

  final Future<SnapshotLocal<Map<String, dynamic>>> Function()
  capturarPrincipal;
  final Future<SnapshotLocal<List<Map<String, dynamic>>>> Function()
  capturarCorridas;
  final Future<int> Function() lerVersaoPrincipal;
  final Future<int> Function() lerVersaoCorridas;

  Future<DadosLocaisCapturados> capturar() async {
    for (var tentativa = 0; tentativa < 3; tentativa++) {
      final principal = await capturarPrincipal();
      final corridas = await capturarCorridas();
      final versaoPrincipal = await lerVersaoPrincipal();
      final versaoCorridas = await lerVersaoCorridas();
      if (principal.versao == versaoPrincipal &&
          corridas.versao == versaoCorridas) {
        return DadosLocaisCapturados(principal: principal, corridas: corridas);
      }
    }
    throw const DadosLocaisEmAlteracao();
  }
}
