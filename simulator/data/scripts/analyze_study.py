import argparse
import csv
import json
import math
import statistics
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STUDIES = ROOT / "data" / "studies"
HISTORICAL = ROOT / "data" / "curated" / "historical_2025_summary.json"
REFERENCE = "referencia"
MEGA = 1_000_000.0
CAP_FUT_PCT = 99.5
DEFICIT_TOLERANCE_M3 = 1e-6
FULL_COVERAGE = 1.0 - 1e-9

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
T_95 = {
    1: 12.706, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571, 6: 2.447, 7: 2.365, 8: 2.306,
    9: 2.262, 10: 2.228, 12: 2.179, 15: 2.131, 20: 2.086, 25: 2.060, 30: 2.042,
}

ANNUAL = (
    ("annual_coverage", "Cobertura anual", "%", 100.0),
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


def number(value):
    return float(value) if value not in (None, "") else None


def ratio(numerator, denominator):
    return numerator / denominator if denominator else 0.0


def t_95(df):
    if df < 1:
        return float("nan")
    if df > 30:
        return 1.96
    return T_95[max(key for key in T_95 if key <= df)]


def summary(values):
    values = [value for value in values if value is not None and not math.isnan(value)]
    if not values:
        return None
    n = len(values)
    mean = statistics.fmean(values)
    std = statistics.stdev(values) if n > 1 else 0.0
    half = t_95(n - 1) * std / math.sqrt(n) if n > 1 else 0.0
    return {
        "n": n,
        "mean": mean,
        "std": std,
        "cv": ratio(std, abs(mean)),
        "min": min(values),
        "max": max(values),
        "ci95_low": mean - half,
        "ci95_high": mean + half,
    }


def difference(values, reference):
    left, right = summary(values), summary(reference)
    if not left or not right or left["n"] < 2 or right["n"] < 2:
        return None
    left_var = left["std"] ** 2 / left["n"]
    right_var = right["std"] ** 2 / right["n"]
    delta = left["mean"] - right["mean"]
    spread = left_var + right_var
    if spread == 0:
        return {"delta": delta, "ci95_low": delta, "ci95_high": delta, "significant": delta != 0}
    df = spread**2 / (left_var**2 / (left["n"] - 1) + right_var**2 / (right["n"] - 1))
    half = t_95(math.floor(df)) * math.sqrt(spread)
    return {
        "delta": delta,
        "ci95_low": delta - half,
        "ci95_high": delta + half,
        "significant": abs(delta) > half,
    }


def percentile(values, q):
    if not values:
        return 0.0
    ordered = sorted(values)
    position = q * (len(ordered) - 1)
    low, high = math.floor(position), math.ceil(position)
    return ordered[low] + (ordered[high] - ordered[low]) * (position - low)


def longest_streak(deficits):
    best = current = 0
    for value in deficits:
        current = current + 1 if value > DEFICIT_TOLERANCE_M3 else 0
        best = max(best, current)
    return best


def study_dir(argument):
    root = STUDIES.resolve()
    if argument is None:
        candidates = [path for path in root.iterdir() if (path / "manifest.csv").is_file()] if root.is_dir() else []
        if not candidates:
            sys.exit("Nenhuma bateria com manifest.csv em data/studies.")
        return max(candidates, key=lambda path: path.stat().st_mtime)
    path = Path(argument).resolve()
    if root not in path.parents:
        sys.exit("A pasta precisa estar dentro de data/studies.")
    if not (path / "manifest.csv").is_file():
        sys.exit("A pasta não tem manifest.csv.")
    return path


def detail_path(study, relative):
    if not relative:
        return None
    path = (study / relative).resolve()
    if study not in path.parents or not path.is_file():
        return None
    return path


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def day_values(row):
    return {key: number(row[f"day_{key}_m3"]) or 0.0 for key in ("demand", "production", "deficit")}


def add_plant(plant, month, row):
    if row["in_model"] != "1":
        plant["offline_days"] += 1
        return
    charge = (number(row["petroleum_processed_m3"]) or 0.0) + (number(row["other_charges_m3"]) or 0.0)
    capacity = number(row["processing_capacity_m3"]) or 0.0
    plant["gasoline_m3"] += number(row["allocated_m3"]) or 0.0
    plant["charge_m3"] += charge
    plant["capacity_m3"] += capacity
    plant["cap_days"] += 1 if (number(row["fut_pct"]) or 0.0) >= CAP_FUT_PCT else 0
    month["charge_m3"] += charge
    month["capacity_m3"] += capacity


def scan_run(path):
    days = {}
    months = defaultdict(lambda: defaultdict(float))
    plants = defaultdict(lambda: defaultdict(float))
    ufs = {}
    stock = {}
    with path.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            plant = row["refinery_id"]
            days.setdefault(row["date"], day_values(row))
            add_plant(plants[plant], months[row["date"][:7]], row)
            ufs[plant] = row["uf"]
            stock[plant] = number(row["stock_m3"]) or 0.0
    for date, day in days.items():
        months[date[:7]]["deficit_m3"] += day["deficit"]
    return days, months, plants, ufs, stock


def daily_metrics(days):
    deficits = [days[date]["deficit"] for date in sorted(days)]
    return {
        "deficit_days": sum(1 for value in deficits if value > DEFICIT_TOLERANCE_M3),
        "max_deficit_m3": max(deficits, default=0.0),
        "p95_deficit_m3": percentile(deficits, 0.95),
        "longest_streak_days": longest_streak(deficits),
        "deficit_sum_mm3": sum(deficits) / MEGA,
    }


def plant_metrics(plants):
    total = sum(values["gasoline_m3"] for values in plants.values())
    return {
        plant: {
            "production_mm3": values["gasoline_m3"] / MEGA,
            "share_pct": ratio(values["gasoline_m3"], total) * 100,
            "fut_pct": ratio(values["charge_m3"], values["capacity_m3"]) * 100,
            "cap_days": values["cap_days"],
            "offline_days": values["offline_days"],
        }
        for plant, values in plants.items()
    }


def region_metrics(plants, ufs, stock, demand_m3):
    produced, held = defaultdict(float), defaultdict(float)
    for plant, values in plants.items():
        region = UF_REGION.get(ufs.get(plant, ""))
        if region:
            produced[region] += values["gasoline_m3"]
            held[region] += stock.get(plant, 0.0)
    population = sum(POPULATION.values())
    metrics = {}
    for region in REGIONS:
        demand = demand_m3 * POPULATION[region] / population
        metrics[region] = {
            "self_sufficiency_pct": ratio(produced[region], demand) * 100,
            "production_mm3": produced[region] / MEGA,
            "demand_mm3": demand / MEGA,
            "stock_mm3": held[region] / MEGA,
        }
    return metrics


def run_metrics(path):
    days, months, plants, ufs, stock = scan_run(path)
    demand = sum(day["demand"] for day in days.values())
    return {
        "daily": daily_metrics(days),
        "months": {
            month: {"fut_pct": ratio(values["charge_m3"], values["capacity_m3"]) * 100, "deficit_mm3": values["deficit_m3"] / MEGA}
            for month, values in months.items()
        },
        "plants": plant_metrics(plants),
        "regions": region_metrics(plants, ufs, stock, demand),
    }


def scaled(row, key, scale):
    value = number(row.get(key))
    return value * scale if value is not None else None


def collect(study, manifest):
    scenarios = {}
    for scenario in dict.fromkeys(row["scenario_id"] for row in manifest):
        runs = [row for row in manifest if row["scenario_id"] == scenario]
        ok = [row for row in runs if row["status"] == "ok"]
        paths = [detail_path(study, row["csv_path"]) for row in ok]
        scenarios[scenario] = {
            "name": runs[0]["scenario_name"],
            "runs": len(runs),
            "ok": ok,
            "failed": [row for row in runs if row["status"] != "ok"],
            "details": [run_metrics(path) for path in paths if path],
        }
    return scenarios


def annual_values(scenario, key, scale):
    return [scaled(row, key, scale) for row in scenario["ok"]]


def nested_values(scenario, section, item, key):
    return [run[section][item][key] for run in scenario["details"] if item in run[section]]


def stats_row(base, metric, unit, stats):
    return {**base, "metric": metric, "unit": unit, **(stats or {})}


def annual_rows(scenarios):
    return [
        stats_row({"scenario_id": scenario_id}, label, unit, summary(annual_values(scenario, key, scale)))
        for scenario_id, scenario in scenarios.items()
        for key, label, unit, scale in ANNUAL
    ]


def reference_rows(scenarios):
    reference = scenarios.get(REFERENCE)
    if not reference:
        return []
    rows = []
    for scenario_id, scenario in scenarios.items():
        if scenario_id == REFERENCE:
            continue
        for key, label, unit, scale in ANNUAL:
            delta = difference(annual_values(scenario, key, scale), annual_values(reference, key, scale))
            if delta:
                rows.append({"scenario_id": scenario_id, "metric": label, "unit": unit, **delta})
    return rows


def daily_rows(scenarios):
    return [
        stats_row({"scenario_id": scenario_id}, label, unit, summary([run["daily"][key] for run in scenario["details"]]))
        for scenario_id, scenario in scenarios.items()
        for key, label, unit in DAILY
    ]


def monthly_rows(scenarios):
    rows = []
    for scenario_id, scenario in scenarios.items():
        months = sorted({month for run in scenario["details"] for month in run["months"]})
        for month in months:
            fut = summary(nested_values(scenario, "months", month, "fut_pct")) or {}
            deficit = summary(nested_values(scenario, "months", month, "deficit_mm3")) or {}
            rows.append({
                "scenario_id": scenario_id,
                "month": month,
                "fut_pct_mean": fut.get("mean"),
                "fut_pct_std": fut.get("std"),
                "deficit_mm3_mean": deficit.get("mean"),
            })
    return rows


def entity_rows(scenarios, section, column, metrics):
    rows = []
    for scenario_id, scenario in scenarios.items():
        items = sorted({item for run in scenario["details"] for item in run[section]})
        for item in items:
            for key, label, unit in metrics:
                stats = summary(nested_values(scenario, section, item, key))
                rows.append(stats_row({"scenario_id": scenario_id, column: item}, label, unit, stats))
    return rows


def write_csv(path, rows):
    if not rows:
        return
    columns = list(dict.fromkeys(key for row in rows for key in row))
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def fmt(value, places=2):
    if value is None or (isinstance(value, float) and math.isnan(value)):
        return "n/d"
    text = f"{value:,.{places}f}"
    return text.replace(",", "_").replace(".", ",").replace("_", ".")


def mean_std(stats, places=2):
    return f"{fmt(stats['mean'], places)} ± {fmt(stats['std'], places)}" if stats else "n/d"


def table(headers, rows):
    lines = ["| " + " | ".join(headers) + " |", "|" + "|".join("---" for _ in headers) + "|"]
    lines += ["| " + " | ".join(str(cell) for cell in row) + " |" for row in rows]
    return lines + [""]


def annual_section(scenarios):
    rows = []
    for scenario_id, scenario in scenarios.items():
        coverage = summary(annual_values(scenario, "annual_coverage", 100.0))
        full = sum(1 for row in scenario["ok"] if (number(row["annual_coverage"]) or 0.0) >= FULL_COVERAGE)
        rows.append([
            scenario_id,
            f"{len(scenario['ok'])}/{scenario['runs']}",
            mean_std(coverage),
            f"{fmt(coverage['ci95_low'])} a {fmt(coverage['ci95_high'])}" if coverage else "n/d",
            mean_std(summary(annual_values(scenario, "annual_deficit_m3", 1 / MEGA))),
            mean_std(summary(annual_values(scenario, "annual_production_m3", 1 / MEGA))),
            mean_std(summary(annual_values(scenario, "annual_fut_pct", 1.0)), 1),
            mean_std(summary(annual_values(scenario, "lost_m3", 1 / MEGA)), 3),
            f"{full}/{len(scenario['ok'])}",
        ])
    headers = [
        "Cenário", "Execuções ok", "Cobertura (%)", "IC 95% da cobertura", "Déficit (Mm³)",
        "Produção (Mm³)", "FUT (%)", "Perdas (Mm³)", "Execuções com 100%",
    ]
    return ["## Resultado anual por cenário", "", "Média ± desvio padrão das execuções.", ""] + table(headers, rows)


def reference_section(scenarios):
    reference = scenarios.get(REFERENCE)
    if not reference:
        return ["## Efeito contra a referência", "", "Sem o cenário `referencia` na bateria.", ""]
    rows = []
    for scenario_id, scenario in scenarios.items():
        if scenario_id == REFERENCE:
            continue
        cells = [scenario_id]
        for key, scale, places in (
            ("annual_coverage", 100.0, 2),
            ("annual_deficit_m3", 1 / MEGA, 2),
            ("annual_production_m3", 1 / MEGA, 2),
            ("annual_fut_pct", 1.0, 1),
        ):
            delta = difference(annual_values(scenario, key, scale), annual_values(reference, key, scale))
            cells.append(f"{fmt(delta['delta'], places)}{' *' if delta['significant'] else ''}" if delta else "n/d")
        rows.append(cells)
    headers = ["Cenário", "Δ cobertura (p.p.)", "Δ déficit (Mm³)", "Δ produção (Mm³)", "Δ FUT (p.p.)"]
    intro = [
        "## Efeito contra a referência",
        "",
        "Δ é a média do cenário menos a média da referência. O asterisco marca diferença cujo "
        "intervalo de confiança de 95% (teste de Welch) não inclui zero.",
        "",
    ]
    return intro + table(headers, rows)


def historical_section(scenarios):
    reference = scenarios.get(REFERENCE)
    if not reference or not HISTORICAL.is_file():
        return []
    annual = json.loads(HISTORICAL.read_text(encoding="utf-8"))["annual"]
    production = annual_values(reference, "annual_production_m3", 1 / MEGA)
    demand = annual_values(reference, "annual_demand_m3", 1 / MEGA)
    balance = [p - d for p, d in zip(production, demand) if p is not None and d is not None]
    rows = [
        ["Produção (Mm³)", fmt(annual["production_supplied_m3"] / MEGA), mean_std(summary(production))],
        ["Demanda (Mm³)", fmt(annual["demand_target_m3"] / MEGA), mean_std(summary(demand))],
        ["Saldo (Mm³)", fmt(annual["balance_m3"] / MEGA), mean_std(summary(balance))],
        ["FUT (%)", fmt(annual["total_fut_pct"], 1), mean_std(summary(annual_values(reference, "annual_fut_pct", 1.0)), 1)],
    ]
    intro = ["## Referência contra o Histórico 2025", "", "Saldo é produção menos demanda.", ""]
    return intro + table(["Indicador", "Histórico", "Referência"], rows)


def daily_section(scenarios):
    rows = []
    for scenario_id, scenario in scenarios.items():
        cells = [scenario_id]
        for key, _label, _unit in DAILY:
            places = 3 if key == "deficit_sum_mm3" else 0
            cells.append(mean_std(summary([run["daily"][key] for run in scenario["details"]]), places))
        rows.append(cells)
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
    months = sorted({row["month"] for row in monthly})
    by_key = {(row["scenario_id"], row["month"]): row for row in monthly}
    rows = [[month] + [fmt(by_key.get((scenario_id, month), {}).get("fut_pct_mean"), 1) for scenario_id in scenarios] for month in months]
    intro = ["## FUT mensal (%)", "", "Média das execuções. FUT é a carga da destilação sobre a capacidade.", ""]
    return intro + table(["Mês"] + list(scenarios), rows)


def region_section(scenarios):
    rows = [
        [scenario_id] + [mean_std(summary(nested_values(scenario, "regions", region, "self_sufficiency_pct")), 1) for region in REGIONS]
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
    reference = scenarios.get(REFERENCE)
    if not reference:
        return []
    plants = sorted({plant for run in reference["details"] for plant in run["plants"]})
    rows = [
        [plant] + [mean_std(summary(nested_values(reference, "plants", plant, key)), 1 if key != "production_mm3" else 3) for key, _label, _unit in PLANT]
        for plant in plants
    ]
    headers = ["Refinaria", "Produção (Mm³)", "Participação (%)", "FUT (%)", "Dias no teto", "Dias fora do modelo"]
    intro = [
        "## Refinarias na referência",
        "",
        f"Dias no teto conta os dias com FUT de pelo menos {fmt(CAP_FUT_PCT, 1)}%.",
        "",
    ]
    return intro + table(headers, rows)


def failure_section(scenarios):
    failed = [
        f"- `{scenario_id}`, execução {row['run']}: {row['note']}"
        for scenario_id, scenario in scenarios.items()
        for row in scenario["failed"]
    ]
    return ["## Execuções que falharam", ""] + failed + [""] if failed else []


def report(study, scenarios, monthly):
    lines = [
        f"# Análise da bateria `{study.name}`",
        "",
        "Cada cenário tem até 10 execuções. Média ± desvio padrão (dp) resume as execuções. "
        "IC 95% é o intervalo de confiança de 95% da média, pela distribuição t de Student. "
        "Mm³ são milhões de m³ e p.p. são pontos percentuais.",
        "",
    ]
    lines += annual_section(scenarios)
    lines += reference_section(scenarios)
    lines += historical_section(scenarios)
    lines += daily_section(scenarios)
    lines += monthly_section(scenarios, monthly)
    lines += region_section(scenarios)
    lines += refinery_section(scenarios)
    lines += failure_section(scenarios)
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Resume uma bateria de cenários gravada em data/studies.")
    parser.add_argument("study", nargs="?", help="Pasta da bateria. Sem valor, usa a mais recente.")
    args = parser.parse_args()

    study = study_dir(args.study)
    scenarios = collect(study, read_csv(study / "manifest.csv"))
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
