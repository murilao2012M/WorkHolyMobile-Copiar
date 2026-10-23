import json
from pathlib import Path
from collections import Counter

arquivo = Path("assets/exercicios/free_exercise_db.json")

with arquivo.open("r", encoding="utf-8-sig") as f:
    dados = json.load(f)

if not isinstance(dados, list):
    raise SystemExit("ERRO: o catálogo não é uma lista JSON.")

ids = [str(item.get("id", "")).strip() for item in dados]
ids_validos = [identificador for identificador in ids if identificador]

print(f"Total de registros: {len(dados)}")
print(f"IDs preenchidos: {len(ids_validos)}")
print(f"IDs únicos: {len(set(ids_validos))}")
print(f"IDs duplicados: {len(ids_validos) - len(set(ids_validos))}")

print("\nCampos encontrados:")
campos = Counter()
for item in dados:
    campos.update(item.keys())

for campo, quantidade in campos.most_common():
    print(f"  {campo}: {quantidade} registros")

print("\nPrimeiros 5 exercícios:")
for item in dados[:5]:
    print(f"\nID: {item.get('id')}")
    print(f"Nome: {item.get('name')}")
    instrucoes = item.get("instructions", [])
    print(f"Quantidade de instruções: {len(instrucoes)}")
    for numero, instrucao in enumerate(instrucoes[:2], start=1):
        print(f"  {numero}. {instrucao}")

print("\nAuditoria concluída. Nenhum arquivo foi alterado.")
