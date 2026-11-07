import 'package:flutter/foundation.dart';

import '../dados/workholy_banco.dart';

enum UnidadeCarga { kg, lb }

class PreferenciaUnidadeCarga extends ChangeNotifier {
  PreferenciaUnidadeCarga._();

  static final PreferenciaUnidadeCarga instancia = PreferenciaUnidadeCarga._();
  static const String _chave = 'workholy_unidade_carga_v1';
  static const double _librasPorQuilograma = 2.2046226218;

  UnidadeCarga _unidade = UnidadeCarga.kg;

  UnidadeCarga get unidade => _unidade;
  String get rotulo => _unidade == UnidadeCarga.kg ? 'kg' : 'lb';

  Future<void> carregar() async {
    final salva = await WorkHolyBanco.instancia.lerTexto(_chave);
    _unidade = salva == 'lb' ? UnidadeCarga.lb : UnidadeCarga.kg;
    notifyListeners();
  }

  Future<void> definir(UnidadeCarga unidade) async {
    await WorkHolyBanco.instancia.salvarTexto(
      _chave,
      unidade == UnidadeCarga.kg ? 'kg' : 'lb',
    );
    _unidade = unidade;
    notifyListeners();
  }

  double deKg(double quilogramas) {
    return _unidade == UnidadeCarga.kg
        ? quilogramas
        : quilogramas * _librasPorQuilograma;
  }

  double paraKg(double valor) {
    return _unidade == UnidadeCarga.kg ? valor : valor / _librasPorQuilograma;
  }

  String formatar(double quilogramas, {bool pesoCorporal = false}) {
    if (quilogramas == 0) {
      return pesoCorporal ? 'Peso corporal' : 'Carga não informada';
    }

    final valor = deKg(quilogramas);
    final texto = valor.toStringAsFixed(valor % 1 == 0 ? 0 : 1);
    return '$texto $rotulo';
  }
}
