import json
from pathlib import Path
from collections import Counter

catalogo_path = Path("assets/exercicios/free_exercise_db.json")
traducoes_path = Path("assets/exercicios/traducoes_pt_BR.json")

with catalogo_path.open("r", encoding="utf-8-sig") as f:
    catalogo = json.load(f)

with traducoes_path.open("r", encoding="utf-8-sig") as f:
    dados = json.load(f)

exercicios = dados.get("exercicios", {})
ids_catalogo = {str(item["id"]) for item in catalogo}

nomes_preenchidos = {
    identificador: registro
    for identificador, registro in exercicios.items()
    if isinstance(registro, dict) and registro.get("nome", "").strip()
}

status = Counter(
    registro.get("status_nome", "sem_status")
    for registro in nomes_preenchidos.values()
)

print(f"Total no catálogo: {len(catalogo)}")
print(f"Nomes preenchidos: {len(nomes_preenchidos)}")
print(f"Nomes pendentes: {len(ids_catalogo - set(nomes_preenchidos))}")
print(f"Traduções sem exercício correspondente: {len(set(exercicios) - ids_catalogo)}")
print("\nDistribuição por status:")

for nome_status, quantidade in sorted(status.items()):
    print(f"  {nome_status}: {quantidade}")

print("\nAmostra das correções:")
for identificador in [
    "Ball_Leg_Curl",
    "Band_Good_Morning",
    "Band_Pull_Apart",
    "Barbell_Curl",
    "Barbell_Hip_Thrust",
]:
    registro = exercicios.get(identificador, {})
    print(f"  {identificador}: {registro.get('nome', 'AUSENTE')}")

print("\nAuditoria concluída.")
