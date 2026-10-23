import json
import time
import html
from pathlib import Path

import requests

BASE = Path(__file__).resolve().parent
CATALOGO = BASE / "assets" / "exercicios" / "free_exercise_db.json"
TRADUCOES = BASE / "assets" / "exercicios" / "traducoes_pt_BR.json"

MAX_POR_EXECUCAO = 25
INTERVALO_SEGUNDOS = 1.5

def carregar_json(caminho):
    with caminho.open("r", encoding="utf-8-sig") as arquivo:
        return json.load(arquivo)

def salvar_json(caminho, dados):
    temporario = caminho.with_suffix(caminho.suffix + ".tmp")
    with temporario.open("w", encoding="utf-8", newline="\n") as arquivo:
        json.dump(dados, arquivo, ensure_ascii=False, indent=2)
        arquivo.write("\n")
    temporario.replace(caminho)

def traduzir(texto, sessao):
    resposta = sessao.get(
        "https://api.mymemory.translated.net/get",
        params={"q": texto, "langpair": "en|pt-BR"},
        timeout=25,
    )
    resposta.raise_for_status()
    dados = resposta.json()

    if dados.get("responseStatus") != 200:
        raise RuntimeError(
            f"API recusou a tradução: {dados.get('responseDetails', dados)}"
        )

    resultado = dados.get("responseData", {}).get("translatedText")
    if not resultado:
        raise RuntimeError("A API retornou uma tradução vazia.")

    return html.unescape(resultado).strip()

def main():
    if not CATALOGO.exists():
        raise FileNotFoundError(f"Catálogo não encontrado: {CATALOGO}")
    if not TRADUCOES.exists():
        raise FileNotFoundError(
            f"Arquivo de traduções não encontrado: {TRADUCOES}"
        )

    catalogo = carregar_json(CATALOGO)
    traducoes = carregar_json(TRADUCOES)

    if not isinstance(catalogo, list):
        raise ValueError("O catálogo precisa ser uma lista JSON.")

    exercicios_traduzidos = traducoes.setdefault("exercicios", {})
    pendentes = []

    for exercicio in catalogo:
        identificador = str(exercicio.get("id", "")).strip()
        nome_original = str(exercicio.get("name", "")).strip()

        if not identificador or not nome_original:
            continue

        atual = exercicios_traduzidos.get(identificador)

        # Preserva traduções que já existem.
        if isinstance(atual, dict) and str(atual.get("nome", "")).strip():
            continue
        if isinstance(atual, str) and atual.strip():
            continue

        pendentes.append((identificador, nome_original))

    if not pendentes:
        print("Todos os nomes já possuem tradução.")
        return

    lote = pendentes[:MAX_POR_EXECUCAO]
    cache = {}
    sessao = requests.Session()
    concluidos = 0

    print(f"Exercícios no catálogo: {len(catalogo)}")
    print(f"Nomes ainda pendentes: {len(pendentes)}")
    print(f"Máximo nesta execução: {len(lote)}")
    print("As traduções serão salvas a cada sucesso.\n")

    for indice, (identificador, original) in enumerate(lote, start=1):
        try:
            if original not in cache:
                cache[original] = traduzir(original, sessao)
                time.sleep(INTERVALO_SEGUNDOS)

            traduzido = cache[original]

            atual = exercicios_traduzidos.get(identificador)
            if isinstance(atual, dict):
                atual["nome"] = traduzido
            else:
                exercicios_traduzidos[identificador] = {
                    "nome": traduzido
                }

            salvar_json(TRADUCOES, traducoes)
            concluidos += 1
            print(
                f"[{indice}/{len(lote)}] {identificador}\n"
                f"  EN: {original}\n"
                f"  PT: {traduzido}\n"
            )

        except KeyboardInterrupt:
            salvar_json(TRADUCOES, traducoes)
            print("\nInterrompido. O progresso já salvo foi preservado.")
            return

        except Exception as erro:
            salvar_json(TRADUCOES, traducoes)
            print(f"\nFalha em {identificador}: {erro}")
            print("Execução interrompida para evitar novas solicitações.")
            print("Execute novamente mais tarde para continuar.")
            return

    restantes = len(pendentes) - concluidos
    print("=" * 55)
    print(f"Nomes traduzidos nesta execução: {concluidos}")
    print(f"Nomes que ainda estavam pendentes: {restantes}")
    print(f"Arquivo atualizado: {TRADUCOES}")
    if restantes:
        print("Execute novamente o mesmo comando para continuar.")
    else:
        print("Todos os nomes pendentes foram processados.")

if __name__ == "__main__":
    main()
