import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../dados/lembrete_treino.dart';
import '../dados/workholy_banco.dart';

class MetasLembretesPage extends StatefulWidget {
  const MetasLembretesPage({super.key});

  @override
  State<MetasLembretesPage> createState() => _MetasLembretesPageState();
}

class _MetasLembretesPageState extends State<MetasLembretesPage> {
  static const _chaveMeta = 'workholy_meta_treinos_semana_v1';
  static const _chaveLembreteAtivo = 'workholy_lembrete_treino_ativo_v1';
  static const _chaveDia = 'workholy_lembrete_treino_dia_v1';
  static const _chaveHora = 'workholy_lembrete_treino_hora_v1';
  static const _chaveMinuto = 'workholy_lembrete_treino_minuto_v1';
  static const _dias = {
    1: 'Segunda-feira',
    2: 'Terça-feira',
    3: 'Quarta-feira',
    4: 'Quinta-feira',
    5: 'Sexta-feira',
    6: 'Sábado',
    7: 'Domingo',
  };

  int _metaSemanal = 3;
  int _diaSemana = 1;
  TimeOfDay _horario = const TimeOfDay(hour: 18, minute: 0);
  bool _lembreteAtivo = false;
  bool _carregando = true;
  bool _salvando = false;
  String? _erroCarregamento;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final banco = WorkHolyBanco.instancia;
      final meta = await banco.lerInteiro(_chaveMeta) ?? 3;
      final dia = await banco.lerInteiro(_chaveDia) ?? 1;
      final hora = await banco.lerInteiro(_chaveHora) ?? 18;
      final minuto = await banco.lerInteiro(_chaveMinuto) ?? 0;
      final ativo = await banco.lerBooleano(_chaveLembreteAtivo) ?? false;
      if (!mounted) return;
      setState(() {
        _metaSemanal = meta.clamp(1, 7).toInt();
        _diaSemana = dia.clamp(1, 7).toInt();
        _horario = TimeOfDay(
          hour: hora.clamp(0, 23).toInt(),
          minute: minuto.clamp(0, 59).toInt(),
        );
        _lembreteAtivo = ativo;
        _carregando = false;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _erroCarregamento = erro.toString();
        _carregando = false;
      });
    }
  }

  Future<bool> _solicitarPermissao() async {
    final estado = await FlutterForegroundTask.checkNotificationPermission();
    if (estado == NotificationPermission.granted) return true;
    await FlutterForegroundTask.requestNotificationPermission();
    return await FlutterForegroundTask.checkNotificationPermission() ==
        NotificationPermission.granted;
  }

  Future<void> _definirLembrete(bool ativo) async {
    setState(() => _salvando = true);
    try {
      if (ativo && !await _solicitarPermissao()) {
        throw StateError(
          'Permissão de notificações negada. Ative-a nas configurações do Android.',
        );
      }

      if (ativo) {
        await LembreteTreino.agendar(
          diaSemana: _diaSemana,
          hora: _horario.hour,
          minuto: _horario.minute,
        );
      } else {
        await LembreteTreino.cancelar();
      }
      await WorkHolyBanco.instancia.salvarConfiguracoes({
        _chaveLembreteAtivo: ativo,
        _chaveDia: _diaSemana,
        _chaveHora: _horario.hour,
        _chaveMinuto: _horario.minute,
      });
      if (mounted) setState(() => _lembreteAtivo = ativo);
    } catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível atualizar o lembrete: $erro'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _salvarMeta(int valor) async {
    final metaAnterior = _metaSemanal;
    setState(() {
      _metaSemanal = valor;
      _salvando = true;
    });
    try {
      await WorkHolyBanco.instancia.salvarInteiro(_chaveMeta, valor);
    } catch (erro) {
      if (!mounted) return;
      setState(() => _metaSemanal = metaAnterior);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar a meta: $erro')),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _escolherHorario() async {
    final horario = await showTimePicker(
      context: context,
      initialTime: _horario,
    );
    if (horario == null || !mounted) return;
    setState(() => _horario = horario);
    if (_lembreteAtivo) await _definirLembrete(true);
  }

  Future<void> _definirDia(int? dia) async {
    if (dia == null) return;
    final diaAnterior = _diaSemana;
    setState(() => _diaSemana = dia);
    if (_lembreteAtivo) {
      await _definirLembrete(true);
    } else {
      try {
        await WorkHolyBanco.instancia.salvarInteiro(_chaveDia, dia);
      } catch (erro) {
        if (!mounted) return;
        setState(() => _diaSemana = diaAnterior);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar o dia: $erro')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return Scaffold(
        appBar: AppBar(title: const Text('Metas e lembretes')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Metas e lembretes')),
      body: _erroCarregamento != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Não foi possível carregar as preferências: '
                      '$_erroCarregamento',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _carregando = true;
                          _erroCarregamento = null;
                        });
                        _carregar();
                      },
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                const Text(
                  'Meta semanal',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Defina quantos treinos de musculação você quer concluir por semana.',
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.flag_outlined),
                    title: const Text('Treinos por semana'),
                    trailing: DropdownButton<int>(
                      value: _metaSemanal,
                      items: List.generate(
                        7,
                        (indice) => DropdownMenuItem(
                          value: indice + 1,
                          child: Text('${indice + 1}'),
                        ),
                      ),
                      onChanged: _salvando
                          ? null
                          : (valor) {
                              if (valor != null) _salvarMeta(valor);
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Lembrete semanal',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'O lembrete é local, recorrente e pode chegar alguns minutos '
                  'depois do horário escolhido por causa das restrições de '
                  'economia de bateria do Android.',
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Ativar lembrete'),
                        subtitle: const Text('Exibido mesmo com o app fechado'),
                        value: _lembreteAtivo,
                        onChanged: _salvando ? null : _definirLembrete,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Dia da semana'),
                        trailing: DropdownButton<int>(
                          value: _diaSemana,
                          items: _dias.entries
                              .map(
                                (dia) => DropdownMenuItem(
                                  value: dia.key,
                                  child: Text(dia.value),
                                ),
                              )
                              .toList(),
                          onChanged: _salvando ? null : _definirDia,
                        ),
                      ),
                      ListTile(
                        title: const Text('Horário'),
                        trailing: TextButton(
                          onPressed: _salvando ? null : _escolherHorario,
                          child: Text(_horario.format(context)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_salvando) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
    );
  }
}
