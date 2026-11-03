import 'dart:math' as math;

import 'package:flutter/material.dart' hide Icon;

import 'w_icone.dart';

const Color painelLima = Color(0xFFC6F432);
const Color painelRoxo = Color(0xFF7C5CFF);
const Color painelFundoCartao = Color(0xFF12141A);
const Color painelBorda = Color(0xFF262A33);
const Color painelTextoSuave = Color(0xFF9AA0AB);

/// Cartão escuro com borda fina, usado em todo o painel.
class CartaoPainel extends StatelessWidget {
  const CartaoPainel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.destaque,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? destaque;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: painelFundoCartao,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: destaque?.withValues(alpha: 0.5) ?? painelBorda,
        ),
      ),
      child: child,
    );
  }
}

class TituloSecaoPainel extends StatelessWidget {
  const TituloSecaoPainel(this.titulo, {super.key, this.icone, this.trailing});

  final String titulo;
  final IconData? icone;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icone != null) ...[
          Icon(icone, size: 18, color: painelRoxo),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Anel de progresso com ícone, valor e rótulo.
class AnelProgressoPainel extends StatelessWidget {
  const AnelProgressoPainel({
    super.key,
    required this.progresso,
    required this.cor,
    required this.icone,
    required this.valor,
    required this.rotulo,
    this.detalhe,
  });

  final double progresso;
  final Color cor;
  final IconData icone;
  final String valor;
  final String rotulo;
  final String? detalhe;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 92,
          height: 92,
          child: CustomPaint(
            painter: _PintorAnel(progresso.clamp(0.0, 1.0), cor),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icone, size: 16, color: cor),
                Text(
                  valor,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (detalhe != null)
                  Text(
                    detalhe!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: painelTextoSuave,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          rotulo,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _PintorAnel extends CustomPainter {
  _PintorAnel(this.progresso, this.cor);

  final double progresso;
  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    const largura = 9.0;
    final area = (Offset.zero & size).deflate(largura / 2);
    final fundo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = largura
      ..color = cor.withValues(alpha: 0.16);
    canvas.drawArc(area, 0, math.pi * 2, false, fundo);
    if (progresso <= 0) return;
    final frente = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = largura
      ..strokeCap = StrokeCap.round
      ..color = cor;
    canvas.drawArc(area, -math.pi / 2, math.pi * 2 * progresso, false, frente);
  }

  @override
  bool shouldRepaint(_PintorAnel antigo) =>
      antigo.progresso != progresso || antigo.cor != cor;
}

/// Métrica compacta (valor grande e rótulo) para resumos.
class MetricaPainel extends StatelessWidget {
  const MetricaPainel({
    super.key,
    required this.valor,
    required this.unidade,
    required this.rotulo,
    this.icone,
    this.cor = painelLima,
  });

  final String valor;
  final String unidade;
  final String rotulo;
  final IconData? icone;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: painelBorda),
      ),
      child: Column(
        children: [
          if (icone != null) Icon(icone, size: 16, color: cor),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                text: valor,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
                children: [
                  if (unidade.isNotEmpty)
                    TextSpan(
                      text: ' $unidade',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: painelTextoSuave,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            rotulo,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: painelTextoSuave),
          ),
        ],
      ),
    );
  }
}

/// Barras verticais por período, com o atual em destaque.
class BarrasSemanaPainel extends StatelessWidget {
  const BarrasSemanaPainel({
    super.key,
    required this.rotulos,
    required this.valores,
    this.indiceAtual,
    this.altura = 120,
  });

  final List<String> rotulos;
  final List<num> valores;
  final int? indiceAtual;
  final double altura;

  @override
  Widget build(BuildContext context) {
    final maximo = valores.fold<num>(0, (a, b) => b > a ? b : a);
    return SizedBox(
      height: altura + 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < valores.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    valores[i] > 0 ? _formatar(valores[i]) : '',
                    style: const TextStyle(
                      fontSize: 10,
                      color: painelTextoSuave,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 12,
                    height: maximo == 0
                        ? 4
                        : math.max(4, altura * (valores[i] / maximo)),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: i == indiceAtual ? painelLima : painelRoxo,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    rotulos[i],
                    style: TextStyle(
                      fontSize: 11,
                      color: i == indiceAtual ? painelLima : painelTextoSuave,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _formatar(num v) => v == v.roundToDouble()
      ? v.toInt().toString()
      : v.toStringAsFixed(1).replaceAll('.', ',');
}

/// Selo circular de conquista.
class SeloConquistaPainel extends StatelessWidget {
  const SeloConquistaPainel({
    super.key,
    required this.valor,
    required this.titulo,
    required this.descricao,
    required this.cor,
    this.ativo = true,
  });

  final String valor;
  final String titulo;
  final String descricao;
  final Color cor;
  final bool ativo;

  @override
  Widget build(BuildContext context) {
    final c = ativo ? cor : painelTextoSuave;
    return CartaoPainel(
      destaque: ativo ? cor : null,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.withValues(alpha: 0.12),
              border: Border.all(color: c, width: 2),
            ),
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: c,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            descricao,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: painelTextoSuave),
          ),
        ],
      ),
    );
  }
}
