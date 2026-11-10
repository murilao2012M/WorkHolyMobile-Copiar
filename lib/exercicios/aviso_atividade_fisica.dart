import 'package:flutter/material.dart';

const textoAvisoAtividadeFisica =
    'Antes de realizar exercícios físicos, é importante procurar um médico '
    'para avaliar sua saúde.\n\n'
    'O WorkHoly é um aplicativo feito para amantes do exercício físico e '
    'não substitui o acompanhamento de um profissional de educação física '
    'qualificado e registrado no conselho profissional (CREF).';

Future<bool> mostrarAvisoAtividadeFisica(BuildContext context) async {
  final continuar = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Aviso importante'),
      content: const SingleChildScrollView(
        child: Text(textoAvisoAtividadeFisica),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Voltar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );
  return continuar == true;
}
