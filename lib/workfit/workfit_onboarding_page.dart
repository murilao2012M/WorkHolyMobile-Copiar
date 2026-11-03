import 'package:flutter/material.dart';

import '../painel/w_icone.dart' show WIcone;

import 'workfit_aprendizado.dart';
import 'workfit_perfil.dart';
import 'workfit_motor.dart';

class WorkFitOnboardingPage extends StatefulWidget {
  final Function(List<WorkFitSugestao>) onConfirm;
  final VoidCallback onSkip;
  final List<ExercicioBanco> exercicios;
  final AprendizadoWorkFit? aprendizado;

  const WorkFitOnboardingPage({
    super.key,
    required this.onConfirm,
    required this.onSkip,
    required this.exercicios,
    this.aprendizado,
  });

  @override
  State<WorkFitOnboardingPage> createState() => _WorkFitOnboardingPageState();
}

class _WorkFitOnboardingPageState extends State<WorkFitOnboardingPage> {
  int _currentStep = 0;

  String? _tipoTreino;
  int? _minutosPorDia;
  int? _diasPorSemana;
  String? _objetivo;
  String? _equipamento;
  String? _experiencia;
  final Set<String> _equipamentosDisponiveis = {};
  List<WorkFitSugestao>? _sugestoes;

  final List<String> _tiposTreino = [
    'Musculação',
    'CrossFit',
    'Corrida de Rua',
    'Personal Trainer',
  ];

  final List<int> _minutos = [10, 15, 20, 30, 45, 60];
  final List<int> _dias = [1, 2, 3, 4, 5, 6, 7];
  final List<String> _objetivos = [
    'Emagrecimento',
    'Hipertrofia',
    'Força',
    'Resistência muscular',
    'Condicionamento geral',
    'Sou atleta amador',
    'Sou apenas amante do esporte',
  ];

  final List<String> _equipamentos = [
    'Treino na Academia',
    'Treino em casa com alguns aparelhos',
    'Corro na rua',
    'Treino em condomínio',
    'Treino com Personal na Academia',
    'Treino em Estúdio de CrossFit',
  ];

  void _proximaEtapa() {
    if (_currentStep == 0 && _tipoTreino == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione um tipo de treino')),
      );
      return;
    }
    if (_currentStep == 1 && _minutosPorDia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione os minutos por dia'),
        ),
      );
      return;
    }
    if (_currentStep == 2 && _diasPorSemana == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione os dias por semana'),
        ),
      );
      return;
    }
    if (_currentStep == 3 && _objetivo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione seu objetivo')),
      );
      return;
    }
    if (_currentStep == 4 && _equipamento == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione seu equipamento')),
      );
      return;
    }

    if (_currentStep == 5 && _experiencia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione seu nível de experiência')),
      );
      return;
    }

    if (_currentStep == 6) {
      _gerarSugestoes();
    } else {
      setState(() => _currentStep++);
    }
  }

  void _etapaAnterior() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _gerarSugestoes() {
    final perfil = WorkFitPerfil(
      tipoTreino: switch (_tipoTreino!) {
        'Musculação' => 'musculacao',
        'CrossFit' => 'crossfit',
        'Corrida de Rua' => 'corrida',
        'Personal Trainer' => 'personal',
        _ => throw StateError('Modalidade de treino desconhecida'),
      },
      minutosPorDia: _minutosPorDia!,
      diasPorSemana: _diasPorSemana!,
      objetivo: switch (_objetivo!) {
        'Força' => 'forca',
        'Resistência muscular' => 'resistencia',
        'Condicionamento geral' => 'condicionamento',
        final objetivo => objetivo.toLowerCase().replaceAll(' ', ''),
      },
      equipamento: _equipamento!,
      experiencia: _experiencia!,
      equipamentosDisponiveis: _equipamentosDisponiveis.toList(),
    );

    final sugestoes = WorkFitMotor.gerarSugestoes(
      perfil,
      widget.exercicios,
      aprendizado: widget.aprendizado,
    );
    setState(() {
      _sugestoes = sugestoes;
      _currentStep = 7;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Monte seu plano'),
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _construirIndicadorProgresso(),
                    const SizedBox(height: 20),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_currentStep == 0) _construirEtapa1(),
                            if (_currentStep == 1) _construirEtapa2(),
                            if (_currentStep == 2) _construirEtapa3(),
                            if (_currentStep == 3) _construirEtapa4(),
                            if (_currentStep == 4) _construirEtapa5(),
                            if (_currentStep == 5) _construirExperiencia(),
                            if (_currentStep == 6) _construirEquipamentos(),
                            if (_currentStep == 7) _construirEtapa6(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _construirBotoes(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _construirIndicadorProgresso() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Etapa ${_currentStep + 1} de 8',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / 8,
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _construirEtapa1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'O que você gosta de treinar?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ..._tiposTreino.map(
          (tipo) => RadioListTile<String>(
            title: Text(tipo),
            value: tipo,
            groupValue: _tipoTreino,
            onChanged: (value) => setState(() => _tipoTreino = value),
          ),
        ),
      ],
    );
  }

  Widget _construirEtapa2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quantos minutos você treina por dia?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _minutos
              .map(
                (minuto) => FilterChip(
                  label: Text('$minuto min'),
                  selected: _minutosPorDia == minuto,
                  onSelected: (selected) =>
                      setState(() => _minutosPorDia = selected ? minuto : null),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _construirEtapa3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quantas vezes por semana?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _dias
              .map(
                (dia) => FilterChip(
                  label: Text('$dia x'),
                  selected: _diasPorSemana == dia,
                  onSelected: (selected) =>
                      setState(() => _diasPorSemana = selected ? dia : null),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _construirEtapa4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Qual é o seu objetivo?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ..._objetivos.map(
          (obj) => RadioListTile<String>(
            title: Text(obj),
            value: obj,
            groupValue: _objetivo,
            onChanged: (value) => setState(() => _objetivo = value),
          ),
        ),
      ],
    );
  }

  Widget _construirEtapa5() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Onde você treina?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ..._equipamentos.map(
          (equip) => RadioListTile<String>(
            title: Text(equip),
            value: equip,
            groupValue: _equipamento,
            onChanged: (value) => setState(() => _equipamento = value),
          ),
        ),
      ],
    );
  }

  Widget _construirExperiencia() {
    const niveis = {
      'iniciante': 'Iniciante',
      'intermediario': 'Intermediário',
      'avancado': 'Avançado',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Qual é sua experiência com exercícios?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        ...niveis.entries.map(
          (nivel) => RadioListTile<String>(
            title: Text(nivel.value),
            value: nivel.key,
            groupValue: _experiencia,
            onChanged: (value) => setState(() => _experiencia = value),
          ),
        ),
        const Text(
          'A recomendação não considera lesões, condições de saúde ou limitações. Procure orientação profissional antes de treinar.',
        ),
      ],
    );
  }

  Widget _construirEquipamentos() {
    const opcoes = {
      'halteres': 'Halteres',
      'barra': 'Barra e anilhas',
      'maquinas': 'Máquinas (incluindo Smith e leg press)',
      'polia': 'Polia',
      'kettlebell': 'Kettlebell',
      'elastico': 'Elásticos',
      'bola': 'Bolas de exercício',
      'corda': 'Corda',
      'rolo': 'Rolo ou roda abdominal',
      'banco': 'Banco de exercícios',
      'barra_fixa': 'Barra fixa',
      'caixa': 'Caixa ou plataforma de exercícios',
      'cadeira': 'Cadeira estável',
      'paralelas': 'Barras paralelas',
      'argolas': 'Argolas de ginástica',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quais equipamentos você tem disponíveis?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'Marque apenas os disponíveis. Sem seleção, serão usados exercícios com peso corporal.',
        ),
        ...opcoes.entries.map(
          (opcao) => CheckboxListTile(
            secondary: WIcone(
              const {
                    'halteres': 'dumbbell',
                    'barra': 'barbell',
                    'kettlebell': 'kettlebell',
                    'elastico': 'stretch',
                    'bola': 'yoga',
                    'rolo': 'stretch',
                    'banco': 'bench',
                    'maquinas': 'weight_plate',
                  }[opcao.key] ??
                  'dumbbell',
              size: 24,
            ),
            title: Text(opcao.value),
            value: _equipamentosDisponiveis.contains(opcao.key),
            onChanged: (selecionado) => setState(() {
              if (selecionado == true) {
                _equipamentosDisponiveis.add(opcao.key);
              } else {
                _equipamentosDisponiveis.remove(opcao.key);
              }
            }),
          ),
        ),
      ],
    );
  }

  Widget _construirEtapa6() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vamos começar o treino!',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Text(
          _sugestoes?.isEmpty == true
              ? 'Nenhum exercício compatível foi encontrado. Volte e altere as opções ou crie um treino manualmente.'
              : 'WorkFit Personal criou ${_sugestoes?.length ?? 0} treino(s) para você. Ajuste o plano com um profissional de educação física:',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        ..._sugestoes
                ?.map(
                  (sugestao) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sugestao.nomeTreino,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            sugestao.descricao,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${sugestao.exercicios.length} exercícios • ~${sugestao.tempoEstimadoMinutos} min',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey),
                          ),
                          ...sugestao.exercicios.map(
                            (ex) => Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${ex.nomeExercicio} — ${ex.justificativa}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList() ??
            [],
      ],
    );
  }

  Widget _construirBotoes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_currentStep < 7)
          ElevatedButton(
            onPressed: _proximaEtapa,
            child: Text(_currentStep == 6 ? 'Gerar Treinos' : 'Próximo'),
          ),
        if (_currentStep == 7)
          ElevatedButton(
            onPressed: _sugestoes?.isNotEmpty == true
                ? () => widget.onConfirm(_sugestoes!)
                : null,
            child: const Text('Confirmar e Começar'),
          ),
        const SizedBox(height: 8),
        if (_currentStep < 7)
          OutlinedButton(
            onPressed: _currentStep > 0 ? _etapaAnterior : widget.onSkip,
            child: Text(
              _currentStep > 0 ? 'Anterior' : 'Criar treino manualmente',
            ),
          ),
        if (_currentStep == 7)
          OutlinedButton(
            onPressed: _etapaAnterior,
            child: const Text('Alterar opções'),
          ),
        if (_currentStep == 7)
          OutlinedButton(
            onPressed: widget.onSkip,
            child: const Text('Criar Treino Manualmente'),
          ),
      ],
    );
  }
}
