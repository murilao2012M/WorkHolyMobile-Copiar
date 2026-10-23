import requests

url = "https://api.mymemory.translated.net/get"

parametros = {
    "q": "Lie down on the floor and secure your feet.",
    "langpair": "en|pt-BR"
}

try:
    resposta = requests.get(url, params=parametros, timeout=20)
    resposta.raise_for_status()
    dados = resposta.json()

    traducao = dados.get("responseData", {}).get("translatedText")

    if dados.get("responseStatus") == 200 and traducao:
        print("Original: Lie down on the floor and secure your feet.")
        print(f"Tradução: {traducao}")
    else:
        print("O serviço não retornou uma tradução válida.")
        print(dados)

except Exception as erro:
    print(f"Falha no teste: {erro}")
