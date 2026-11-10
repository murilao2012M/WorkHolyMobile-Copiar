String? primeiroNome(String? nome) {
  final texto = nome?.trim() ?? '';
  if (texto.isEmpty) return null;
  return texto.split(RegExp(r'\s+')).first;
}
