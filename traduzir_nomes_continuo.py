import json
import os
import time
import http.client
import urllib.parse
from pathlib import Path

HOST = "free-google-translator.p.rapidapi.com"
CATALOGO = Path("assets/exercicios/free_exercise_db.json")
TRADUCOES = Path("assets/exercicios/traducoes_pt_BR.json")

# Limite máximo de novas traduções nesta execução.
# Ajuste esse número se quiser processar menos exercícios.
MAX_CHAMADAS = 796

# Pausa entre requisições para evitar excesso de chamadas.
INTERVALO_SEGUNDOS = 1.2

CHAVE = os.environ.get("RAPIDAPI_KEY")


def carregar_json(caminho):
    with caminho.open("r", encoding="utf-8-sig") as arquivo:
        return json.load(arquivo)


def salvar_json_seguro(caminho, dados):
    temporario = caminho.with_suffix(".json.tmp")

    with temporario.open("w", encoding="utf-8", newline="\n") as arquivo:
        json.dump(dados, arquivo, ensure_ascii=False, indent=2)
        arquivo.write("\n")

    temporario.replace(caminho)


def traduzir(texto):
    parametros = urllib.parse.urlencode({
        "from": "en",
        "to": "pt",
        "query": texto
    })

    caminho = f"/external-api/free-google-translator?{parametros}"

    corpo = json.dumps(
        {"translate": texto},
        ensure_ascii=False
    ).encode("utf-8")

    cabecalhos = {
        "x-rapidapi-key": CHAVE,
        "x-rapidapi-host": HOST,
        "Content-Type": "application/json"
    }

    conn = http.client.HTTPSConnection(HOST, timeout=30)

    try:
        conn.request("POST", caminho, corpo, cabecalhos)
        resposta = conn.getresponse()
        conteudo = resposta.read().decode("utf-8", errors="replace")

        if resposta.status == 429:
            raise RuntimeError(
                "Limite de requisições atingido (HTTP 429)."
            )

        if resposta.status != 200:
            raise RuntimeError(
                f"API retornou HTTP {resposta.status}: {conteudo[:250]}"
            )

        resultado = json.loads(conteudo)
        traducao = resultado.get("translation")

        if resultado.get("status") != 200:
            raise RuntimeError("A API informou falha na tradução.")

        if not isinstance(traducao, str) or not traducao.strip():
            raise RuntimeError("A API retornou uma tradução vazia.")

        return traducao.strip()

    finally:
        conn.close()


def main():
    if not CHAVE:
        raise SystemExit(
            "ERRO: configure RAPIDAPI_KEY nesta sessão do PowerShell."
        )

    catalogo = carregar_json(CATALOGO)
    dados = carregar_json(TRADUCOES)
    exercicios = dados.setdefault("exercicios", {})

    pendentes = [
        item for item in catalogo
        if not (
            isinstance(exercicios.get(str(item.get("id", ""))), dict)
            and isinstance(
                exercicios[str(item.get("id", ""))].get("nome"), str
            )
            and exercicios[str(item.get("id", ""))]["nome"].strip()
        )
    ]

    limite = min(MAX_CHAMADAS, len(pendentes))

    print("=" * 60)
    print("WORKHOLYMOBILE - TRADUÇÃO CONTÍNUA DE NOMES")
    print("=" * 60)
    print(f"Total de exercícios: {len(catalogo)}")
    print(f"Nomes já preenchidos: {len(catalogo) - len(pendentes)}")
    print(f"Nomes pendentes: {len(pendentes)}")
    print(f"Máximo de chamadas nesta execução: {limite}")
    print(f"Pausa entre chamadas: {INTERVALO_SEGUNDOS}s")
    print()
    print("O catálogo original não será modificado.")
    print("Traduções automáticas ficarão pendentes de revisão.")
    print()

    if limite == 0:
        print("Não há nomes pendentes.")
        return

    confirmacao = input(
        f"Digite SIM para iniciar até {limite} traduções: "
    ).strip()

    if confirmacao.upper() != "SIM":
        print("Operação cancelada. Nenhuma chamada foi feita.")
        return

    concluidos = 0
    falhas = 0
    interrompido = False

    try:
        for indice, item in enumerate(pendentes[:limite], start=1):
            identificador = str(item.get("id", "")).strip()
            original = str(item.get("name", "")).strip()

            if not identificador or not original:
                print(f"[IGNORADO] Registro sem ID ou nome válido: {item}")
                falhas += 1
                continue

            print(f"\n[{indice}/{limite}] {identificador}")

            try:
                nome_pt = traduzir(original)

                registro = exercicios.setdefault(identificador, {})
                registro["nome"] = nome_pt
                registro["status_nome"] = (
                    "automatico_pendente_revisao"
                )

                salvar_json_seguro(TRADUCOES, dados)

                concluidos += 1
                print(f"[OK] {original} -> {nome_pt}")

                if indice < limite:
                    time.sleep(INTERVALO_SEGUNDOS)

            except KeyboardInterrupt:
                interrompido = True
                print("\nInterrupção solicitada. Progresso salvo preservado.")
                break

            except Exception as erro:
                falhas += 1
                print(f"[ERRO] {erro}")

                if "HTTP 429" in str(erro):
                    print("Limite atingido; encerrando para evitar novas chamadas.")
                    break

                print("Execução encerrada para preservar o controle.")
                print("Execute novamente para retomar os nomes pendentes.")
                break

    except KeyboardInterrupt:
        interrompido = True
        print("\nInterrupção solicitada pelo usuário.")

    restantes = sum(
        1 for item in catalogo
        if not (
            isinstance(exercicios.get(str(item.get("id", ""))), dict)
            and isinstance(
                exercicios[str(item.get("id", ""))].get("nome"), str
            )
            and exercicios[str(item.get("id", ""))]["nome"].strip()
        )
    )

    print("\n" + "=" * 60)
    print("RELATÓRIO FINAL")
    print("=" * 60)
    print(f"Novas traduções salvas: {concluidos}")
    print(f"Falhas/ignorados: {falhas}")
    print(f"Nomes ainda pendentes: {restantes}")
    print(f"Interrompido pelo usuário: {'Sim' if interrompido else 'Não'}")
    print(f"Arquivo: {TRADUCOES}")
    print("=" * 60)


if __name__ == "__main__":
    main()
