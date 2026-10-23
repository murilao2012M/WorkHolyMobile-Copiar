from deep_translator import GoogleTranslator

tradutor = GoogleTranslator(source="en", target="pt")

testes = [
    "Abdominal Crunch Machine",
    "Alternating Dumbbell Shoulder Press",
    "Lie down on the floor and secure your feet."
]

for texto in testes:
    try:
        resultado = tradutor.translate(texto)
        print(f"Original: {texto}")
        print(f"Português: {resultado}")
        print("-" * 50)
    except Exception as erro:
        print(f"ERRO ao traduzir '{texto}': {erro}")
