import 'package:flutter/material.dart';

import '../dados/workholy_banco.dart';

enum ModoAparencia { escuro, claro, automatico }

class WorkHolyAparencia extends ChangeNotifier {
  static const String _chaveModo = 'workholy_aparencia_modo_v1';
  static const String _chaveCor = 'workholy_aparencia_cor_v1';

  ModoAparencia _modo = ModoAparencia.escuro;
  int _indiceCor = 0;
  bool _carregado = false;

  ModoAparencia get modo => _modo;
  int get indiceCor => _indiceCor;
  bool get carregado => _carregado;

  static const List<Color> cores = [
    Color(0xFFB7F34A), // Verde-limão
    Color(0xFF42A5F5), // Azul
    Color(0xFFAB7CFF), // Roxo
    Color(0xFFFF5252), // Vermelho
    Color(0xFFFFA726), // Laranja
  ];

  Color get corDestaque => cores[_indiceCor];

  Future<void> carregar() async {
    final banco = WorkHolyBanco.instancia;
    final modoSalvo = await banco.lerTexto(_chaveModo);
    final corSalva = await banco.lerInteiro(_chaveCor);

    _modo = ModoAparencia.values.firstWhere(
      (item) => item.name == modoSalvo,
      orElse: () => ModoAparencia.escuro,
    );

    if (corSalva != null && corSalva >= 0 && corSalva < cores.length) {
      _indiceCor = corSalva;
    }

    _carregado = true;
    notifyListeners();
  }

  Future<void> definirModo(ModoAparencia novoModo) async {
    if (_modo == novoModo) return;

    _modo = novoModo;
    notifyListeners();

    await WorkHolyBanco.instancia.salvarTexto(_chaveModo, novoModo.name);
  }

  Future<void> definirCor(int indice) async {
    if (indice < 0 || indice >= cores.length || indice == _indiceCor) {
      return;
    }

    _indiceCor = indice;
    notifyListeners();

    await WorkHolyBanco.instancia.salvarInteiro(_chaveCor, indice);
  }

  ThemeData criarTema(Brightness brilho) {
    final escuro = brilho == Brightness.dark;
    final destaque = corDestaque;

    final fundoTema = escuro
        ? const Color(0xFF10120F)
        : const Color(0xFFF5F6F2);

    final superficieTema = escuro ? const Color(0xFF1B1E19) : Colors.white;

    final textoPrincipal = escuro ? Colors.white : const Color(0xFF20231D);

    final borda = escuro ? Colors.white12 : const Color(0xFFDDE1D7);

    final scheme = ColorScheme.fromSeed(
      seedColor: destaque,
      brightness: brilho,
      primary: destaque,
      surface: superficieTema,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brilho,
      colorScheme: scheme,
      scaffoldBackgroundColor: fundoTema,
      cardColor: superficieTema,
      dividerColor: borda,
      appBarTheme: AppBarTheme(
        backgroundColor: fundoTema,
        foregroundColor: textoPrincipal,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: superficieTema,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borda),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: destaque, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: destaque,
          foregroundColor: escuro ? Colors.black : Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        ),
      ),
    );
  }
}
