import 'package:flutter/material.dart';

import 'workfit_ciclo.dart';

class SelecaoCicloCorrida {
  const SelecaoCicloCorrida(this.planoId);
  final String? planoId;
}

class SelecaoCicloCorridaDialog extends StatelessWidget {
  const SelecaoCicloCorridaDialog({super.key, required this.ciclos});
  final List<WorkFitCiclo> ciclos;

  String _rotulo(WorkFitCiclo ciclo) {
    final inicio = ciclo.inicio.toLocal();
    final codigo = ciclo.id.length <= 6
        ? ciclo.id
        : ciclo.id.substring(ciclo.id.length - 6);
    return 'Ciclo ${inicio.day.toString().padLeft(2, '0')}/'
        '${inicio.month.toString().padLeft(2, '0')}/${inicio.year} '
        '${inicio.hour.toString().padLeft(2, '0')}:'
        '${inicio.minute.toString().padLeft(2, '0')} • '
        '${ciclo.diasPorSemana} dias/semana • $codigo';
  }

  @override
  Widget build(BuildContext context) => SimpleDialog(
    title: const Text('Vincular corrida a um ciclo?'),
    children: [
      for (final ciclo in ciclos)
        SimpleDialogOption(
          onPressed: () =>
              Navigator.pop(context, SelecaoCicloCorrida(ciclo.id)),
          child: Text(_rotulo(ciclo)),
        ),
      SimpleDialogOption(
        onPressed: () =>
            Navigator.pop(context, const SelecaoCicloCorrida(null)),
        child: const Text('Corrida avulsa, sem vínculo'),
      ),
      SimpleDialogOption(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
    ],
  );
}
