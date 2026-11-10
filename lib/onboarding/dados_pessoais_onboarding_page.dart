import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../dados/workholy_banco.dart';
import '../perfil_praticante_page.dart' show chavePerfilPraticante;
import '../sincronizacao/sincronizacao_usuario.dart';
import 'perfil_onboarding.dart';

/// Etapa obrigatória do primeiro acesso: coleta e grava os dados pessoais.
class DadosPessoaisOnboardingPage extends StatefulWidget {
  const DadosPessoaisOnboardingPage({super.key, this.nomeInicial});

  final String? nomeInicial;

  @override
  State<DadosPessoaisOnboardingPage> createState() =>
      _DadosPessoaisOnboardingPageState();
}

class _DadosPessoaisOnboardingPageState
    extends State<DadosPessoaisOnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _peso = TextEditingController();
  final _altura = TextEditingController();
  Map<String, dynamic> _perfilExistente = {};
  DateTime? _nascimento;
  String _objetivo = PerfilOnboarding.objetivos.first;
  String _experiencia = PerfilOnboarding.experiencias.first;
  String? _erroNascimento;
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarExistente();
  }

  Future<void> _carregarExistente() async {
    _nome.text = widget.nomeInicial ?? '';
    try {
      final texto = await WorkHolyBanco.instancia.lerTexto(
        chavePerfilPraticante,
      );
      if (texto != null) {
        final dados = jsonDecode(texto);
        if (dados is Map) {
          _perfilExistente = Map<String, dynamic>.from(dados);
          final nome = dados['nome']?.toString().trim() ?? '';
          if (nome.isNotEmpty) _nome.text = nome;
          _peso.text = dados['peso']?.toString() ?? '';
          _altura.text = dados['altura']?.toString() ?? '';
          _nascimento = DateTime.tryParse(
            dados['nascimento']?.toString() ?? '',
          );
          final objetivo = dados['objetivo']?.toString();
          if (objetivo != null &&
              PerfilOnboarding.objetivos.contains(objetivo)) {
            _objetivo = objetivo;
          }
          final experiencia = dados['experiencia']?.toString();
          if (experiencia != null &&
              PerfilOnboarding.experiencias.contains(experiencia)) {
            _experiencia = experiencia;
          }
        }
      }
    } catch (erro) {
      debugPrint('Não foi possível ler o perfil existente: $erro');
    }
    if (mounted) setState(() => _carregando = false);
  }

  String _formatarData(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/'
      '${data.month.toString().padLeft(2, '0')}/${data.year}';

  Future<void> _escolherNascimento() async {
    final data = await showDatePicker(
      context: context,
      initialDate: _nascimento ?? DateTime(DateTime.now().year - 25),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Data de nascimento',
    );
    if (data != null) {
      setState(() {
        _nascimento = data;
        _erroNascimento = null;
      });
    }
  }

  Future<void> _salvar() async {
    final formularioValido = _formKey.currentState!.validate();
    final erroNascimento = PerfilOnboarding.validarNascimento(_nascimento);
    setState(() => _erroNascimento = erroNascimento);
    if (!formularioValido || erroNascimento != null) return;

    setState(() => _salvando = true);
    try {
      final nome = _nome.text.trim();
      final dados = {
        ..._perfilExistente,
        'nome': nome,
        'peso': _peso.text.trim().replaceAll(',', '.'),
        'altura': _altura.text.trim().replaceAll(',', '.'),
        'nascimento': _nascimento!.toIso8601String(),
        'objetivo': _objetivo,
        'experiencia': _experiencia,
        'atualizadoEm': DateTime.now().toIso8601String(),
      };
      await WorkHolyBanco.instancia.salvarTexto(
        chavePerfilPraticante,
        jsonEncode(dados),
      );
      SincronizacaoUsuario.instancia.agendarEnvio();

      final usuario = FirebaseAuth.instance.currentUser;
      if (usuario != null && usuario.displayName != nome) {
        try {
          await usuario.updateDisplayName(nome);
        } on FirebaseAuthException catch (erro) {
          debugPrint(
            'Não foi possível atualizar o nome da conta: ${erro.code}',
          );
        }
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (erro) {
      debugPrint('Erro ao salvar dados do primeiro acesso: $erro');
      if (mounted) {
        setState(() => _salvando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível salvar seus dados. Tente novamente.',
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nome.dispose();
    _peso.dispose();
    _altura.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Seus dados'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: _carregando
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        'Vamos conhecer você',
                        style: tema.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Esses dados são usados nos cálculos do app, como '
                        'calorias da corrida, e para montar seu treino. '
                        'Todos os campos são obrigatórios.',
                        style: tema.textTheme.bodyMedium?.copyWith(
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nome,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nome',
                          border: OutlineInputBorder(),
                        ),
                        validator: PerfilOnboarding.validarNome,
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _escolherNascimento,
                        borderRadius: BorderRadius.circular(4),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Data de nascimento',
                            border: const OutlineInputBorder(),
                            errorText: _erroNascimento,
                            suffixIcon: const Icon(Icons.calendar_month),
                          ),
                          child: Text(
                            _nascimento == null
                                ? 'Selecionar data'
                                : _formatarData(_nascimento!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _peso,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Peso',
                                suffixText: 'kg',
                                border: OutlineInputBorder(),
                              ),
                              validator: PerfilOnboarding.validarPeso,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _altura,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Altura',
                                suffixText: 'cm',
                                border: OutlineInputBorder(),
                              ),
                              validator: PerfilOnboarding.validarAltura,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _objetivo,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Objetivo principal',
                          border: OutlineInputBorder(),
                        ),
                        items: PerfilOnboarding.objetivos
                            .map(
                              (valor) => DropdownMenuItem(
                                value: valor,
                                child: Text(valor),
                              ),
                            )
                            .toList(),
                        onChanged: (valor) {
                          if (valor != null) setState(() => _objetivo = valor);
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _experiencia,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Experiência com treino',
                          border: OutlineInputBorder(),
                        ),
                        items: PerfilOnboarding.experiencias
                            .map(
                              (valor) => DropdownMenuItem(
                                value: valor,
                                child: Text(valor),
                              ),
                            )
                            .toList(),
                        onChanged: (valor) {
                          if (valor != null) {
                            setState(() => _experiencia = valor);
                          }
                        },
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _salvando ? null : _salvar,
                          child: _salvando
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Continuar'),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
