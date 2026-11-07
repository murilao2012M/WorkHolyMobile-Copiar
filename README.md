# Moveria

Aplicativo Flutter para organizar treinos de musculação e acompanhar corridas.

## Funcionalidades

- Cadastro de treinos e exercícios, com configurações por treino.
- Catálogo de 876 exercícios com nome em português e nome original entre
  parênteses, além de instruções em português.
- Execução e retomada de sessões, com registro de séries e anotações.
- Histórico de treinos e corridas, incluindo recordes de carga por exercício.
- Organização de treinos com busca, favoritos, filtros por divisão e agenda
  semanal, além de duplicação de treinos.
- Cartões com resumo de exercícios, duração aproximada e última realização.
- Editor com reordenação de exercícios, instruções individuais e notas gerais.
- Metas planejadas de carga e repetições, comparadas com o histórico de execução.
- Compartilhamento do resumo do treino pelo menu nativo do Android.
- Exercícios com peso corporal e preferência de carga em kg ou lb.
- Metas semanais de treino e lembretes semanais.
- Cadastro e acompanhamento de alunos, com treinos atribuídos, histórico,
  frequência e anotações privadas do treinador.
- Backup JSON e exportação CSV pelo menu de backup e exportação.

As instruções de 871 exercícios com texto na fonte foram traduzidas para
português e normalizadas com termos usuais de musculação. Cinco exercícios sem
instruções na fonte receberam orientações próprias. As traduções automáticas
continuam identificadas no catálogo para revisão técnica individual e não
substituem a orientação de um profissional de educação física; ajuste a carga
e interrompa o movimento se sentir dor.

## Dados e backup

O backup JSON inclui treinos, exercícios, associações, sessões e corridas
concluídas. Em Configurações > Backup e exportação, escolha salvar no Google
Drive e selecione o Drive e a pasta na janela do Android. O aplicativo não
acessa sua conta do Google diretamente; o seletor do Android e o provedor do
Drive cuidam do acesso. O Google Drive precisa estar disponível no aparelho e
com uma conta configurada. Também é possível copiar o JSON para a área de
transferência.

A restauração substitui esses dados do aplicativo, mas preserva corridas que
ainda estejam em andamento. Faça um backup antes de restaurar, pois a
substituição não pode ser desfeita.

O CSV exporta o histórico de sessões e corridas para consulta em planilhas; ele
não pode ser restaurado no aplicativo. A unidade escolhida para carga é apenas
uma preferência de exibição: os dados são armazenados em quilogramas.
Os cadastros e anotações de alunos também entram no backup JSON. O resumo de
um treino atribuído pode ser compartilhado pelo menu nativo do Android; as
anotações privadas do treinador não são incluídas nesse compartilhamento.

## Metas e lembretes

A meta semanal acompanha sessões de musculação concluídas. Os lembretes podem
ser configurados por dia e horário. No Android, o sistema pode atrasar
notificações agendadas devido a economia de bateria ou restrições do fabricante.
As permissões de notificação do sistema também precisam estar habilitadas.

## Desenvolvimento

Requisitos: Flutter SDK e dependências do projeto instaladas.

```powershell
flutter pub get
flutter analyze lib test
flutter test
flutter build apk --debug
```
