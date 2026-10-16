import argparse
import csv
import json
from collections import defaultdict
from pathlib import Path

import numpy as np
from scipy import stats

ROOT = Path(__file__).resolve().parents[2]
STUDIES = ROOT / "data" / "studies"
HISTORICAL = ROOT / "data" / "curated" / "historical_2025_summary.json"
PRODUCTION = ROOT / "data" / "curated" / "anp_2025_gasoline_a_production_by_refinery_monthly.csv"
REFERENCE = "referencia"
MEGA = 1_000_000.0
CAP_FUT_PCT = 99.5
CONFIDENCE = 0.95

REGIONS = ("north", "northeast", "southeast", "south")
REGION_LABELS = {"north": "Norte", "northeast": "Nordeste", "southeast": "Sudeste", "south": "Sul"}
POPULATION = {
    "north": 17_354_884,
    "northeast": 54_658_515,
    "southeast": 84_840_113 + 16_289_538,
    "south": 29_937_706,
}
UF_REGION = {
    **dict.fromkeys(["AC", "AP", "AM", "PA", "RO", "RR", "TO"], "north"),
    **dict.fromkeys(["AL", "BA", "CE", "MA", "PB", "PE", "PI", "RN", "SE"], "northeast"),
    **dict.fromkeys(["DF", "GO", "MT", "MS", "ES", "MG", "RJ", "SP"], "southeast"),
    **dict.fromkeys(["PR", "RS", "SC"], "south"),
}
REGION_COVERAGE = {region: f"coverage_{region}" for region in REGIONS}

ANNUAL = (
    ("annual_coverage", "Cobertura nacional", "%", 100.0),
    ("annual_effective_coverage", "Cobertura efetiva", "%", 100.0),
    *((REGION_COVERAGE[region], f"Cobertura efetiva {REGION_LABELS[region]}", "%", 100.0) for region in REGIONS),
    ("annual_deficit_m3", "Déficit anual", "Mm³", 1 / MEGA),
    ("annual_production_m3", "Produção", "Mm³", 1 / MEGA),
    ("annual_fut_pct", "FUT anual", "%", 1.0),
    ("excess_m3", "Excedente", "Mm³", 1 / MEGA),
    ("landed_m3", "Chegadas", "Mm³", 1 / MEGA),
    ("lost_m3", "Perdas no transporte", "Mm³", 1 / MEGA),
    ("plant_stock_m3", "Estoque no fim do ano", "Mm³", 1 / MEGA),
)
DAILY = (
    ("deficit_days", "Dias com falta", "dias"),
    ("max_deficit_m3", "Maior falta diária", "m³"),
    ("p95_deficit_m3", "Falta diária no percentil 95", "m³"),
    ("longest_streak_days", "Maior sequência de dias com falta", "dias"),
    ("deficit_sum_mm3", "Falta diária somada", "Mm³"),
)
PLANT = (
    ("production_mm3", "Produção", "Mm³"),
    ("share_pct", "Participação na produção", "%"),
    ("fut_pct", "FUT", "%"),
    ("cap_days", "Dias no teto", "dias"),
    ("offline_days", "Dias fora do modelo", "dias"),
)
REGION = (
    ("self_sufficiency_pct", "Autossuficiência", "%"),
    ("production_mm3", "Produção", "Mm³"),
    ("demand_mm3", "Demanda", "Mm³"),
    ("stock_mm3", "Estoque no fim do ano", "Mm³"),
)


def constant(data):
    return bool(np.allclose(data, data[0], rtol=1e-9, atol=0.0))


def summary(values):
    data = np.asarray(values, dtype=float)
    mean = float(np.mean(data))
    if constant(data):
        low = high = mean
    else:
        low, high = stats.t.interval(CONFIDENCE, data.size - 1, loc=mean, scale=stats.sem(data))
    return {
        "n": data.size,
        "mean": mean,
        "std": float(np.std(data, ddof=1)),
        "cv": abs(float(stats.variation(data, ddof=1))) if mean else 0.0,
        "min": float(np.min(data)),
        "max": float(np.max(data)),
        "ci95_low": float(low),
        "ci95_high": float(high),
    }


def difference(values, reference):
    left, right = np.asarray(values, dtype=float), np.asarray(reference, dtype=float)
    delta = float(np.mean(left) - np.mean(right))
    if constant(left) and constant(right):
        return {"delta": delta, "ci95_low": delta, "ci95_high": delta, "p_value": float(delta == 0), "significant": delta != 0}
    p_value, low, high = welch(left, right)
    return {
        "delta": delta,
        "ci95_low": float(low),
        "ci95_high": float(high),
        "p_value": float(p_value),
        "significant": bool(p_value < 1 - CONFIDENCE),
    }


def welch(left, right):
    if constant(right):
        test = stats.ttest_1samp(left, right[0])
        interval = test.confidence_interval(CONFIDENCE)
        return test.pvalue, interval.low - right[0], interval.high - right[0]
    if constant(left):
        test = stats.ttest_1samp(right, left[0])
        interval = test.confidence_interval(CONFIDENCE)
        return test.pvalue, left[0] - interval.high, left[0] - interval.low
    test = stats.ttest_ind(left, right, equal_var=False)
    interval = test.confidence_interval(CONFIDENCE)
    return test.pvalue, interval.low, interval.high


def longest_streak(short):
    edges = np.flatnonzero(np.diff(np.concatenate(([0], short.astype(int), [0]))))
    return int((edges[1::2] - edges[::2]).max(initial=0))


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def add_plant(plant, month, row):
    if row["in_model"] != "1":
        plant["offline_days"] += 1
        return
    charge = float(row["petroleum_processed_m3"]) + float(row["other_charges_m3"])
    capacity = float(row["processing_capacity_m3"])
    plant["gasoline_m3"] += float(row["allocated_m3"])
    plant["charge_m3"] += charge
    plant["capacity_m3"] += capacity
    plant["cap_days"] += float(row["fut_pct"]) >= CAP_FUT_PCT
    month["charge_m3"] += charge
    month["capacity_m3"] += capacity


def run_metrics(path):
    days = {}
    months = defaultdict(lambda: defaultdict(float))
    plants = defaultdict(lambda: defaultdict(float))
    ufs, stock = {}, {}
    for row in read_csv(path):
        plant = row["refinery_id"]
        days.setdefault(row["date"], (float(row["day_demand_m3"]), float(row["day_deficit_m3"])))
        add_plant(plants[plant], months[row["date"][:7]], row)
        ufs[plant] = row["uf"]
        stock[plant] = float(row["stock_m3"])
    for date, (_demand, deficit) in days.items():
        months[date[:7]]["deficit_m3"] += deficit
    deficits = np.array([days[date][1] for date in sorted(days)])
    demand = sum(day[0] for day in days.values())
    return {
        "daily": {
            "deficit_days": int(np.count_nonzero(deficits > 0)),
            "max_deficit_m3": float(np.max(deficits)),
            "p95_deficit_m3": float(np.percentile(deficits, 95)),
            "longest_streak_days": longest_streak(deficits > 0),
            "deficit_sum_mm3": float(np.sum(deficits)) / MEGA,
        },
        "months": {
            month: {"fut_pct": values["charge_m3"] / values["capacity_m3"] * 100, "deficit_mm3": values["deficit_m3"] / MEGA}
            for month, values in months.items()
        },
        "plants": plant_metrics(plants),
        "regions": region_metrics(plants, ufs, stock, demand),
        "ufs": ufs,
    }


def plant_metrics(plants):
    total = sum(values["gasoline_m3"] for values in plants.values())
    return {
        plant: {
            "production_mm3": values["gasoline_m3"] / MEGA,
            "share_pct": values["gasoline_m3"] / total * 100,
            "fut_pct": values["charge_m3"] / values["capacity_m3"] * 100,
            "cap_days": values["cap_days"],
            "offline_days": values["offline_days"],
        }
        for plant, values in plants.items()
    }


def regional_demand(demand_m3):
    population = sum(POPULATION.values())
    return {region: demand_m3 * POPULATION[region] / population for region in REGIONS}


def region_metrics(plants, ufs, stock, demand_m3):
    produced, held = defaultdict(float), defaultdict(float)
    for plant, values in plants.items():
        produced[UF_REGION[ufs[plant]]] += values["gasoline_m3"]
        held[UF_REGION[ufs[plant]]] += stock[plant]
    return {
        region: {
            "self_sufficiency_pct": produced[region] / demand * 100,
            "production_mm3": produced[region] / MEGA,
            "demand_mm3": demand / MEGA,
            "stock_mm3": held[region] / MEGA,
        }
        for region, demand in regional_demand(demand_m3).items()
    }


def collect(study):
    scenarios = defaultdict(lambda: {"rows": [], "details": []})
    for row in read_csv(study / "manifest.csv"):
        scenarios[row["scenario_id"]]["rows"].append(row)
        scenarios[row["scenario_id"]]["details"].append(run_metrics(study / row["csv_path"]))
    return dict(scenarios)


def annual_values(scenario, key, scale):
    return [float(row[key]) * scale for row in scenario["rows"]]


def nested_values(scenario, section, item, key):
    return [run[section][item][key] for run in scenario["details"]]


def stats_row(base, metric, unit, values):
    return {**base, "metric": metric, "unit": unit, **summary(values)}


def annual_rows(scenarios):
    return [
        stats_row({"scenario_id": scenario_id}, label, unit, annual_values(scenario, key, scale))
        for scenario_id, scenario in scenarios.items()
        for key, label, unit, scale in ANNUAL
    ]


def reference_rows(scenarios):
    reference = scenarios[REFERENCE]
    return [
        {
            "scenario_id": scenario_id,
            "metric": label,
            "unit": unit,
            **difference(annual_values(scenario, key, scale), annual_values(reference, key, scale)),
        }
        for scenario_id, scenario in scenarios.items()
        if scenario_id != REFERENCE
        for key, label, unit, scale in ANNUAL
    ]


def daily_rows(scenarios):
    return [
        stats_row({"scenario_id": scenario_id}, label, unit, [run["daily"][key] for run in scenario["details"]])
        for scenario_id, scenario in scenarios.items()
        for key, label, unit in DAILY
    ]


def monthly_rows(scenarios):
    rows = []
    for scenario_id, scenario in scenarios.items():
        for month in sorted(scenario["details"][0]["months"]):
            fut = summary(nested_values(scenario, "months", month, "fut_pct"))
            deficit = summary(nested_values(scenario, "months", month, "deficit_mm3"))
            rows.append({
                "scenario_id": scenario_id,
                "month": month,
                "fut_pct_mean": fut["mean"],
                "fut_pct_std": fut["std"],
                "deficit_mm3_mean": deficit["mean"],
            })
    return rows


def entity_rows(scenarios, section, column, metrics):
    return [
        stats_row({"scenario_id": scenario_id, column: item}, label, unit, nested_values(scenario, section, item, key))
        for scenario_id, scenario in scenarios.items()
        for item in sorted(scenario["details"][0][section])
        for key, label, unit in metrics
    ]


def write_csv(path, rows):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def fmt(value, places=2):
    return f"{value:,.{places}f}".replace(",", "_").replace(".", ",").replace("_", ".")


def mean_std(values, places=2):
    result = summary(values)
    return f"{fmt(result['mean'], places)} ± {fmt(result['std'], places)}"


def table(headers, rows):
    lines = ["| " + " | ".join(headers) + " |", "|" + "|".join("---" for _ in headers) + "|"]
    lines += ["| " + " | ".join(str(cell) for cell in row) + " |" for row in rows]
    return lines + [""]


def annual_section(scenarios):
    rows = []
    for scenario_id, scenario in scenarios.items():
        effective = summary(annual_values(scenario, "annual_effective_coverage", 100.0))
        rows.append([
            scenario_id,
            len(scenario["rows"]),
            mean_std(annual_values(scenario, "annual_coverage", 100.0)),
            mean_std(annual_values(scenario, "annual_effective_coverage", 100.0)),
            f"{fmt(effective['ci95_low'])} a {fmt(effective['ci95_high'])}",
            mean_std(annual_values(scenario, "annual_deficit_m3", 1 / MEGA)),
            mean_std(annual_values(scenario, "annual_production_m3", 1 / MEGA)),
            mean_std(annual_values(scenario, "annual_fut_pct", 1.0), 1),
            mean_std(annual_values(scenario, "lost_m3", 1 / MEGA), 3),
        ])
    headers = [
        "Cenário", "Execuções", "Cobertura nacional (%)", "Cobertura efetiva (%)",
        "IC 95% da efetiva", "Déficit nacional (Mm³)", "Produção (Mm³)", "FUT (%)", "Perdas (Mm³)",
    ]
    intro = [
        "## Resultado anual por cenário",
        "",
        "Média ± desvio padrão das execuções. A cobertura nacional compara a produção do ano, "
        "menos as perdas no transporte, com a demanda do país. A cobertura efetiva soma o que "
        "cada região teve no ano (refinação própria e chegadas, menos o que enviou), até a demanda "
        "dela, e divide pela demanda do país. Gasolina parada numa região não cobre outra.",
        "",
    ]
    return intro + table(headers, rows)


def regional_coverage_section(scenarios):
    rows = [
        [scenario_id] + [mean_std(annual_values(scenario, REGION_COVERAGE[region], 100.0), 1) for region in REGIONS]
        for scenario_id, scenario in scenarios.items()
    ]
    intro = [
        "## Cobertura efetiva por região (%)",
        "",
        "Quanto da demanda de cada região foi servido no ano, com a refinação dela e as chegadas "
        "de comboio. Média ± desvio padrão das execuções.",
        "",
    ]
    return intro + table(["Cenário"] + [REGION_LABELS[region] for region in REGIONS], rows)


def reference_section(scenarios):
    reference = scenarios[REFERENCE]
    rows = []
    for scenario_id, scenario in scenarios.items():
        if scenario_id == REFERENCE:
            continue
        cells = [scenario_id]
        for key, scale, places in (
            ("annual_coverage", 100.0, 2),
            ("annual_effective_coverage", 100.0, 2),
            ("annual_deficit_m3", 1 / MEGA, 2),
            ("annual_production_m3", 1 / MEGA, 2),
            ("annual_fut_pct", 1.0, 1),
        ):
            delta = difference(annual_values(scenario, key, scale), annual_values(reference, key, scale))
            cells.append(f"{fmt(delta['delta'], places)}{' *' if delta['significant'] else ''}")
        rows.append(cells)
    headers = [
        "Cenário", "Δ cobertura nacional (p.p.)", "Δ cobertura efetiva (p.p.)",
        "Δ déficit nacional (Mm³)", "Δ produção (Mm³)", "Δ FUT (p.p.)",
    ]
    intro = [
        "## Efeito contra a referência",
        "",
        "Δ é a média do cenário menos a média da referência. O asterisco marca p < 0,05 no teste t "
        "de Welch, que compara médias com variâncias diferentes. O valor p e o intervalo de 95% da "
        "diferença estão em `scenario_vs_reference.csv`.",
        "",
    ]
    return intro + table(headers, rows)


def historical_section(scenarios, historical):
    reference = scenarios[REFERENCE]
    production = annual_values(reference, "annual_production_m3", 1 / MEGA)
    demand = annual_values(reference, "annual_demand_m3", 1 / MEGA)
    rows = [
        ["Produção (Mm³)", fmt(historical["production_supplied_m3"] / MEGA), mean_std(production)],
        ["Demanda (Mm³)", fmt(historical["demand_target_m3"] / MEGA), mean_std(demand)],
        ["Saldo (Mm³)", fmt(historical["balance_m3"] / MEGA), mean_std(np.subtract(production, demand))],
        ["FUT (%)", fmt(historical["total_fut_pct"], 1), mean_std(annual_values(reference, "annual_fut_pct", 1.0), 1)],
    ]
    intro = ["## Referência contra o Histórico 2025", "", "Saldo é produção menos demanda.", ""]
    return intro + table(["Indicador", "Histórico", "Referência"], rows)


def historical_coverage_section(scenarios, historical):
    reference = scenarios[REFERENCE]
    region_of = {plant: UF_REGION[uf] for plant, uf in reference["details"][0]["ufs"].items()}
    produced = defaultdict(float)
    for row in read_csv(PRODUCTION):
        produced[region_of[row["refinery_code"]]] += float(row["gasolina_a_m3"])
    demand = historical["demand_target_m3"]
    regions = regional_demand(demand)
    national = min(demand, historical["production_supplied_m3"]) / demand * 100
    isolated = sum(min(regions[region], produced[region]) for region in REGIONS) / demand * 100
    coverage_rows = [
        ["Cobertura nacional (%)", fmt(national), mean_std(annual_values(reference, "annual_coverage", 100.0))],
        [
            "Cobertura efetiva (%)",
            f"{fmt(isolated)} a {fmt(national)}",
            mean_std(annual_values(reference, "annual_effective_coverage", 100.0)),
        ],
    ]
    region_rows = [
        [
            REGION_LABELS[region],
            fmt(produced[region] / MEGA),
            fmt(regions[region] / MEGA),
            fmt(produced[region] / regions[region] * 100, 1),
            mean_std(nested_values(reference, "regions", region, "self_sufficiency_pct"), 1),
            mean_std(annual_values(reference, REGION_COVERAGE[region], 100.0), 1),
        ]
        for region in REGIONS
    ]
    intro = [
        "## Cobertura do Histórico 2025 com as mesmas simplificações",
        "",
        "A demanda de cada região é a fatia populacional da demanda do país, pelo Censo 2022, com o "
        "Centro-Oeste somado ao Sudeste, como no modelo. A cobertura nacional do Histórico é a produção "
        "observada sobre a demanda, sem perdas, porque o Histórico não tem comboios. A parte que faltou foi "
        "coberta por importação e estoque, que ficam fora do modelo. Os dados não dizem quanta gasolina "
        "passou de uma região para outra, então a cobertura efetiva do Histórico é um intervalo. O menor "
        "valor supõe que nenhuma região mandou gasolina para outra. O maior supõe que toda a sobra chegou "
        "onde faltava, e por isso é igual à cobertura nacional.",
        "",
    ]
    regional_intro = [
        "Autossuficiência é a produção das refinarias da região dividida pela demanda dela. A cobertura "
        "efetiva da referência inclui as chegadas de comboio.",
        "",
    ]
    region_headers = [
        "Região", "Produção histórica (Mm³)", "Demanda (Mm³)", "Autossuficiência histórica (%)",
        "Autossuficiência na referência (%)", "Cobertura efetiva na referência (%)",
    ]
    return (
        intro
        + table(["Indicador", "Histórico", "Referência"], coverage_rows)
        + regional_intro
        + table(region_headers, region_rows)
    )


def daily_section(scenarios):
    rows = [
        [scenario_id]
        + [
            mean_std([run["daily"][key] for run in scenario["details"]], 3 if key == "deficit_sum_mm3" else 0)
            for key, _label, _unit in DAILY
        ]
        for scenario_id, scenario in scenarios.items()
    ]
    headers = [
        "Cenário", "Dias com falta", "Maior falta diária (m³)", "Falta no percentil 95 (m³)",
        "Maior sequência (dias)", "Falta diária somada (Mm³)",
    ]
    intro = [
        "## Fechamento diário",
        "",
        "A falta do dia é a soma do que cada região não cobriu naquele dia, com tanque, produção e "
        "chegadas. Ela mede quando a gasolina não estava na região certa, mesmo que o ano feche coberto.",
        "",
    ]
    return intro + table(headers, rows)


def monthly_section(scenarios, monthly):
    by_key = {(row["scenario_id"], row["month"]): row["fut_pct_mean"] for row in monthly}
    months = sorted({row["month"] for row in monthly})
    rows = [[month] + [fmt(by_key[(scenario_id, month)], 1) for scenario_id in scenarios] for month in months]
    intro = ["## FUT mensal (%)", "", "Média das execuções. FUT é a carga da destilação sobre a capacidade.", ""]
    return intro + table(["Mês"] + list(scenarios), rows)


def region_section(scenarios):
    rows = [
        [scenario_id] + [mean_std(nested_values(scenario, "regions", region, "self_sufficiency_pct"), 1) for region in REGIONS]
        for scenario_id, scenario in scenarios.items()
    ]
    intro = [
        "## Autossuficiência por região (%)",
        "",
        "Produção das refinarias da região dividida pela demanda da região, antes dos comboios. "
        "Abaixo de 100% a região depende de outras.",
        "",
    ]
    return intro + table(["Cenário"] + [REGION_LABELS[region] for region in REGIONS], rows)


def refinery_section(scenarios):
    reference = scenarios[REFERENCE]
    rows = [
        [plant]
        + [
            mean_std(nested_values(reference, "plants", plant, key), 3 if key == "production_mm3" else 1)
            for key, _label, _unit in PLANT
        ]
        for plant in sorted(reference["details"][0]["plants"])
    ]
    headers = ["Refinaria", "Produção (Mm³)", "Participação (%)", "FUT (%)", "Dias no teto", "Dias fora do modelo"]
    intro = [
        "## Refinarias na referência",
        "",
        f"Dias no teto conta os dias com FUT de pelo menos {fmt(CAP_FUT_PCT, 1)}%.",
        "",
    ]
    return intro + table(headers, rows)


def report(study, scenarios, monthly):
    historical = json.loads(HISTORICAL.read_text(encoding="utf-8"))["annual"]
    lines = [
        f"# Análise da bateria `{study.name}`",
        "",
        "Cada cenário tem 10 execuções. Média ± desvio padrão (dp) resume as execuções. "
        "IC 95% é o intervalo de confiança de 95% da média, pela distribuição t de Student. "
        "Mm³ são milhões de m³ e p.p. são pontos percentuais.",
        "",
    ]
    lines += annual_section(scenarios)
    lines += reference_section(scenarios)
    lines += historical_section(scenarios, historical)
    lines += historical_coverage_section(scenarios, historical)
    lines += daily_section(scenarios)
    lines += monthly_section(scenarios, monthly)
    lines += regional_coverage_section(scenarios)
    lines += region_section(scenarios)
    lines += refinery_section(scenarios)
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Resume uma bateria de cenários gravada em data/studies.")
    parser.add_argument("study", nargs="?", help="Pasta da bateria. Sem valor, usa a mais recente.")
    args = parser.parse_args()

    study = Path(args.study) if args.study else max(STUDIES.iterdir(), key=lambda path: path.stat().st_mtime)
    scenarios = collect(study)
    output = study / "analysis"
    output.mkdir(exist_ok=True)

    monthly = monthly_rows(scenarios)
    write_csv(output / "scenario_annual.csv", annual_rows(scenarios))
    write_csv(output / "scenario_vs_reference.csv", reference_rows(scenarios))
    write_csv(output / "scenario_daily.csv", daily_rows(scenarios))
    write_csv(output / "scenario_monthly.csv", monthly)
    write_csv(output / "scenario_refineries.csv", entity_rows(scenarios, "plants", "refinery_id", PLANT))
    write_csv(output / "scenario_regions.csv", entity_rows(scenarios, "regions", "region", REGION))

    text = report(study, scenarios, monthly)
    (output / "report.md").write_text(text + "\n", encoding="utf-8")
    print(text)
    print(f"\nArquivos em {output}")


if __name__ == "__main__":
    main()
