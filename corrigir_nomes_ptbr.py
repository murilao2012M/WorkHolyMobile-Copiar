import json
from pathlib import Path

arquivo = Path("assets/exercicios/traducoes_pt_BR.json")

correcoes = {
    "Adductor_Groin": "Alongamento de adutores (virilha)",
    "Advanced_Kettlebell_Windmill": "Moinho de vento avançado com kettlebell",
    "Air_Bike": "Bicicleta ergométrica de resistência a ar",
    "All_Fours_Quad_Stretch": "Alongamento de quadríceps em quatro apoios",
    "Alternate_Hammer_Curl": "Rosca martelo alternada",
    "Alternate_Heel_Touchers": "Toques alternados nos calcanhares",
    "Alternate_Incline_Dumbbell_Curl": "Rosca alternada com halteres no banco inclinado",
    "Alternate_Leg_Diagonal_Bound": "Saltos diagonais alternados",
    "Alternating_Cable_Shoulder_Press": "Desenvolvimento alternado de ombros na polia",
    "Alternating_Deltoid_Raise": "Elevação alternada dos deltoides",
    "Alternating_Floor_Press": "Supino alternado no chão",
    "Alternating_Hang_Clean": "Clean alternado a partir da posição suspensa",
    "Alternating_Kettlebell_Press": "Desenvolvimento alternado com kettlebell",
    "Alternating_Kettlebell_Row": "Remada alternada com kettlebell",
    "Alternating_Renegade_Row": "Remada renegada alternada",
    "Ankle_Circles": "Rotação circular dos tornozelos",
    "Ankle_On_The_Knee": "Tornozelo apoiado sobre o joelho",
    "Anterior_Tibialis-SMR": "Liberação miofascial do tibial anterior",
    "Anti-Gravity_Press": "Desenvolvimento antigravitacional",
    "Arm_Circles": "Circundução dos braços",
    "Arnold_Dumbbell_Press": "Desenvolvimento Arnold com halteres",
    "Around_The_Worlds": "Around the Worlds",
    "Atlas_Stone_Trainer": "Treino com pedra Atlas",
    "Atlas_Stones": "Pedras Atlas",
    "Axle_Deadlift": "Levantamento terra com barra axle",
}

with arquivo.open("r", encoding="utf-8-sig") as f:
    dados = json.load(f)

exercicios = dados.setdefault("exercicios", {})
atualizados = 0

for identificador, nome_pt in correcoes.items():
    atual = exercicios.get(identificador)

    if isinstance(atual, dict):
        atual["nome"] = nome_pt
    else:
        exercicios[identificador] = {"nome": nome_pt}

    atualizados += 1

temporario = arquivo.with_suffix(".json.tmp")
with temporario.open("w", encoding="utf-8", newline="\n") as f:
    json.dump(dados, f, ensure_ascii=False, indent=2)
    f.write("\n")

temporario.replace(arquivo)

print(f"Correções de terminologia aplicadas: {atualizados}")
print(f"Arquivo atualizado: {arquivo}")
print("O catálogo original não foi alterado.")
