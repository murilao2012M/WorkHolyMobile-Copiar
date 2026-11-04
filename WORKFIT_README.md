# 🎯 WorkFit Personal - Sugestões de treino

## Visão geral

WorkFit usa regras locais e exercícios do catálogo para sugerir treinos. Não é um modelo de linguagem e não envia as respostas a serviços de IA. As sugestões não substituem a avaliação de um profissional de educação física.

O motor filtra por nível informado, categoria e equipamentos selecionados. Também procura nas instruções e no nome sinais de equipamentos adicionais ou necessidade de parceiro e utiliza sinais de execução controlada para ordenar os candidatos. Para iniciantes, exercícios sem nível identificado são excluídos. O catálogo pode conter traduções e metadados incorretos, e uma busca por termos nas instruções não equivale a compreendê-las integralmente; revise sempre os exercícios sugeridos.

O perfil não pergunta sobre lesões, limitações, doenças ou histórico clínico. Em caso de dúvida ou condição de saúde, procure avaliação profissional antes de treinar. A carga inicial não é determinada pelo aplicativo.

Para gerar outro plano, acesse **Meus treinos → Criar plano com WorkFit**. Os planos existentes são mantidos.

### Ciclo, aderência e ajustes

Planos novos incluem um ciclo de quatro semanas: base na primeira semana,
progressão nas semanas 2 e 3 e revisão na semana 4. Após o encerramento,
o aplicativo sugere revisão e recuperação; para iniciar outro ciclo, crie
um novo plano. Treinos criados antes desta função continuam disponíveis,
mas não recebem uma frequência ou ciclo retroativos.

A aderência compara a meta informada com os dias distintos de atividade
concluída em cada semana de sete dias a partir do início do ciclo. Para
treinos, conta uma sessão finalizada com pelo menos uma série concluída;
para corridas, conta apenas a corrida explicitamente vinculada ao ciclo ao
iniciá-la. Apenas uma semana completa é usada para o aviso de menos de 80%.

Na finalização de treinos WorkFit, RPE e RIR da sessão são opcionais. Para
corridas, registre o RPE no histórico pelo botão **Registrar esforço da
corrida**. RIR não é solicitado para corrida. No detalhe do treino,
**Sugerir ajustes** usa as séries e o esforço registrados: pode
propor repetições, uma carga maior após duas sessões consistentes, ou
redução de uma série para recuperação. A sugestão de carga arredonda para
0,5 kg e deve ser conferida com os equipamentos disponíveis. Para planos
novos, a progressão exige RPE ou RIR registrados; cargas não são
determinadas para exercícios sem carga informada.

Ao configurar um exercício no treino, **Sugerir progressão** controla as
sugestões de carga e repetições daquele exercício. Nos exercícios adicionados
manualmente, a opção começa desativada; itens antigos mantêm o comportamento
anterior. Sugestões de recuperação continuam disponíveis mesmo com a
progressão desativada.

No cadastro geral, informe apenas nome e grupo muscular; séries, repetições,
carga e descanso são definidos ao adicionar o exercício ao treino. Os valores
anteriores permanecem guardados para compatibilidade.

Todos os ajustes exigem confirmação e alteram apenas o treino futuro, não
o histórico. A redução de séries permanece até ser editada novamente;
o aplicativo não restaura o volume automaticamente. Essas regras são
heurísticas, não avaliam técnica e não garantem resultados.

O backup continua pausado: alterações novas ficam apenas neste aparelho e
não podem ser restauradas em outro enquanto a sincronização segura não
estiver pronta.

### 📦 Arquivos Entregues

| Arquivo | Descrição | Status |
|---------|-----------|--------|
| [lib/workfit/workfit_perfil.dart](/lib/workfit/workfit_perfil.dart) | Modelos de dados (WorkFitPerfil, WorkFitSugestao, WorkFitItemExercicio) | ✅ Completo |
| [lib/workfit/workfit_motor.dart](/lib/workfit/workfit_motor.dart) | Motor de geração inteligente (4 tipos de treino) | ✅ Completo |
| [lib/workfit/workfit_onboarding_page.dart](/lib/workfit/workfit_onboarding_page.dart) | Questionário e confirmação do plano | ✅ |
| [lib/workfit/workfit_adapter.dart](/lib/workfit/workfit_adapter.dart) | Converter WorkFit → app models (WorkHolyHome) | ✅ Completo |
| [test/workfit/workfit_motor_test.dart](/test/workfit/workfit_motor_test.dart) | Testes unitários | ✅ 7/7 Passando |
| [WORKFIT_IMPLEMENTATION.md](/WORKFIT_IMPLEMENTATION.md) | Documentação técnica | ✅ Completo |
| [WORKFIT_INTEGRATION_GUIDE.md](/WORKFIT_INTEGRATION_GUIDE.md) | Guia passo-a-passo para integração | ✅ Completo |

## 🧠 Inteligência do Motor

O **WorkFitMotor** gera treinos coerentes e inteligentes baseado em:

### 1. Musculação
- Sugere exercícios por grupo muscular e adapta a quantidade ao tempo informado.
- Considera os equipamentos selecionados independentemente do local de treino.
- Não presume cargas: ajuste-as com orientação profissional.

### 2. CrossFit
- Seleciona movimentos compatíveis com experiência e equipamentos; o resultado é uma sugestão, não um WOD certificado.

### 3. Corrida de Rua
- Sugere corrida ou caminhada ao ar livre por até o tempo informado. O exercício do catálogo é de trilha; registre a atividade na aba Corrida.

### 4. Personal Trainer
- Estrutura básica para orientação personalizada

## 🎮 Fluxo da UI

### Etapas do questionário

**Etapa 1**: O que você gosta de treinar?
- ⚪ Musculação
- ⚪ CrossFit
- ⚪ Corrida de Rua
- ⚪ Personal Trainer

**Etapa 2**: Quantos minutos você treina por dia?
- ◻️ 10, 15, 20, 30, 45 ou 60 minutos

**Etapa 3**: Quantas vezes por semana?
- ◻️ De 1 a 7 dias por semana

**Etapa 4**: Qual é o seu objetivo?
- ⚪ Emagrecimento
- ⚪ Hipertrofia
- ⚪ Força
- ⚪ Resistência muscular
- ⚪ Condicionamento geral
- ⚪ Sou atleta amador
- ⚪ Sou apenas amante do esporte

**Etapa 5**: Onde você treina?
- ⚪ Treino na Academia
- ⚪ Treino em casa com alguns aparelhos
- ⚪ Corro na rua
- ⚪ Treino em condomínio
- ⚪ Treino com Personal na Academia
- ⚪ Treino em Estúdio de CrossFit

**Etapa 6**: Nível de experiência (iniciante, intermediário ou avançado).

**Etapa 7**: Equipamentos efetivamente disponíveis. Sem marcação são considerados apenas exercícios identificados como peso corporal, desde que as instruções não indiquem equipamentos adicionais.

**Etapa 8**: Confirmação
- Mostra os treinos encontrados, ou uma mensagem para ajustar as opções quando não há exercícios compatíveis.
- "Confirmar e Começar" → Salva treinos no app
- "Criar Treino Manualmente" → Pula o WorkFit

## 🧪 Testes

```bash
flutter test test/workfit/workfit_motor_test.dart
```

**Resultado: ✅ 7/7 Testes Passando**

```
00:00 +0: loading workfit_motor_test.dart
00:00 +1: WorkFitMotor - Geração de Treinos Gera sugestões para musculação hipertrofia 4x/semana
00:00 +2: WorkFitMotor - Geração de Treinos Adapta para treino em casa sem academia
00:00 +3: WorkFitMotor - Geração de Treinos Gera sugestões para CrossFit
00:00 +4: WorkFitMotor - Geração de Treinos Gera sugestões para corrida de rua
00:00 +5: WorkFitMotor - Geração de Treinos Nomes de treinos são descritivos, não genéricos
00:00 +6: WorkFitMotor - Geração de Treinos Exercícios têm séries e repetições coerentes
00:00 +7: WorkFitPerfil - Serialização Serializa e desserializa JSON corretamente
00:00 +8: All tests passed!
```

## 🔧 Integração com main.dart

Veja [WORKFIT_INTEGRATION_GUIDE.md](/WORKFIT_INTEGRATION_GUIDE.md) para instruções passo-a-passo.

**Resumo**:
1. Importar WorkFit classes
2. Adicionar flag de primeiro acesso no banco
3. Mostrar `WorkFitOnboardingPage` na primeira execução
4. Usar `WorkFitAdapter.converterSugestoesParaTreinos()` para converter output
5. Salvar treinos gerados no banco local

## 🛡️ Segurança (Já Implementado)

- ✅ R8 Minification + ProGuard (remove logs, ofusca código)
- ✅ Dart Obfuscation (`--obfuscate`, `--split-debug-info`)
- ✅ Bloqueio de backup (`allowBackup=false`, `dataExtractionRules`)
- ✅ Password Policy forte (≥10 chars, maiúsc, minúsc, números)
- ✅ Bypass dev com `--dart-define=WORKHOLY_DEV_PREMIUM=true`
- ✅ Build scripts separados: dev e produção

## 📚 Catálogo de Exercícios

- **876 exercícios** (Free Exercise DB)
- Todas as traduzido para português
- Equipamentos normalizados (academia, casa, rua, etc.)
- Testes validam carregamento completo

## 🚀 Próximos Passos

### Curto Prazo (Essencial)
1. Integrar com main.dart (ver WORKFIT_INTEGRATION_GUIDE.md)
2. Testar fluxo: criar conta → onboarding → treinos gerados → executar
3. Validar persistência no banco SQLite

### Médio Prazo (Recomendado)
4. Melhorar motor com ML baseado em histórico (performance do usuário)
5. Adicionar histórico de treinos completados
6. Sugestões adaptativas baseadas em progresso

### Longo Prazo (Opcional)
7. Integração com LLM real (Claude API, GPT) para geração mais inteligente
8. Sistema de compartilhamento de treinos com amigos
9. Análise de performance: gráficos, estatísticas, medalhas

## 📊 Características Principais

| Característica | Implementado? | Detalhes |
|---|---|---|
| Coleta de preferências | ✅ Yes | 5 dimensões (tipo, tempo, frequência, objetivo, equipamento) |
| Geração inteligente | ✅ Yes | Heurística pura, descritiva, não genérica |
| UI multi-etapa | ✅ Yes | 6 etapas, progresso visual, validação, skip |
| Nomes descritivos | ✅ Yes | "Peito Explosivos", não "Treino A" |
| Adaptação equipamento | ✅ Yes | Academia vs casa detecta automaticamente |
| Persistência | ✅ Ready | Usa SQLite (vem com app) |
| Testes | ✅ Yes | 7/7 passando |
| Documentação | ✅ Yes | 2 guias + código comentado |

## 📝 Dependências Adicionadas

```yaml
dev_dependencies:
  test: ^1.24.0  # Para testes unitários
```

Todas as outras dependências (Flutter, Dart, etc.) já estão presentes.

## 🎓 Aprendizados & Design

### Por Que Heurística e Não ML?

1. **Performance**: Geração instantânea no device
2. **Privacidade**: Sem chamadas a backend
3. **Simplicidade**: Fácil de debugar e manter
4. **Flexibilidade**: Fácil de substituir por LLM futuro

### Por Que Esses 4 Tipos de Treino?

Cobertura dos principais modelos fitness:
- **Musculação**: Força e hipertrofia (maior público)
- **CrossFit**: Funcional e HIIT (modalidade em crescimento)
- **Corrida**: Cardio puro (saúde cardiovascular)
- **Personal**: Orientação profissional (premium, futuro)

### Por Que 6 Etapas Separadas (Não Tudo de Uma Vez)?

- **UX**: Menos intimidante
- **Validação**: Cada etapa gera feedback
- **Engajamento**: Sensação de progresso
- **Escalabilidade**: Fácil adicionar mais perguntas

## 🎙️ Voz, lembretes e passos

- **Voz do treinador** (`lib/voz`): fala séries, descansos e, na corrida, quilômetros e trocas de bloco. Só com o app aberto; precisa de voz pt-BR no aparelho.
- **Comandos de voz** (opcional, botão de microfone): pausar, continuar, próximo, série concluída, repetir e finalizar no treino; só pausar/continuar na corrida. Depende do reconhecedor do Android, que pode exigir internet e falhar com barulho. Os botões de toque continuam sendo o caminho principal.
- **Lembretes** (`lib/lembretes`): notificação semanal nos dias e horário escolhidos, em Configurações > Lembretes e voz. Horário aproximado (o Android pode atrasar). A notificação não fala.
- **Passos** (`lib/passos`): cartão no painel, opt-in, usando o sensor do aparelho. Conta a partir da primeira leitura do dia.

## 📞 Suporte & Troubleshooting

### Testes falhando?
```bash
flutter pub get
flutter test test/workfit/workfit_motor_test.dart -v
```

### Motor gera nomes genéricos?
Revisar lógica em `workfit_motor.dart`. Cada tipo de treino tem nomes customizados por objetivo.

### Não salva no banco?
1. Verificar se `WorkFitAdapter.converterSugestoesParaTreinos()` foi chamado
2. Validar que `WorkHolyHome` e `ItemTreino` estão sendo persistidos
3. Checar se flag `primeiro_acesso` está sendo atualizada

---

**Desenvolvido com ❤️ para WorkHoly Mobile**
