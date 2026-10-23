# Operação Premium e privacidade — WorkHoly

## Produto

- ID da assinatura: `workholy_premium_mensal`.
- Plano-base: mensal, renovação automática, preço inicial de R$ 9,90.
- Plano gratuito: perfil básico, treinos próprios, corrida, histórico e
  consistência semanal.
- Premium: biblioteca de exercícios, metas, avaliações e gráficos.

## Regra de licença

A licença pertence ao `uid` da conta WorkHoly. O aplicativo pode guardar uma
cópia para exibir o último estado offline, mas ela jamais é prova de acesso.
O backend é a fonte de verdade e atualiza `entitlements/{uid}` somente após
consultar a Google Play Developer API.

| Situação Play | Acesso Premium |
| --- | --- |
| Ativa | Sim, até `expiraEm` |
| Período de carência | Sim, até `expiraEm` |
| Cancelada | Sim até a expiração; sem nova renovação |
| Em espera, expirada ou revogada | Não |

## Checklist antes do lançamento

1. Criar projeto Firebase de produção separado do desenvolvimento.
2. Habilitar Authentication por e-mail/senha e exigir verificação de e-mail.
3. Criar Firestore em modo produção e publicar `backend/firestore.rules`.
4. Criar conta de serviço exclusiva do backend e atribuir o mínimo de
   permissões na Play Console para consulta de compras.
5. Ativar Google Play Developer API no projeto associado.
6. Criar assinatura e plano-base na Play Console; cadastrar testadores no
   canal fechado e em testes de licença.
7. Criar tópico Pub/Sub e apontá-lo como RTDN na Play Console.
8. Implantar funções; configurar alertas para falhas de RTDN e erros 5xx.
9. Testar: primeira compra, restauração, cancelamento, renovação, período de
   carência, pagamento recusado, reembolso e troca de dispositivo.
10. Só após esses cenários, publicar no canal de produção.

## Proteção de dados e LGPD

O app trata identificadores de conta e dados de evolução física. Adote
minimização: colete somente nome, e-mail e medições necessárias ao serviço.
Dados de pagamento não passam pelos servidores do WorkHoly: são processados
pela Google Play.

Antes de produção, publicar Política de Privacidade e Termos contendo:

- controlador e canal de contato do titular;
- finalidades, dados coletados, fornecedores e prazo de retenção;
- como solicitar acesso, correção, exportação e exclusão da conta;
- compartilhamento limitado com Firebase/Google Cloud e Google Play;
- procedimento de incidentes e atualização da política.

Implementar também uma função autenticada de exclusão de conta: apagar ou
anonimizar `users`, `health_data` e dados de perfil; preservar somente
registros fiscais/antifraude estritamente necessários pelo prazo legal, com
acesso administrativo auditado.

## Segredos e acesso administrativo

- Não enviar arquivos `.env`, JSON de conta de serviço ou chaves para Git.
- Guardar segredos no Secret Manager.
- Aplicar MFA às contas Firebase, Google Cloud e Play Console.
- Usar contas individuais, nunca uma senha compartilhada.
- Revisar permissões a cada trimestre.
- Registrar operações administrativas e validar backups/restauração.
