import 'package:firebase_auth/firebase_auth.dart';

import '../dados/workholy_banco.dart';

/// Fonte única de autorização dos recursos Premium.
///
/// Nesta fase de lançamento, todos os usuários possuem acesso completo.
/// A estrutura de assinaturas permanece preparada para monetização futura.
class AssinaturaWorkHoly {
  AssinaturaWorkHoly._();

  static final instancia = AssinaturaWorkHoly._();

  static const _chavePremiumAtivo = 'workholy_assinatura_premium_ativa_v1';

  /// Mantém disponível a identificação da conta autenticada.
  String? get emailUsuario =>
      FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase();

  /// Acesso gratuito e completo para todos os usuários nesta versão.
  Future<bool> possuiPremium() async {
    return true;
  }

  /// Reservado à integração futura com compras validadas.
  Future<void> atualizarAposCompraValidada(bool ativo) {
    return WorkHolyBanco.instancia.salvarBooleano(_chavePremiumAtivo, ativo);
  }
}
