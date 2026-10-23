import json
import os
import http.client
import urllib.parse

HOST = "free-google-translator.p.rapidapi.com"
CHAVE = os.environ.get("RAPIDAPI_KEY")

if not CHAVE:
    raise SystemExit("Configure a variável RAPIDAPI_KEY no PowerShell.")

testes = [
    "Abdominal Crunch Machine",
    "Alternating Dumbbell Shoulder Press",
    "Barbell Squat",
    "Lie down on the floor and secure your feet.",
    "Keep your back straight throughout the movement."
]

conn = http.client.HTTPSConnection(HOST, timeout=30)

headers = {
    "x-rapidapi-key": CHAVE,
    "x-rapidapi-host": HOST,
    "Content-Type": "application/json"
}

try:
    for texto in testes:
        parametros = urllib.parse.urlencode({
            "from": "en",
            "to": "pt",
            "query": texto
        })

        caminho = f"/external-api/free-google-translator?{parametros}"
        payload = json.dumps({"translate": texto})

        conn.request("POST", caminho, payload, headers)
        resposta = conn.getresponse()
        corpo = resposta.read().decode("utf-8", errors="replace")

        print(f"\nHTTP: {resposta.status}")
        print(f"Original: {texto}")

        try:
            resultado = json.loads(corpo)
            print("Resposta:", json.dumps(
                resultado, ensure_ascii=False, indent=2
            ))
        except json.JSONDecodeError:
            print("Resposta:", corpo[:1500])

        if resposta.status != 200:
            print("Teste interrompido por resposta diferente de HTTP 200.")
            break

finally:
    conn.close()
