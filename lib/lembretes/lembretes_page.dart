import 'package:flutter/material.dart' hide Icon;

import '../voz/voz_treinador.dart';
import 'lembretes_treino.dart';

/// Tela de lembretes de treino e da voz do treinador.
class LembretesPage extends StatefulWidget {
  const LembretesPage({super.key});

  @override
  State<LembretesPage> createState() => _LembretesPageState();
}

class _LembretesPageState extends State<LembretesPage> {
  static const _nomesDias = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  ConfigLembretes _config = const ConfigLembretes();
  bool _carregando = true;
  bool _salvando = false;
  bool _voz = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final config = await LembretesTreino.instancia.ler();
    await VozTreinador.instancia.carregarPreferencia();
    if (!mounted) return;
    setState(() {
      _config = config;
      _voz = VozTreinador.instancia.ativa;
      _carregando = false;
    });
  }

  Future<void> _aplicar(ConfigLembretes nova) async {
    final anterior = _config;
    setState(() {
      _config = nova;
      _salvando = true;
    });
    final erro = await LembretesTreino.instancia.aplicar(nova);
    if (!mounted) return;
    setState(() {
      _salvando = false;
      if (erro != null) _config = anterior.copiar(ativo: false);
    });
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
    }
  }

  Future<void> _escolherHora() async {
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _config.hora, minute: _config.minuto),
    );
    if (hora == null) return;
    await _aplicar(_config.copiar(hora: hora.hour, minuto: hora.minute));
  }

  @override
  Widget build(BuildContext context) {
    final hora =
        '${_config.hora.toString().padLeft(2, '0')}:'
        '${_config.minuto.toString().padLeft(2, '0')}';
    return Scaffold(
      appBar: AppBar(title: const Text('Lembretes e voz')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Lembrete de treino'),
                        subtitle: const Text(
                          'Uma notificação nos dias e horário escolhidos.',
                        ),
                        value: _config.ativo,
                        onChanged: _salvando
                            ? null
                            : (v) => _aplicar(_config.copiar(ativo: v)),
                      ),
                      if (_config.ativo) ...[
                        ListTile(
                          title: const Text('Horário'),
                          trailing: Text(hora),
                          onTap: _salvando ? null : _escolherHora,
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              for (var i = 0; i < 7; i++)
                                FilterChip(
                                  label: Text(_nomesDias[i]),
                                  selected: _config.dias.contains(i + 1),
                                  onSelected: _salvando
                                      ? null
                                      : (marcado) {
                                          final dias = {..._config.dias};
                                          marcado
                                              ? dias.add(i + 1)
                                              : dias.remove(i + 1);
                                          _aplicar(_config.copiar(dias: dias));
                                        },
                                ),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: Text(
                            'O horário é aproximado: o Android pode atrasar '
                            'alguns minutos para poupar bateria. O lembrete '
                            'só avisa; ele não fala.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: SwitchListTile(
                    title: const Text('Voz do treinador'),
                    subtitle: const Text(
                      'Fala séries, descansos e quilômetros com o app aberto.',
                    ),
                    value: _voz,
                    onChanged: (v) async {
                      setState(() => _voz = v);
                      await VozTreinador.instancia.definirAtiva(v);
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
