import 'package:flutter/material.dart';

class EsforcoWorkFit {
  const EsforcoWorkFit({this.rpe, this.rir});

  final int? rpe;
  final int? rir;
}

class WorkFitEsforcoDialog extends StatefulWidget {
  const WorkFitEsforcoDialog({
    super.key,
    this.permiteRir = true,
    this.rpeInicial,
  });
  final bool permiteRir;
  final int? rpeInicial;

  @override
  State<WorkFitEsforcoDialog> createState() => _WorkFitEsforcoDialogState();
}

class _WorkFitEsforcoDialogState extends State<WorkFitEsforcoDialog> {
  int? rpe;
  int? rir;

  @override
  void initState() {
    super.initState();
    rpe = widget.rpeInicial;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Como foi o esforço?'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Opcional: registre uma percepção geral da sessão. '
            'RPE vai de 1 (leve) a 10 (máximo).'
            '${widget.permiteRir ? ' RIR é quantas repetições você acredita que ainda conseguiria realizar.' : ''}',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: rpe,
            decoration: const InputDecoration(labelText: 'RPE da sessão'),
            items: [
              for (var valor = 1; valor <= 10; valor++)
                DropdownMenuItem(value: valor, child: Text('$valor')),
            ],
            onChanged: (valor) => setState(() => rpe = valor),
          ),
          if (widget.permiteRir)
            DropdownButtonFormField<int>(
              initialValue: rir,
              decoration: const InputDecoration(labelText: 'RIR da sessão'),
              items: [
                for (var valor = 0; valor <= 10; valor++)
                  DropdownMenuItem(value: valor, child: Text('$valor')),
              ],
              onChanged: (valor) => setState(() => rir = valor),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Pular'),
      ),
      FilledButton(
        onPressed: () =>
            Navigator.pop(context, EsforcoWorkFit(rpe: rpe, rir: rir)),
        child: const Text('Concluir'),
      ),
    ],
  );
}
