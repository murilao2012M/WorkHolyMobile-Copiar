/// Regras de validação dos dados pessoais coletados no primeiro acesso.
class PerfilOnboarding {
  const PerfilOnboarding._();

  static const List<String> objetivos = [
    'Hipertrofia',
    'Emagrecimento',
    'Força',
    'Condicionamento físico',
    'Saúde e bem-estar',
  ];

  static const List<String> experiencias = [
    'Iniciante',
    'Intermediário',
    'Avançado',
  ];

  static double? lerNumero(String? valor) =>
      double.tryParse((valor ?? '').trim().replaceAll(',', '.'));

  static String? validarNome(String? valor) {
    final nome = (valor ?? '').trim();
    if (nome.length < 2) return 'Informe seu nome.';
    return null;
  }

  static String? validarPeso(String? valor) {
    final peso = lerNumero(valor);
    if (peso == null) return 'Informe seu peso em kg.';
    if (peso < 20 || peso > 400) return 'Informe um peso entre 20 e 400 kg.';
    return null;
  }

  static String? validarAltura(String? valor) {
    final altura = lerNumero(valor);
    if (altura == null) return 'Informe sua altura em cm.';
    if (altura < 100 || altura > 250) {
      return 'Informe uma altura entre 100 e 250 cm.';
    }
    return null;
  }

  static String? validarNascimento(DateTime? nascimento, {DateTime? agora}) {
    if (nascimento == null) return 'Informe sua data de nascimento.';
    final idade = idadeEm(nascimento, agora ?? DateTime.now());
    if (idade < 10 || idade > 100) {
      return 'Informe uma data de nascimento válida.';
    }
    return null;
  }

  static int idadeEm(DateTime nascimento, DateTime agora) {
    var idade = agora.year - nascimento.year;
    final fezAniversario =
        agora.month > nascimento.month ||
        (agora.month == nascimento.month && agora.day >= nascimento.day);
    if (!fezAniversario) idade--;
    return idade;
  }

  /// Indica se o perfil salvo tem todos os dados exigidos no primeiro acesso.
  static bool perfilCompleto(Map<String, dynamic>? perfil, {DateTime? agora}) {
    if (perfil == null) return false;
    final objetivo = perfil['objetivo']?.toString().trim() ?? '';
    return validarNome(perfil['nome']?.toString()) == null &&
        validarPeso(perfil['peso']?.toString()) == null &&
        validarAltura(perfil['altura']?.toString()) == null &&
        validarNascimento(
              DateTime.tryParse(perfil['nascimento']?.toString() ?? ''),
              agora: agora,
            ) ==
            null &&
        objetivo.isNotEmpty;
  }
}
