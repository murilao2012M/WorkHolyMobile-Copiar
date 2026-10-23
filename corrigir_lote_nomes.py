import json
from pathlib import Path

arquivo = Path("assets/exercicios/traducoes_pt_BR.json")

correcoes = {
    "Ball_Leg_Curl": "Flexão de pernas com bola",
    "Balance_Board": "Prancha de equilíbrio",
    "Band_Good_Morning": "Bom dia com faixa elástica",
    "Band_Good_Morning_Pull_Through": "Bom dia com faixa elástica e puxada entre as pernas",
    "Band_Hip_Adductions": "Adução de quadril com faixa elástica",
    "Band_Pull_Apart": "Abertura de faixa elástica",
    "Band_Skull_Crusher": "Extensão de tríceps com faixa elástica",
    "Barbell_Ab_Rollout": "Rolamento abdominal com barra",
    "Barbell_Ab_Rollout_-_On_Knees": "Rolamento abdominal com barra, ajoelhado",
    "Barbell_Bench_Press_-_Medium_Grip": "Supino com barra e pegada média",
    "Barbell_Curl": "Rosca com barra",
    "Barbell_Curls_Lying_Against_An_Incline": "Rosca com barra deitado em banco inclinado",
    "Barbell_Incline_Bench_Press_-_Medium_Grip": "Supino inclinado com barra e pegada média",
    "Barbell_Incline_Shoulder_Raise": "Elevação de ombros inclinada com barra",
    "Barbell_Hip_Thrust": "Elevação de quadril com barra",
}

with arquivo.open("r", encoding="utf-8-sig") as f:
    dados = json.load(f)

exercicios = dados.setdefault("exercicios", {})
alterados = 0

for identificador, nome in correcoes.items():
    if identificador not in exercicios:
        print(f"[NÃO ENCONTRADO] {identificador}")
        continue

    exercicios[identificador]["nome"] = nome
    exercicios[identificador]["status_nome"] = "corrigido_manual"
    alterados += 1

temporario = arquivo.with_suffix(".json.tmp")
with temporario.open("w", encoding="utf-8", newline="\n") as f:
    json.dump(dados, f, ensure_ascii=False, indent=2)
    f.write("\n")

temporario.replace(arquivo)

print(f"Correções aplicadas: {alterados}")
print("Catálogo original preservado.")
