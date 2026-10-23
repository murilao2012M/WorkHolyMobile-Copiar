import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const _verde = Color(0xFFB7F34A);

class AutenticacaoPage extends StatefulWidget {
  const AutenticacaoPage({super.key});

  @override
  State<AutenticacaoPage> createState() => _AutenticacaoPageState();
}

class _AutenticacaoPageState extends State<AutenticacaoPage> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _criandoConta = false;
  bool _enviando = false;
  bool _ocultarSenha = true;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  String? _validarEmail(String? valor) {
    final email = valor?.trim() ?? '';
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
        ? null
        : 'Informe um e-mail válido.';
  }

  Future<void> _enviar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      final auth = FirebaseAuth.instance;
      if (_criandoConta) {
        final credencial = await auth.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _senha.text,
        );
        await credencial.user?.sendEmailVerification();
        if (mounted) {
          _mensagem('Conta criada. Confirme o e-mail enviado para continuar.');
        }
      } else {
        await auth.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _senha.text,
        );
      }
    } on FirebaseAuthException catch (erro) {
      final texto = switch (erro.code) {
        'email-already-in-use' => 'Este e-mail já possui uma conta.',
        'invalid-credential' ||
        'wrong-password' => 'E-mail ou senha incorretos.',
        'weak-password' => 'A senha deve ter pelo menos 6 caracteres.',
        'user-not-found' => 'Nenhuma conta encontrada para este e-mail.',
        'too-many-requests' => 'Muitas tentativas. Aguarde e tente novamente.',
        _ => 'Não foi possível concluir. Tente novamente.',
      };
      if (mounted) _mensagem(texto);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _recuperarSenha() async {
    final email = _email.text.trim();
    if (_validarEmail(email) != null) {
      _mensagem('Informe seu e-mail para recuperar a senha.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) _mensagem('Enviamos um link para redefinir sua senha.');
    } on FirebaseAuthException {
      if (mounted) _mensagem('Não foi possível enviar o e-mail agora.');
    }
  }

  void _mensagem(String texto) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(texto)));

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.fitness_center, size: 68, color: _verde),
                const SizedBox(height: 18),
                Text(
                  _criandoConta ? 'Crie sua conta' : 'Entre no WorkHoly',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _criandoConta
                      ? 'Salve seu progresso e acesse em qualquer dispositivo.'
                      : 'Use seu e-mail para continuar.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _email,
                  validator: _validarEmail,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _senha,
                  obscureText: _ocultarSenha,
                  validator: (v) => (v?.length ?? 0) >= 6
                      ? null
                      : 'A senha deve ter ao menos 6 caracteres.',
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _ocultarSenha = !_ocultarSenha),
                      icon: Icon(
                        _ocultarSenha ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                ),
                if (!_criandoConta)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _recuperarSenha,
                      child: const Text('Esqueci minha senha'),
                    ),
                  ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _enviando ? null : _enviar,
                  style: FilledButton.styleFrom(
                    backgroundColor: _verde,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(
                    _enviando
                        ? 'Aguarde...'
                        : _criandoConta
                        ? 'Criar conta'
                        : 'Entrar',
                  ),
                ),
                TextButton(
                  onPressed: _enviando
                      ? null
                      : () => setState(() => _criandoConta = !_criandoConta),
                  child: Text(
                    _criandoConta
                        ? 'Já tenho uma conta'
                        : 'Criar uma conta gratuita',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class ConfirmarEmailPage extends StatefulWidget {
  const ConfirmarEmailPage({super.key});
  @override
  State<ConfirmarEmailPage> createState() => _ConfirmarEmailPageState();
}

class _ConfirmarEmailPageState extends State<ConfirmarEmailPage> {
  bool _enviando = false;
  Future<void> _verificar() async {
    await FirebaseAuth.instance.currentUser?.reload();
    if (mounted) setState(() {});
  }

  Future<void> _reenviar() async {
    setState(() => _enviando = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Novo e-mail de confirmação enviado.')),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.mark_email_unread_outlined,
                size: 64,
                color: _verde,
              ),
              const SizedBox(height: 20),
              const Text(
                'Confirme seu e-mail',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Enviamos um link para ${FirebaseAuth.instance.currentUser?.email ?? 'seu e-mail'}. Depois de confirmar, volte e toque abaixo.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _verificar,
                child: const Text('Já confirmei meu e-mail'),
              ),
              TextButton(
                onPressed: _enviando ? null : _reenviar,
                child: Text(_enviando ? 'Enviando...' : 'Reenviar confirmação'),
              ),
              TextButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                child: const Text('Sair'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
