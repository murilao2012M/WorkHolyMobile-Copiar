from deep_translator import GoogleTranslator

tradutor = GoogleTranslator(source="en", target="pt")

frases = [
    "3/4 Sit-Up",
    "Lie down on the floor and secure your feet.",
    "Keep your back straight throughout the movement."
]

try:
    resultados = tradutor.translate_batch(frases)

    for original, traduzido in zip(frases, resultados):
        print(f"\nEN: {original}")
        print(f"PT: {traduzido}")

except Exception as erro:
    print(f"Falha no teste: {erro}")
