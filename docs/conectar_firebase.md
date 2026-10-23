# Conectar o WorkHoly ao Firebase

Projeto Firebase: `workholy-mobile`.

## No console Firebase

1. Em **Authentication > Sign-in method**, habilitar **E-mail/senha**. Não
   habilitar login anônimo para a versão comercial.
2. Em **Firestore Database**, criar o banco em modo de produção na região mais
   adequada à operação brasileira; não usar regras de teste.
3. Em **App Check**, registrar o app Android e usar Play Integrity quando o
   app estiver distribuído pela Play Store.
4. Em **Configurações do projeto > Seus apps**, adicionar o app Android com o
   pacote `br.com.workholyia.workholy_mobile`.
5. Baixar `google-services.json` e colocá-lo em
   `android/app/google-services.json`. Esse arquivo é configuração pública do
   app, mas não substitui as regras Firestore nem chaves de servidor.

## Neste computador

Instalar Node.js 20 LTS e, depois, executar no PowerShell:

```powershell
npm install -g firebase-tools
dart pub global activate flutterfire_cli
firebase login
Set-Location "C:\Users\TI\WorkHolyMobile"
flutterfire configure --project=workholy-mobile --platforms=android
```

O último comando gera `lib/firebase_options.dart`. Esse arquivo deve ser
versionado; ele não contém uma chave de servidor.

## Depois da conexão

1. Adicionar os SDKs Flutter de Firebase.
2. Inicializar Firebase no `main.dart` com `DefaultFirebaseOptions`.
3. Criar tela de cadastro/login e exigir confirmação de e-mail.
4. Publicar `backend/firestore.rules`.
5. Instalar e publicar `backend/functions` quando houver Node.js e conta
   Google Cloud configurada.

Não criar ainda a assinatura na Play Console nem colar credenciais de conta
de serviço no aplicativo. Isso entra somente quando a conta de desenvolvedor
Google Play estiver pronta.
