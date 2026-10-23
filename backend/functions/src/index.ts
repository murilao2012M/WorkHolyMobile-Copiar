import * as admin from 'firebase-admin';
import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {onMessagePublished} from 'firebase-functions/v2/pubsub';
import {google} from 'googleapis';
import {createHash} from 'node:crypto';

admin.initializeApp();
const db = admin.firestore();

const packageName = process.env.WORKHOLY_ANDROID_PACKAGE ?? '';
const premiumProduct = process.env.WORKHOLY_PREMIUM_PRODUCT ?? '';

type EstadoLicenca = 'active' | 'grace_period' | 'canceled' | 'expired' | 'revoked';

function tokenHash(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

function androidPublisher() {
  const auth = new google.auth.GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  return google.androidpublisher({version: 'v3', auth});
}

function validarConfiguracao() {
  if (!packageName || !premiumProduct) {
    throw new HttpsError('failed-precondition', 'Backend de cobrança ainda não configurado.');
  }
}

function obterExpiracao(compra: {lineItems?: Array<{expiryTime?: string | null}>}): Date {
  const texto = compra.lineItems?.[0]?.expiryTime;
  const data = texto ? new Date(texto) : new Date(0);
  if (Number.isNaN(data.valueOf())) return new Date(0);
  return data;
}

function normalizarEstado(
  estadoPlay: string | null | undefined,
  expiraEm: Date,
): {estado: EstadoLicenca; premium: boolean} {
  const agora = Date.now();
  if (estadoPlay === 'SUBSCRIPTION_STATE_REVOKED') {
    return {estado: 'revoked', premium: false};
  }
  if (estadoPlay === 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD' && expiraEm.valueOf() > agora) {
    return {estado: 'grace_period', premium: true};
  }
  if (
    estadoPlay === 'SUBSCRIPTION_STATE_EXPIRED' ||
    estadoPlay === 'SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED' ||
    expiraEm.valueOf() <= agora
  ) {
    return {estado: 'expired', premium: false};
  }
  if (estadoPlay === 'SUBSCRIPTION_STATE_ON_HOLD') {
    return {estado: 'canceled', premium: false};
  }
  return {estado: 'active', premium: true};
}

/**
 * Fonte de verdade da licença. A associação token -> uid é imutável: uma
 * compra já vinculada a outra conta não pode ser reivindicada pelo cliente.
 */
async function sincronizarCompra(token: string, uidEsperado?: string) {
  validarConfiguracao();
  const hash = tokenHash(token);
  const compraRef = db.collection('purchases').doc(hash);
  const compraExistente = await compraRef.get();
  const uidExistente = compraExistente.data()?.uid as string | undefined;
  if (uidEsperado && uidExistente && uidEsperado !== uidExistente) {
    throw new HttpsError('permission-denied', 'Esta compra já está vinculada a outra conta.');
  }

  const play = androidPublisher();
  const resposta = await play.purchases.subscriptionsv2.get({
    packageName,
    token,
  });
  const compra = resposta.data;
  const produtos = compra.lineItems?.map((item) => item.productId).filter(Boolean) ?? [];
  if (!produtos.includes(premiumProduct)) {
    throw new HttpsError('invalid-argument', 'Produto de assinatura inválido.');
  }

  const uid = uidExistente ?? uidEsperado;
  if (!uid) return; // RTDN de compra ainda não vinculada ao usuário do app.

  const expiraEm = obterExpiracao(compra);
  const resultado = normalizarEstado(compra.subscriptionState, expiraEm);
  const agora = admin.firestore.FieldValue.serverTimestamp();
  await db.runTransaction(async (transacao) => {
    transacao.set(compraRef, {
      uid,
      produto: premiumProduct,
      estadoPlay: compra.subscriptionState ?? 'UNKNOWN',
      expiraEm: admin.firestore.Timestamp.fromDate(expiraEm),
      ordemGooglePlay: compra.latestOrderId ?? null,
      tokenAnterior: compra.linkedPurchaseToken
        ? tokenHash(compra.linkedPurchaseToken)
        : null,
      atualizadoEm: agora,
      criadoEm: compraExistente.exists ? compraExistente.data()?.criadoEm ?? agora : agora,
    }, {merge: true});
    transacao.set(db.collection('entitlements').doc(uid), {
      premium: resultado.premium,
      status: resultado.estado,
      produto: premiumProduct,
      expiraEm: admin.firestore.Timestamp.fromDate(expiraEm),
      atualizadoEm: agora,
    }, {merge: true});
  });

  // A confirmação é idempotente. O erro é registrado pelo provedor, mas não
  // invalida uma licença já verificada.
  const produto = produtos[0];
  try {
    await play.purchases.subscriptions.acknowledge({
      packageName,
      subscriptionId: produto!,
      token,
      requestBody: {},
    });
  } catch (erro) {
    console.warn('Não foi possível confirmar a assinatura no Play', erro);
  }
}

/** O app chama após o fluxo de compra ou em “Restaurar compras”. */
export const verificarAssinatura = onCall(async (requisicao) => {
  if (!requisicao.auth) {
    throw new HttpsError('unauthenticated', 'Faça login para verificar sua assinatura.');
  }
  const token = requisicao.data?.purchaseToken;
  if (typeof token !== 'string' || token.length < 20 || token.length > 4096) {
    throw new HttpsError('invalid-argument', 'Token de compra inválido.');
  }
  await sincronizarCompra(token, requisicao.auth.uid);
  const licenca = await db.collection('entitlements').doc(requisicao.auth.uid).get();
  return licenca.data() ?? {premium: false, status: 'expired'};
});

/**
 * Configurar o tópico informado em WORKHOLY_RTDN_TOPIC na Play Console.
 * A notificação não é uma prova de pagamento; ela sempre dispara nova
 * consulta à Google Play Developer API antes de qualquer liberação.
 */
export const processarRtdn = onMessagePublished(
  process.env.WORKHOLY_RTDN_TOPIC || 'workholy-play-rtdn',
Eu  async (evento) => {
    const id = evento.id;
    const eventoRef = db.collection('billing_events').doc(id);
    if ((await eventoRef.get()).exists) return;
    await eventoRef.create({recebidoEm: admin.firestore.FieldValue.serverTimestamp()});

    try {
      const bruto = Buffer.from(evento.data.message.data, 'base64').toString('utf8');
      const mensagem = JSON.parse(bruto) as {subscriptionNotification?: {purchaseToken?: string}};
      const token = mensagem.subscriptionNotification?.purchaseToken;
      if (!token) throw new Error('RTDN sem token de assinatura.');
      await sincronizarCompra(token);
      await eventoRef.set({processadoEm: admin.firestore.FieldValue.serverTimestamp()}, {merge: true});
    } catch (erro) {
      await eventoRef.set({erro: String(erro), falhouEm: admin.firestore.FieldValue.serverTimestamp()}, {merge: true});
      throw erro; // Pub/Sub tenta novamente conforme a política configurada.
    }
  },
);
