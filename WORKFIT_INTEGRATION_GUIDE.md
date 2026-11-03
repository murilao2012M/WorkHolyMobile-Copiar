# WorkFit Personal - Guia de Integração ao main.dart

## Resumo Rápido

WorkFit Personal foi completamente implementado com 3 arquivos core:
- ✅ [workfit_perfil.dart](/lib/workfit/workfit_perfil.dart) - Modelos de dados
- ✅ [workfit_motor.dart](/lib/workfit/workfit_motor.dart) - Motor de geração inteligente
- ✅ [workfit_onboarding_page.dart](/lib/workfit/workfit_onboarding_page.dart) - UI de 6 etapas
- ✅ [workfit_motor_test.dart](/test/workfit/workfit_motor_test.dart) - **Testes passando 7/7**

## O Que Foi Implementado

### 1. Motor de IA (WorkFitMotor)
Gera treinos coherentes baseado em:
- **Tipo de treino**: Musculação, CrossFit, Corrida, Personal Trainer
- **Duração**: 10/30/60 minutos por dia
- **Frequência**: 2-7 dias por semana
- **Objetivo**: Emagrecimento, Hipertrofia, Atleta Amador, Amante do Esporte
- **Equipamento**: Academia, Casa, Rua, Condomínio, Personal, CrossFit Studio

**Inteligência**: Nomes descritivos ("Peito e Tríceps Explosivos", não "Treino A"), séries/reps adaptadas ao objetivo, exercícios coerentes com o equipamento disponível.

### 2. UI de Onboarding (6 Etapas)
1. Tipo de treino (radio buttons)
2. Minutos por dia (chips)
3. Dias por semana (chips)
4. Objetivo (radio buttons)
5. Equipamento (radio buttons)
6. Confirmação com sugestões geradas

Barra de progresso, validação, opção de "Pular" e "Confirmar e Começar".

### 3. Modelos de Dados
- **WorkFitPerfil**: Armazena preferências (JSON serializable)
- **WorkFitSugestao**: Sugestão de treino com exercícios
- **WorkFitItemExercicio**: Item de exercício dentro da sugestão

## Integração no main.dart

### Passo 1: Importar WorkFit

Adicione no topo de `lib/main.dart`:

```dart
import 'workfit/workfit_onboarding_page.dart';
import 'workfit/workfit_perfil.dart';
import 'dados/workholy_banco.dart';
```

### Passo 2: Flag de Primeiro Acesso

No seu banco de dados (`lib/dados/workholy_banco.dart`), adicione:

```dart
// Adicione uma flag para controlar se o onboarding foi feito
Future<bool> obterPrimeiroAcesso() async {
  final db = await obterDatabase();
  try {
    final result = await db.query('preferencias', where: 'chave = ?', whereArgs: ['primeiro_acesso']);
    if (result.isEmpty) return true;
    return result.first['valor'] == 'false';
  } catch (e) {
    return true;
  }
}

Future<void> definirPrimeiroAcesso(bool valor) async {
  final db = await obterDatabase();
  await db.insert(
    'preferencias',
    {'chave': 'primeiro_acesso', 'valor': valor.toString()},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

// Também salve o perfil do WorkFit:
Future<void> salvarWorkFitPerfil(WorkFitPerfil perfil) async {
  final db = await obterDatabase();
  try {
    await db.insert(
      'preferencias',
      {
        'chave': 'workfit_perfil',
        'valor': jsonEncode(perfil.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  } catch (e) {
    print('Erro ao salvar WorkFit Perfil: $e');
  }
}

Future<WorkFitPerfil?> obterWorkFitPerfil() async {
  final db = await obterDatabase();
  try {
    final result = await db.query('preferencias', where: 'chave = ?', whereArgs: ['workfit_perfil']);
    if (result.isEmpty) return null;
    return WorkFitPerfil.fromJson(jsonDecode(result.first['valor'] as String));
  } catch (e) {
    return null;
  }
}
```

### Passo 3: Mostrar Onboarding na Primeira Execução

No seu `build()` ou `initState()` do home widget, após login bem-sucedido:

```dart
@override
void initState() {
  super.initState();
  _verificarPrimeiroAcesso();
}

Future<void> _verificarPrimeiroAcesso() async {
  final primeiroAcesso = await banco.obterPrimeiroAcesso();
  
  if (primeiroAcesso && mounted) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: WorkFitOnboardingPage(
          onConfirm: (sugestoes) {
            _procesarSugestoesWorkFit(sugestoes);
            banco.definirPrimeiroAcesso(false);
            Navigator.pop(context);
          },
          onSkip: () {
            banco.definirPrimeiroAcesso(false);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

Future<void> _procesarSugestoesWorkFit(List<WorkFitSugestao> sugestoes) async {
  for (final sugestao in sugestoes) {
    // Converter WorkFitSugestao em WorkHolyHome (Treino)
    final novoTreino = WorkHolyHome(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      nomeTreino: sugestao.nomeTreino,
      descricao: sugestao.descricao,
      dataCriacao: DateTime.now(),
      itensTreino: sugestao.exercicios.map((item) {
        return ItemTreino(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          nomeExercicio: item.nomeExercicio,
          series: item.series,
          repeticoes: item.repeticoes,
          cargaKg: item.cargaKgPadrao,
          descansoSegundos: item.descansoSegundos,
          idTreino: '',
          ordemExercicio: 0,
        );
      }).toList(),
    );
    
    // Salvar no banco
    await banco.salvarDadosTreino(novoTreino);
  }
  
  // Recarregar treinos na UI
  setState(() {
    _carregarDados();
  });
}
```

### Passo 4: (Opcional) Permitir Re-ativar WorkFit

Adicione um botão "Reconfigur WorkFit" nas configurações:

```dart
ElevatedButton(
  onPressed: () {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: WorkFitOnboardingPage(
          onConfirm: (sugestoes) {
            _procesarSugestoesWorkFit(sugestoes);
            Navigator.pop(context);
          },
          onSkip: () => Navigator.pop(context),
        ),
      ),
    );
  },
  child: const Text('Reconfigur WorkFit Personal'),
),
```

## Testes

Todos os testes passam:

```bash
flutter test test/workfit/workfit_motor_test.dart
```

**Resultado**: ✅ 7/7 testes passando

- ✅ Gera sugestões para musculação hipertrofia 4x/semana
- ✅ Adapta para treino em casa sem academia
- ✅ Gera sugestões para CrossFit
- ✅ Gera sugestões para corrida de rua
- ✅ Nomes de treinos são descritivos (não genéricos)
- ✅ Exercícios têm séries/reps coerentes
- ✅ Serialização JSON funciona

## Recursos Já Integrados

- ✅ **1.786 exercícios**: Catálogo completo com 876 originais + 910 português
- ✅ **Segurança avançada**: R8 obfuscation, ProGuard, password policy forte
- ✅ **Build scripts**: `build_release_dev.ps1` e `build_release_producao.ps1`
- ✅ **SQLite persistência**: Banco pronto para salvar perfis e treinos

## Próximos Passos Recomendados

1. **Integrar com main.dart** (usar guia acima)
2. **Testar fluxo completo**: Criar conta → ver onboarding → gerar treinos → executar
3. **(Opcional) Melhorias futuras**:
   - Conectar a LLM real (Claude API) para geração mais inteligente
   - Adicionar histórico de performance do usuário
   - Sugestões adaptativas baseadas em progresso
   - Compartilhar treinos com amigos

