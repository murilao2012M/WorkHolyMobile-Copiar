# Backend do WorkHoly

Este diretório contém a base para autenticação, licença Premium e sincronização
das compras do Google Play. Nenhuma credencial deve ser adicionada ao Git.

## Implantação futura

1. Criar um projeto Firebase e habilitar Authentication (e-mail/senha e Google).
2. Criar Firestore em modo produção.
3. Criar o projeto Google Cloud associado e habilitar a Google Play Developer API.
4. Criar uma conta de serviço dedicada ao backend; conceder a ela, na Play
   Console, apenas as permissões necessárias para consultar assinaturas.
5. Copiar `.env.example` para `.env` localmente e preencher os valores.
6. Publicar regras: `firebase deploy --only firestore:rules`.
7. Instalar as funções: `cd functions; npm ci; npm run build`.
8. Publicar as funções e configurar o tópico Pub/Sub de RTDN na Play Console.

O aplicativo nunca recebe chaves de conta de serviço e nunca define o campo
`premium` por conta própria.
