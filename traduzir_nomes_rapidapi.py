import json
import os
import time
import http.client
import urllib.parse
from pathlib import Path

HOST = "free-google-translator.p.rapidapi.com"
CATALOGO = Path("assets/exercicios/free_exercise_db.json")
TRADUCOES = Path("assets/exercicios/traducoes_pt_BR.json")

LIMITE_LOTE = 25
INTERVALO = 1.0
CHAVE = os.environ.get("RAPIDAPI_KEY")

def salvar(dados):
    temporario = TRADUCOES.with_suffix(".json.tmp")
    with temporario.open("w", encoding="utf-8", newline="\n") as f:
        json.dump(dados, f, ensure_ascii=False, indent=2)
        f.write("\n")
    temporario.replace(TRADUCOES)

def traduzir(conn, texto):
    parametros = urllib.parse.urlencode({
        "from": "en",
        "to": "pt",
        "query": texto
    })

    caminho = f"/external-api/free-google-translator?{parametros}"
    corpo = json.dumps({"translate": texto}, ensure_ascii=False)

    headers = {
        "x-rapidapi-key": CHAVE,
        "x-rapidapi-host": HOST,
        "Content-Type": "application/json"
    }

    conn.request("POST", caminho, corpo.encode("utf-8"), headers)
    resposta = conn.getresponse()
    conteudo = resposta.read().decode("utf-8", errors="replace")

    if resposta.status != 200:
        raise RuntimeError(f"HTTP {resposta.status}: {conteudo[:300]}")

    resultado = json.loads(conteudo)
    traducao = resultado.get("translation")

    if resultado.get("status") != 200 or not isinstance(traducao, str):
        raise RuntimeError(f"Resposta inesperada da API: {conteudo[:300]}")

    traducao = traducao.strip()
    if not traducao:
        raise RuntimeError("A API retornou uma tradução vazia.")

    return traducao

def main():
    if not CHAVE:
        raise SystemExit(
            "Configure primeiro $env:RAPIDAPI_KEY no PowerShell."
        )

    with CATALOGO.open("r", encoding="utf-8-sig") as f:
        catalogo = json.load(f)

    with TRADUCOES.open("r", encoding="utf-8-sig") as f:
        dados = json.load(f)

    exercicios = dados.setdefault("exercicios", {})

    pendentes = [
        item for item in catalogo
        if not (
            isinstance(exercicios.get(str(item["id"])), dict)
            and exercicios[str(item["id"])].get("nome")
        )
    ]

    print(f"Total de exercícios: {len(catalogo)}")
    print(f"Nomes já preenchidos: {len(catalogo) - len(pendentes)}")
    print(f"Nomes pendentes: {len(pendentes)}")
    print(f"Limite deste lote: {LIMITE_LOTE}")

    if not pendentes:
        print("Todos os exercícios já possuem nome no arquivo de traduções.")
        return

    concluidos = 0
    conn = http.client.HTTPSConnection(HOST, timeout=30)

    try:
        for item in pendentes[:LIMITE_LOTE]:
            identificador = str(item["id"])
            original = str(item.get("name", "")).strip()

            if not original:
                print(f"[IGNORADO] {identificador}: nome original vazio")
                continue

            try:
                nome_pt = traduzir(conn, original)

                exercicios[identificador] = {
                    "nome": nome_pt,
                    "status_nome": "automatico_pendente_revisao"
                }

                salvar(dados)
                concluidos += 1
                print(f"[OK] {identificador}: {nome_pt}")

                time.sleep(INTERVALO)

            except Exception as erro:
                print(f"[ERRO] {identificador}: {erro}")
                print("Lote interrompido. O progresso salvo foi preservado.")
                break
    finally:
        conn.close()

    restantes = sum(
        1 for item in catalogo
        if not (
            isinstance(exercicios.get(str(item["id"])), dict)
            and exercicios[str(item["id"])].get("nome")
        )
    )

    print(f"\nNovas traduções neste lote: {concluidos}")
    print(f"Nomes ainda pendentes: {restantes}")
    print(f"Arquivo salvo: {TRADUCOES}")

if __name__ == "__main__":
    main()
