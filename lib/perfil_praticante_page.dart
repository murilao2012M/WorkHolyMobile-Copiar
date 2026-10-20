
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _perfilKey = 'workholy_perfil_praticante_v1';
const _verdePerfil = Color(0xFFB7F34A);
const _textoPerfil = Color(0xFFA4AAA0);

class PerfilPraticantePage extends StatefulWidget {
  const PerfilPraticantePage({super.key});

  @override
  State<PerfilPraticantePage> createState() =>
      _PerfilPraticantePageState();
}

class _PerfilPraticantePageState extends State<PerfilPraticantePage> {
  final _formKey = GlobalKey<FormState>();

  final _nome = TextEditingController();
  final _altura = TextEditingController();
  final _peso = TextEditingController();
  final _objetivoPersonalizado = TextEditingController();

  final Map<String, TextEditingController> _medidas = {
    'Cintura': TextEditingController(),
    'Peito': TextEditingController(),
    'Quadril': TextEditingController(),
    'Braço': TextEditingController(),
    'Coxa': TextEditingController(),
    'Panturrilha': TextEditingController(),
  };

  DateTime? _nascimento;
  String _objetivo = 'Hipertrofia';
  String _experiencia = 'Iniciante';
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarPerfil();
  }

  Future<void> _carregarPerfil() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final texto = prefs.getString(_perfilKey);

      if (texto != null) {
        final dados = jsonDecode(texto) as Map<String, dynamic>;

        _nome.text = dados['nome']?.toString() ?? '';
        _altura.text = dados['altura']?.toString() ?? '';
        _peso.text = dados['peso']?.toString() ?? '';

        _objetivo = dados['objetivo']?.toString() ?? 'Hipertrofia';
        _experiencia =
            dados['experiencia']?.toString() ?? 'Iniciante';

        _objetivoPersonalizado.text =
            dados['objetivoPersonalizado']?.toString() ?? '';

        final nascimento = dados['nascimento']?.toString();
        if (nascimento != null && nascimento.isNotEmpty) {
          _nascimento = DateTime.tryParse(nascimento);
        }

        final medidasSalvas = dados['medidas'];
        if (medidasSalvas is Map) {
          for (final entrada in _medidas.entries) {
            entrada.value.text =
                medidasSalvas[entrada.key]?.toString() ?? '';
          }
        }
      }
    } catch (erro) {
      debugPrint('Erro ao carregar perfil: $erro');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível carregar o perfil salvo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  void dispose() {
    _nome.dispose();
    _altura.dispose();
    _peso.dispose();
    _objetivoPersonalizado.dispose();

    for (final controller in _medidas.values) {
      controller.dispose();
    }

    super.dispose();
  }

  double? _numero(String texto) {
    return double.tryParse(texto.trim().replaceAll(',', '.'));
  }

  String? _validarNumero(
    String? valor, {
    required String campo,
    required double minimo,
    required double maximo,
  }) {
    if (valor == null || valor.trim().isEmpty) return null;

    final numero = _numero(valor);
    if (numero == null || numero < minimo || numero > maximo) {
      return 'Informe um valor entre $minimo e $maximo.';
    }

    return null;
  }

  Future<void> _selecionarNascimento() async {
    final hoje = DateTime.now();
    final selecionada = await showDatePicker(
      context: context,
      initialDate: _nascimento ?? DateTime(hoje.year - 18),
      firstDate: DateTime(1900),
      lastDate: hoje,
      helpText: 'Data de nascimento',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );

    if (selecionada != null && mounted) {
      setState(() => _nascimento = selecionada);
    }
  }

  Future<void> _salvarPerfil() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      final dados = <String, dynamic>{
        'nome': _nome.text.trim(),
        'nascimento': _nascimento?.toIso8601String(),
        'altura': _altura.text.trim(),
        'peso': _peso.text.trim(),
        'objetivo': _objetivo,
        'objetivoPersonalizado': _objetivoPersonalizado.text.trim(),
        'experiencia': _experiencia,
        'medidas': {
          for (final entrada in _medidas.entries)
            entrada.key: entrada.value.text.trim(),
        },
        'atualizadoEm': DateTime.now().toIso8601String(),
      };

      final sucesso = await prefs.setString(
        _perfilKey,
        jsonEncode(dados),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            sucesso ? 'Perfil salvo com sucesso!' : 'Não foi possível salvar.',
          ),
        ),
      );
    } catch (erro) {
      debugPrint('Erro ao salvar perfil: $erro');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao salvar o perfil.')),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Widget _campo(
    String rotulo,
    TextEditingController controller, {
    String? sufixo,
    String? Function(String?)? validator,
    TextInputType teclado = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: teclado,
      validator: validator,
      decoration: InputDecoration(
        labelText: rotulo,
        suffixText: sufixo,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _secao(String titulo, IconData icone, List<Widget> filhos) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, color: _verdePerfil),
                const SizedBox(width: 10),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ...filhos,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Center(
        child: CircularProgressIndicator(color: _verdePerfil),
      );
    }

    final nascimentoTexto = _nascimento == null
        ? 'Selecionar data'
        : '${_nascimento!.day.toString().padLeft(2, '0')}/'
          '${_nascimento!.month.toString().padLeft(2, '0')}/'
          '${_nascimento!.year}';

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Meu perfil',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Seus dados e sua evolução física em um só lugar.',
            style: TextStyle(color: _textoPerfil),
          ),
          const SizedBox(height: 20),

          _secao('Dados pessoais', Icons.person_outline, [
            _campo('Nome', _nome),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data de nascimento'),
              subtitle: Text(nascimentoTexto),
              trailing: const Icon(Icons.calendar_month),
              onTap: _selecionarNascimento,
            ),
          ]),

          _secao('Dados físicos', Icons.monitor_weight_outlined, [
            Row(
              children: [
                Expanded(
                  child: _campo(
                    'Altura',
                    _altura,
                    sufixo: 'cm',
                    teclado: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) => _validarNumero(
                      v,
                      campo: 'Altura',
                      minimo: 50,
                      maximo: 260,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _campo(
                    'Peso atual',
                    _peso,
                    sufixo: 'kg',
                    teclado: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) => _validarNumero(
                      v,
                      campo: 'Peso',
                      minimo: 1,
                      maximo: 500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _objetivo,
              decoration: const InputDecoration(
                labelText: 'Objetivo principal',
                border: OutlineInputBorder(),
              ),
              items: const [
                'Hipertrofia',
                'Emagrecimento',
                'Força',
                'Condicionamento físico',
                'Saúde e bem-estar',
                'Outro',
              ].map((item) {
                return DropdownMenuItem(value: item, child: Text(item));
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _objetivo = v);
              },
            ),
            if (_objetivo == 'Outro') ...[
              const SizedBox(height: 14),
              _campo('Descreva seu objetivo', _objetivoPersonalizado),
            ],
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _experiencia,
              decoration: const InputDecoration(
                labelText: 'Experiência com musculação',
                border: OutlineInputBorder(),
              ),
              items: const [
                'Iniciante',
                'Intermediário',
                'Avançado',
              ].map((item) {
                return DropdownMenuItem(value: item, child: Text(item));
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _experiencia = v);
              },
            ),
          ]),

          _secao('Medidas corporais', Icons.straighten, [
            const Text(
              'Medidas em centímetros. Todos os campos são opcionais.',
              style: TextStyle(color: _textoPerfil),
            ),
            const SizedBox(height: 16),
            ..._medidas.entries.map((entrada) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _campo(
                  entrada.key,
                  entrada.value,
                  sufixo: 'cm',
                  teclado: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) => _validarNumero(
                    v,
                    campo: entrada.key,
                    minimo: 1,
                    maximo: 300,
                  ),
                ),
              );
            }),
          ]),

          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _salvando ? null : _salvarPerfil,
              icon: _salvando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_salvando ? 'Salvando...' : 'Salvar perfil'),
              style: FilledButton.styleFrom(
                backgroundColor: _verdePerfil,
                foregroundColor: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
