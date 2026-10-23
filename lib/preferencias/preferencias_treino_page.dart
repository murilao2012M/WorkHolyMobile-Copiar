import 'package:flutter/material.dart';

import '../dados/workholy_banco.dart';

class PreferenciasTreinoPage extends StatefulWidget {
  const PreferenciasTreinoPage({super.key});

  @override
  State<PreferenciasTreinoPage> createState() => _PreferenciasTreinoPageState();
}

class _PreferenciasTreinoPageState extends State<PreferenciasTreinoPage> {
  static const _chaveObjetivo = 'workholy_pref_treino_objetivo_v1';
  static const _chaveNivel = 'workholy_pref_treino_nivel_v1';
  static const _chaveDias = 'workholy_pref_treino_dias_v1';
  static const _chaveDuracao = 'workholy_pref_treino_duracao_v1';
  static const _chaveDescanso = 'workholy_pref_treino_descanso_v1';

  String _objetivo = 'Hipertrofia';
  String _nivel = 'Intermediário';
  int _dias = 4;
  int _duracao = 60;
  int _descanso = 90;

  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarPreferencias();
  }

  Future<void> _carregarPreferencias() async {
    final banco = WorkHolyBanco.instancia;
    final objetivo = await banco.lerTexto(_chaveObjetivo);
    final nivel = await banco.lerTexto(_chaveNivel);
    final dias = await banco.lerInteiro(_chaveDias);
    final duracao = await banco.lerInteiro(_chaveDuracao);
    final descanso = await banco.lerInteiro(_chaveDescanso);

    if (!mounted) return;

    setState(() {
      _objetivo = objetivo ?? 'Hipertrofia';
      _nivel = nivel ?? 'Intermediário';
      _dias = dias ?? 4;
      _duracao = duracao ?? 60;
      _descanso = descanso ?? 90;
      _carregando = false;
    });
  }

  Future<void> _salvarPreferencias() async {
    if (_salvando) return;

    setState(() => _salvando = true);

    try {
      await WorkHolyBanco.instancia.salvarConfiguracoes({
        _chaveObjetivo: _objetivo,
        _chaveNivel: _nivel,
        _chaveDias: _dias,
        _chaveDuracao: _duracao,
        _chaveDescanso: _descanso,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferências de treino salvas.')),
      );
    } catch (erro) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível salvar as preferências.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  Future<void> _restaurarPadrao() async {
    setState(() {
      _objetivo = 'Hipertrofia';
      _nivel = 'Intermediário';
      _dias = 4;
      _duracao = 60;
      _descanso = 90;
    });

    await _salvarPreferencias();
  }

  Widget _secao(String titulo, Widget conteudo) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            conteudo,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preferências de treino')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Personalize sua rotina de treinamento.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),

                _secao(
                  'Objetivo principal',
                  DropdownButtonFormField<String>(
                    initialValue: _objetivo,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Objetivo'),
                    items: const [
                      DropdownMenuItem(
                        value: 'Hipertrofia',
                        child: Text('Hipertrofia muscular'),
                      ),
                      DropdownMenuItem(
                        value: 'Força',
                        child: Text('Ganho de força'),
                      ),
                      DropdownMenuItem(
                        value: 'Emagrecimento',
                        child: Text('Emagrecimento'),
                      ),
                      DropdownMenuItem(
                        value: 'Resistência',
                        child: Text('Resistência muscular'),
                      ),
                      DropdownMenuItem(
                        value: 'Condicionamento',
                        child: Text('Condicionamento físico'),
                      ),
                    ],
                    onChanged: (valor) {
                      if (valor != null) {
                        setState(() => _objetivo = valor);
                      }
                    },
                  ),
                ),

                _secao(
                  'Nível de experiência',
                  DropdownButtonFormField<String>(
                    initialValue: _nivel,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Experiência'),
                    items: const [
                      DropdownMenuItem(
                        value: 'Iniciante',
                        child: Text('Iniciante'),
                      ),
                      DropdownMenuItem(
                        value: 'Intermediário',
                        child: Text('Intermediário'),
                      ),
                      DropdownMenuItem(
                        value: 'Avançado',
                        child: Text('Avançado'),
                      ),
                    ],
                    onChanged: (valor) {
                      if (valor != null) {
                        setState(() => _nivel = valor);
                      }
                    },
                  ),
                ),

                _secao(
                  'Rotina semanal',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dias de treino por semana: $_dias'),
                      Slider(
                        value: _dias.toDouble(),
                        min: 1,
                        max: 7,
                        divisions: 6,
                        label: '$_dias dias',
                        onChanged: (valor) {
                          setState(() => _dias = valor.round());
                        },
                      ),
                    ],
                  ),
                ),

                _secao(
                  'Duração da sessão',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tempo disponível: $_duracao minutos'),
                      Slider(
                        value: _duracao.toDouble(),
                        min: 15,
                        max: 120,
                        divisions: 7,
                        label: '$_duracao min',
                        onChanged: (valor) {
                          setState(() => _duracao = valor.round());
                        },
                      ),
                    ],
                  ),
                ),

                _secao(
                  'Descanso entre séries',
                  DropdownButtonFormField<int>(
                    initialValue: _descanso,
                    decoration: const InputDecoration(
                      labelText: 'Intervalo de descanso',
                    ),
                    items: const [
                      DropdownMenuItem(value: 30, child: Text('30 segundos')),
                      DropdownMenuItem(value: 60, child: Text('60 segundos')),
                      DropdownMenuItem(value: 90, child: Text('90 segundos')),
                      DropdownMenuItem(value: 120, child: Text('2 minutos')),
                      DropdownMenuItem(value: 180, child: Text('3 minutos')),
                    ],
                    onChanged: (valor) {
                      if (valor != null) {
                        setState(() => _descanso = valor);
                      }
                    },
                  ),
                ),

                FilledButton.icon(
                  onPressed: _salvando ? null : _salvarPreferencias,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    _salvando ? 'Salvando...' : 'Salvar preferências',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _salvando ? null : _restaurarPadrao,
                  child: const Text('Restaurar padrões'),
                ),
              ],
            ),
    );
  }
}
