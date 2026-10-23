
import '../dados/workholy_banco.dart';

/// Fonte única de autorização do Premium.
///
/// No desenvolvimento, permite testar todas as funções sem compra.
/// Na versão comercial, o modo de desenvolvimento deve permanecer desativado.
class AssinaturaWorkHoly {
  AssinaturaWorkHoly._();

  static final instancia = AssinaturaWorkHoly._();

  static const _chavePremiumAtivo =
      'workholy_assinatura_premium_ativa_v1';

  static const bool _modoDesenvolvimentoPremium =
      bool.fromEnvironment(
    'WORKHOLY_DEV_PREMIUM',
    defaultValue: false,
  );

  Future<bool> possuiPremium() async {
    // Libera os recursos Premium somente quando a compilação
    // foi iniciada explicitamente com a opção de desenvolvimento.
    if (_modoDesenvolvimentoPremium) {
      return true;
    }

    // Com o modo de desenvolvimento desativado, mantém
    // o comportamento normal da assinatura.
    return await WorkHolyBanco.instancia
            .lerBooleano(_chavePremiumAtivo) ??
        false;
  }

  /// Reservado à integração futura com compras validadas.
  Future<void> atualizarAposCompraValidada(bool ativo) {
    return WorkHolyBanco.instancia.salvarBooleano(
      _chavePremiumAtivo,
      ativo,
    );
  }
}
