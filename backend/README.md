# Backend do Moveria

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

## Backup versionado

As regras deste diretório precisam ser publicadas no projeto Firebase correto
antes de testar o backup no aplicativo. A partir da raiz do repositório, após
conferir o projeto selecionado, use
`firebase deploy --config backend/firebase.json --only firestore:rules`.
Essa implantação altera regras remotas e não é feita automaticamente.

As cópias são divididas em documentos imutáveis em `workholy_backups/{uid}`,
com verificação de integridade e comparação transacional da versão ativa.
Versões e partes incompletas não são apagadas automaticamente; monitore custos
e armazenamento. A migração do formato antigo e a liberação segura da troca de
conta ainda não estão implementadas. O aplicativo mantém o recurso desativado
por padrão; a flag experimental descrita no README principal é apenas para
testes. Teste o fluxo completo em aparelhos reais antes de habilitá-lo para
usuários.

O codec experimental rejeita dados acima de 256 MiB descompactados ou 100 MiB
compactados, sem truncá-los. A restauração só é executada quando os dois bancos
locais permitem uma transação atômica entre arquivos; por exemplo, ela recusa
bancos em modo WAL. O envio automático depende de o aplicativo estar aberto.

O teste `integration_test/backup_android_test.dart` usa exclusivamente os
emuladores Auth e Firestore, no projeto fictício `demo-workholy`; ele precisa de
um emulador Android conectado e ainda não foi validado neste ambiente.
