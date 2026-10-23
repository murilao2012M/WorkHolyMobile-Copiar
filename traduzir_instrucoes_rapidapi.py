
import csv
import http.client
import json
import logging
import os
import re
import time
import urllib.parse
from datetime import datetime
from pathlib import Path

HOST = "free-google-translator.p.rapidapi.com"
CATALOGO = Path("assets/exercicios/free_exercise_db.json")
TRADUCOES = Path("assets/exercicios/traducoes_pt_BR.json")

PASTA_LOGS = Path("logs")
ARQUIVO_LOG = PASTA_LOGS / "traduzir_instrucoes.log"
ARQUIVO_FALHAS = PASTA_LOGS / "falhas_instrucoes.csv"

MAX_CHAMADAS = 871
INTERVALO_SEGUNDOS = 1.2
RESERVA_COTA = 100

CHAVE = os.environ.get("RAPIDAPI_KEY")


class ErroValidacaoTraducao(Exception):
    """A resposta foi recebida, mas não passou na validação."""


def configurar_logs():
    PASTA_LOGS.mkdir(parents=True, exist_ok=True)

    logging.basicConfig(
        filename=str(ARQUIVO_LOG),
        level=logging.INFO,
        encoding="utf-8",
        format="%(asctime)s | %(levelname)s | %(message)s",
    )

    if not ARQUIVO_FALHAS.exists():
        with ARQUIVO_FALHAS.open(
            "w", newline="", encoding="utf-8-sig"
        ) as arquivo:
            escritor = csv.writer(arquivo)
            escritor.writerow([
                "data_hora",
                "id_exercicio",
                "nome_original",
                "motivo",
            ])


def registrar_falha(identificador, nome, erro):
    mensagem = str(erro).replace("\n", " ").strip()

    logging.error(
        "Falha no exercício %s (%s): %s",
        identificador,
        nome,
        mensagem,
    )

    with ARQUIVO_FALHAS.open(
        "a", newline="", encoding="utf-8-sig"
    ) as arquivo:
        escritor = csv.writer(arquivo)
        escritor.writerow([
            datetime.now().isoformat(timespec="seconds"),
            identificador,
            nome,
            mensagem,
        ])


def carregar_json(caminho):
    with caminho.open("r", encoding="utf-8-sig") as arquivo:
        return json.load(arquivo)


def salvar_json_seguro(caminho, dados):
    temporario = caminho.with_suffix(".json.tmp")

    with temporario.open(
        "w", encoding="utf-8", newline="\n"
    ) as arquivo:
        json.dump(dados, arquivo, ensure_ascii=False, indent=2)
        arquivo.write("\n")
        arquivo.flush()
        os.fsync(arquivo.fileno())

    temporario.replace(caminho)


def traduzir(texto):
    parametros = urllib.parse.urlencode({
        "from": "en",
        "to": "pt",
        "query": texto,
    })

    caminho = (
        "/external-api/free-google-translator?"
        + parametros
    )

    corpo = json.dumps(
        {"translate": texto},
        ensure_ascii=False,
    ).encode("utf-8")

    conn = http.client.HTTPSConnection(HOST, timeout=60)

    try:
        conn.request(
            "POST",
            caminho,
            corpo,
            {
                "x-rapidapi-key": CHAVE,
                "x-rapidapi-host": HOST,
                "Content-Type": "application/json",
            },
        )

        resposta = conn.getresponse()
        conteudo = resposta.read().decode(
            "utf-8", errors="replace"
        )
        restante = resposta.getheader(
            "x-ratelimit-requests-remaining"
        )

        if resposta.status == 429:
            raise RuntimeError(
                "HTTP 429: limite de requisições atingido."
            )

        if resposta.status != 200:
            raise RuntimeError(
                f"HTTP {resposta.status}: {conteudo[:300]}"
            )

        try:
            resultado = json.loads(conteudo)
        except json.JSONDecodeError as erro:
            raise RuntimeError(
                "A API retornou uma resposta que não é JSON válido."
            ) from erro

        if resultado.get("status") != 200:
            raise RuntimeError(
                "A API informou falha na tradução."
            )

        traducao = resultado.get("translation")

        if not isinstance(traducao, str) or not traducao.strip():
            raise RuntimeError(
                "A API retornou uma tradução vazia."
            )

        return traducao.strip(), restante

    finally:
        conn.close()


def traduzir_lista(instrucoes):
    blocos = []

    for indice, instrucao in enumerate(instrucoes, start=1):
        marcador = f"ZZZSTEP{indice:04d}ZZZ"
        blocos.append(f"{marcador}\n{instrucao}")

    texto = "\n\n".join(blocos)
    traducao, restante = traduzir(texto)

    padrao = re.compile(
        r"ZZZSTEP(\d{4})ZZZ",
        re.IGNORECASE,
    )
    encontrados = list(padrao.finditer(traducao))

    esperados = [
        f"{i:04d}"
        for i in range(1, len(instrucoes) + 1)
    ]
    recebidos = [m.group(1) for m in encontrados]

    if recebidos != esperados:
        raise ErroValidacaoTraducao(
            "Marcadores alterados ou removidos pelo tradutor. "
            f"Esperados: {len(esperados)}; "
            f"recebidos: {len(recebidos)}."
        )

    resultado = []

    for indice, marcador in enumerate(encontrados):
        inicio = marcador.end()
        fim = (
            encontrados[indice + 1].start()
            if indice + 1 < len(encontrados)
            else len(traducao)
        )

        texto_pt = traducao[inicio:fim].strip()

        if not texto_pt:
            raise ErroValidacaoTraducao(
                f"A tradução do passo {indice + 1} ficou vazia."
            )

        resultado.append(texto_pt)

    return resultado, restante


def tem_instrucao_traduzida(registro):
    instrucoes = registro.get("instrucoes")

    return (
        isinstance(instrucoes, list)
        and len(instrucoes) > 0
        and all(
            isinstance(item, str) and item.strip()
            for item in instrucoes
        )
    )


def contar_pendentes(catalogo, exercicios_pt):
    total = 0

    for item in catalogo:
        identificador = str(item.get("id", "")).strip()
        instrucoes = item.get("instructions", [])

        if not isinstance(instrucoes, list):
            continue

        possui_texto = any(
            str(instrucao).strip()
            for instrucao in instrucoes
            if instrucao is not None
        )

        if not identificador or not possui_texto:
            continue

        registro = exercicios_pt.get(identificador, {})

        if (
            not isinstance(registro, dict)
            or not tem_instrucao_traduzida(registro)
        ):
            total += 1

    return total


def main():
    configurar_logs()

    if not CHAVE:
        raise SystemExit(
            "ERRO: RAPIDAPI_KEY não está configurada nesta sessão."
        )

    catalogo = carregar_json(CATALOGO)
    dados = carregar_json(TRADUCOES)

    if not isinstance(dados, dict):
        raise SystemExit("ERRO: formato inesperado no JSON de traduções.")

    exercicios_pt = dados.setdefault("exercicios", {})

    pendentes = []

    for item in catalogo:
        identificador = str(item.get("id", "")).strip()
        instrucoes = item.get("instructions", [])

        if not identificador or not isinstance(instrucoes, list):
            continue

        instrucoes = [
            str(instrucao).strip()
            for instrucao in instrucoes
            if instrucao is not None and str(instrucao).strip()
        ]

        if not instrucoes:
            continue

        registro = exercicios_pt.get(identificador, {})

        if not isinstance(registro, dict):
            registro = {}
            exercicios_pt[identificador] = registro

        if not tem_instrucao_traduzida(registro):
            pendentes.append((item, instrucoes))

    limite = min(MAX_CHAMADAS, len(pendentes))

    print("=" * 60)
    print("WORKHOLYMOBILE - TRADUÇÃO COM LOG E RETOMADA")
    print("=" * 60)
    print(f"Exercícios no catálogo: {len(catalogo)}")
    print(f"Exercícios pendentes: {len(pendentes)}")
    print(f"Máximo de chamadas nesta execução: {limite}")
    print(f"Reserva desejada de cota: {RESERVA_COTA}")
    print(f"Log: {ARQUIVO_LOG}")
    print(f"Relatório de falhas: {ARQUIVO_FALHAS}")
    print()

    if limite == 0:
        print("Não há instruções pendentes.")
        return

    if input("Digite SIM para iniciar: ").strip().upper() != "SIM":
        print("Operação cancelada.")
        return

    concluidos = 0
    falhas = 0
    restante_cota = None
    parar = False

    try:
        for indice, (item, instrucoes) in enumerate(
            pendentes[:limite], start=1
        ):
            identificador = str(item["id"])
            nome = str(item.get("name", identificador))

            # Se a última resposta já indicou a reserva, não faça outra chamada.
            if restante_cota is not None:
                try:
                    cota_conhecida = int(restante_cota)
                except (TypeError, ValueError):
                    cota_conhecida = None

                if (
                    cota_conhecida is not None
                    and cota_conhecida <= RESERVA_COTA
                ):
                    print(
                        f"[PARADA] Cota conhecida: {cota_conhecida}. "
                        "Reserva atingida antes da próxima chamada."
                    )
                    break

            print(
                f"\n[{indice}/{limite}] {identificador} — {nome} "
                f"({len(instrucoes)} passos)"
            )

            try:
                traducoes, restante_resposta = traduzir_lista(instrucoes)

                # Salva a tradução válida antes de avaliar a reserva.
                registro = exercicios_pt.setdefault(
                    identificador, {}
                )
                registro["instrucoes"] = traducoes
                registro["status_instrucoes"] = (
                    "automatico_pendente_revisao"
                )

                salvar_json_seguro(TRADUCOES, dados)
                concluidos += 1
                restante_cota = restante_resposta

                logging.info(
                    "Salvo: %s (%s), %s passos.",
                    identificador,
                    nome,
                    len(traducoes),
                )
                print(
                    f"[OK] {len(traducoes)} passos traduzidos e salvos."
                )

                if restante_cota is not None:
                    print(f"Cota restante informada: {restante_cota}")

                    try:
                        cota_num = int(restante_cota)
                    except (TypeError, ValueError):
                        cota_num = None

                    if (
                        cota_num is not None
                        and cota_num <= RESERVA_COTA
                    ):
                        print(
                            "[PARADA] Tradução salva. "
                            "A reserva de cota foi atingida."
                        )
                        parar = True

                if parar:
                    break

            except ErroValidacaoTraducao as erro:
                falhas += 1
                registrar_falha(identificador, nome, erro)
                print(f"[FALHA DE VALIDAÇÃO] {erro}")
                print(
                    "O exercício ficará pendente; "
                    "o script seguirá para o próximo."
                )

            except KeyboardInterrupt:
                print(
                    "\nInterrupção solicitada. "
                    "O progresso salvo foi preservado."
                )
                break

            except Exception as erro:
                falhas += 1
                registrar_falha(identificador, nome, erro)
                print(f"[ERRO CRÍTICO] {erro}")
                print(
                    "Execução encerrada para evitar novas chamadas. "
                    "Consulte o log."
                )
                break

            if indice < limite and not parar:
                time.sleep(INTERVALO_SEGUNDOS)

    except KeyboardInterrupt:
        print("\nInterrupção solicitada pelo usuário.")

    pendentes_finais = contar_pendentes(
        catalogo, exercicios_pt
    )

    print("\n" + "=" * 60)
    print("RELATÓRIO FINAL")
    print("=" * 60)
    print(f"Exercícios traduzidos nesta execução: {concluidos}")
    print(f"Falhas nesta execução: {falhas}")
    print(f"Exercícios com instruções ainda pendentes: {pendentes_finais}")
    print(f"Última cota restante informada: {restante_cota or 'não informada'}")
    print(f"Arquivo de traduções: {TRADUCOES}")
    print(f"Log: {ARQUIVO_LOG}")
    print(f"Relatório de falhas: {ARQUIVO_FALHAS}")
    print("=" * 60)


if __name__ == "__main__":
    main()
