import json
from pathlib import Path
from collections import Counter

catalogo_path = Path("assets/exercicios/free_exercise_db.json")
traducoes_path = Path("assets/exercicios/traducoes_pt_BR.json")

with catalogo_path.open("r", encoding="utf-8-sig") as f:
    catalogo = json.load(f)

with traducoes_path.open("r", encoding="utf-8-sig") as f:
    traducoes = json.load(f)

exercicios_pt = traducoes.get("exercicios", {})

total_instrucoes = 0
exercicios_com_instrucoes = 0
sem_instrucoes = 0
caracteres = 0
tipos = Counter()

for item in catalogo:
    instrucoes = item.get("instructions", [])

    if isinstance(instrucoes, list):
        tipos["lista"] += 1
        total_instrucoes += len(instrucoes)
        caracteres += sum(
            len(str(i)) for i in instrucoes if i is not None
        )
        if instrucoes:
            exercicios_com_instrucoes += 1
        else:
            sem_instrucoes += 1
    elif isinstance(instrucoes, str):
        tipos["texto"] += 1
        caracteres += len(instrucoes)
        if instrucoes.strip():
            total_instrucoes += 1
            exercicios_com_instrucoes += 1
        else:
            sem_instrucoes += 1
    else:
        tipos[type(instrucoes).__name__] += 1
        sem_instrucoes += 1

com_nome = sum(
    1 for item in catalogo
    if str(
        exercicios_pt.get(str(item.get("id", "")), {}).get("nome", "")
    ).strip()
)

com_instrucao_pt = sum(
    1 for item in catalogo
    if exercicios_pt.get(str(item.get("id", "")), {}).get("instrucoes")
)

print("=" * 52)
print("AUDITORIA DAS INSTRUÇÕES - WORKHOLYMOBILE")
print("=" * 52)
print(f"Exercícios no catálogo: {len(catalogo)}")
print(f"Nomes em português preenchidos: {com_nome}")
print(f"Exercícios com instruções originais: {exercicios_com_instrucoes}")
print(f"Exercícios sem instruções: {sem_instrucoes}")
print(f"Total de instruções/itens: {total_instrucoes}")
print(f"Caracteres originais nas instruções: {caracteres}")
print(f"Tipos encontrados: {dict(tipos)}")
print(f"Exercícios com campo instrucoes no arquivo de tradução: {com_instrucao_pt}")
print("=" * 52)
