enum ComandoVoz { pausar, retomar, proximo, serieConcluida, finalizar, repetir }

/// Converte o texto reconhecido em um comando. Só aceita frases claras;
/// o que não for reconhecido devolve null e nada é executado.
ComandoVoz? interpretarComandoVoz(String texto) {
  final t = _normalizar(texto);
  if (t.isEmpty) return null;

  bool tem(List<String> termos) => termos.any(t.contains);

  if (tem([
    'serie concluida',
    'serie feita',
    'terminei a serie',
    'conclui a serie',
    'fiz a serie',
    'concluir serie',
  ])) {
    return ComandoVoz.serieConcluida;
  }
  if (tem([
    'finalizar',
    'encerrar',
    'terminar treino',
    'terminar corrida',
    'parar tudo',
  ])) {
    return ComandoVoz.finalizar;
  }
  if (tem(['retomar', 'continuar', 'voltar a correr', 'seguir'])) {
    return ComandoVoz.retomar;
  }
  if (tem(['pausar', 'pausa', 'pause', 'pare'])) {
    return ComandoVoz.pausar;
  }
  if (tem(['proximo', 'proxima', 'pular descanso', 'pular'])) {
    return ComandoVoz.proximo;
  }
  if (tem(['repetir', 'repita', 'de novo', 'o que falta'])) {
    return ComandoVoz.repetir;
  }
  return null;
}

String _normalizar(String texto) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const para = 'aaaaaeeeeiiiiooooouuuuc';
  final sb = StringBuffer();
  for (final r in texto.toLowerCase().runes) {
    final c = String.fromCharCode(r);
    final i = de.indexOf(c);
    sb.write(i >= 0 ? para[i] : c);
  }
  return sb
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
