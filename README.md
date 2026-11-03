# workholy_mobile

A new Flutter project.

## Biblioteca de exercícios

Na biblioteca Premium, use **Adicionar todos** para incluir o catálogo inteiro
no acervo, mesmo quando houver filtros ativos. Exercícios já vinculados ao
catálogo não são adicionados novamente. Cadastros antigos sem vínculo são
mantidos e podem ter nomes iguais aos exercícios importados. A gravação é feita
em uma transação local; em caso de falha, o lote é revertido.

Use o filtro **Equipamento** para combinar, por exemplo, halteres, kettlebell
ou peso corporal com o grupo muscular e a busca. O filtro utiliza o equipamento
principal informado no catálogo; outros equipamentos mencionados nas instruções
podem ser necessários. **Adicionar todos** continua incluindo todo o catálogo,
independentemente dos filtros.

## Demonstrações durante o treino

Na execução, exercícios vinculados ao catálogo mostram imagens locais e
instruções quando disponíveis. Deslize para ver as imagens do movimento.
Em exercícios antigos ou personalizados sem vínculo, use **Escolher
demonstração** e confirme que se trata do mesmo movimento; a escolha é salva
para a sessão atual, inclusive ao retomá-la. Algumas entradas não possuem
imagens ou instruções no catálogo, e a tela informa essa ausência. As imagens
não substituem orientação de um profissional de educação física.

## Backup na nuvem

O backup versionado está **desativado por padrão** enquanto a restauração é
validada em Android e a migração de backups antigos não estiver pronta. Dados
novos continuam somente no aparelho; não desinstale o aplicativo.

Para testes controlados, a compilação com
`--dart-define=WORKHOLY_BACKUP_EXPERIMENTAL=true` apresenta a opção de ativação
após a publicação das regras de `backend/firestore.rules` no Firebase de teste.
O protótipo envia perfil, treinos e corridas (incluindo rotas), tenta novamente
enquanto o aplicativo estiver aberto e preserva as versões anteriores. A
restauração solicita confirmação e conserva antes uma cópia local na nuvem.
Backups do formato antigo são detectados, mas sua migração ainda não está
disponível; nesse caso, o envio novo fica bloqueado e a cópia antiga não é
apagada. A troca para outra conta neste aparelho continua bloqueada. Não use
esse modo experimental como proteção única dos dados.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
