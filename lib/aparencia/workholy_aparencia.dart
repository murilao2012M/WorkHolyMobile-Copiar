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
    Color(0xFFC6F432), // Verde-limão
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
        ? const Color(0xFF0A0B10)
        : const Color(0xFFF5F6F2);

    final superficieTema = escuro ? const Color(0xFF12141A) : Colors.white;

    final textoPrincipal = escuro ? Colors.white : const Color(0xFF20231D);

    final borda = escuro ? const Color(0xFF262A33) : const Color(0xFFDDE1D7);

    final scheme = ColorScheme.fromSeed(
      seedColor: destaque,
      brightness: brilho,
      surface: superficieTema,
      contrastLevel: 0.25,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brilho,
      colorScheme: scheme,
      scaffoldBackgroundColor: fundoTema,
      cardColor: superficieTema,
      dividerColor: borda,
      textTheme: Typography.material2021(platform: TargetPlatform.android).black
          .apply(bodyColor: textoPrincipal, displayColor: textoPrincipal),
      appBarTheme: AppBarTheme(
        backgroundColor: fundoTema,
        foregroundColor: textoPrincipal,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: textoPrincipal,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: superficieTema,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borda),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(color: borda, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: superficieTema,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
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
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
        ),
      ),
    );
  }
}
