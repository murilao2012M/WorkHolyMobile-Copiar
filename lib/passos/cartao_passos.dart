import 'package:flutter/material.dart';

import '../painel/componentes_painel.dart';
import 'passos_do_dia.dart';

/// Cartão do painel com os passos de hoje. O contador só liga depois que o
/// usuário aceita, para a permissão não aparecer de surpresa.
class CartaoPassos extends StatefulWidget {
  const CartaoPassos({super.key});

  @override
  State<CartaoPassos> createState() => _CartaoPassosState();
}

class _CartaoPassosState extends State<CartaoPassos> {
  final _passos = PassosDoDia.instancia;
  bool _ligado = false;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    final ligado = await _passos.preferenciaAtiva();
    if (ligado) await _passos.iniciar();
    if (!mounted) return;
    setState(() {
      _ligado = ligado;
      _carregando = false;
    });
  }

  Future<void> _alternar(bool valor) async {
    setState(() => _ligado = valor);
    await _passos.definirAtivo(valor);
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CartaoPainel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TituloSecaoPainel(
              'Passos de hoje',
              icone: Icons.directions_walk,
              trailing: Switch(value: _ligado, onChanged: _alternar),
            ),
            const SizedBox(height: 8),
            if (!_ligado)
              const Text(
                'Ative para contar seus passos com o sensor do celular.',
                style: TextStyle(color: painelTextoSuave),
              )
            else
              ValueListenableBuilder<String?>(
                valueListenable: _passos.indisponivel,
                builder: (context, erro, _) {
                  if (erro != null) {
                    return Text(
                      erro,
                      style: const TextStyle(color: painelTextoSuave),
                    );
                  }
                  return ValueListenableBuilder<int?>(
                    valueListenable: _passos.hoje,
                    builder: (context, passos, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          passos == null ? 'Aguardando o sensor...' : '$passos',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Conta a partir da primeira leitura do dia; passos '
                          'dados antes de abrir o app não entram.',
                          style: TextStyle(
                            color: painelTextoSuave,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
