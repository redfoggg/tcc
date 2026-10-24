import argparse
import csv
import hashlib
import json
import platform
from collections import defaultdict
from pathlib import Path

import numpy as np
import scipy

import study_statistics as inference
from study_statistics import CONFIDENCE, descriptive, diagnostics, difference, holm, summary

ROOT = Path(__file__).resolve().parents[2]
STUDIES = ROOT / "data" / "studies"
HISTORICAL = ROOT / "data" / "curated" / "historical_2025_summary.json"
PRODUCTION = ROOT / "data" / "curated" / "anp_2025_gasoline_a_production_by_refinery_monthly.csv"
REFERENCE = "referencia"
CEILING = "mobilidade_fut"
CEILING_METRICS = (
    "annual_fut_pct",
    "production_mm3",
    "effective_coverage_pct",
    "effective_coverage_delta_pp",
    "deficit_mm3",
    "deficit_days",
    "deficit_sum_mm3",
)
MEGA = 1_000_000.0
CAP_FUT_PCT = 99.5

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
    study = study.resolve()
    scenarios = defaultdict(lambda: {"rows": [], "details": []})
    seen, sources = set(), set()
    for row in read_csv(study / "manifest.csv"):
        if row["status"] != "ok":
            raise ValueError(f"Failed run in manifest: {row['scenario_id']} / {row['run']}")
        run = int(row["run"])
        if run < 1 or (row["scenario_id"], run) in seen:
            raise ValueError("Run IDs must be positive and unique within each scenario")
        seen.add((row["scenario_id"], run))
        row["run"] = run
        source = (study / row["csv_path"]).resolve()
        if not source.is_relative_to(study) or Path(row["csv_path"]).is_absolute():
            raise ValueError("Run CSV must be inside the selected study")
        if source in sources:
            raise ValueError("The same simulation CSV cannot represent multiple runs")
        sources.add(source)
        scenarios[row["scenario_id"]]["rows"].append(row)
    if REFERENCE not in scenarios or CEILING not in scenarios:
        raise ValueError("Study must contain reference and mobility scenarios")
    for scenario in scenarios.values():
        scenario["rows"].sort(key=lambda row: row["run"])
        paired_rows(scenario, scenarios[REFERENCE], exact=True)
        scenario["details"] = [run_metrics(study / row["csv_path"]) for row in scenario["rows"]]
    return dict(scenarios)


def paired_rows(scenario, reference, exact=False):
    def index(rows):
        result = {}
        for row in rows:
            key = int(row["run"])
            if key in result:
                raise ValueError("Duplicate run in paired comparison")
            result[key] = row
        return result
    left, right = index(scenario["rows"]), index(reference["rows"])
    if not left or not set(left) <= set(right) or (exact and set(left) != set(right)):
        raise ValueError("Scenario/reference run IDs do not match")
    pairs = [(left[run], right[run]) for run in sorted(left)]
    if any(a["seed"] != b["seed"] for a, b in pairs):
        raise ValueError("Paired scenario/reference seeds do not match")
    return pairs


def ceiling_groups(scenarios):
    grouped = defaultdict(lambda: {"rows": [], "details": []})
    mobile = scenarios[CEILING]
    for row, details in zip(mobile["rows"], mobile["details"]):
        ceiling = float(row["fut_lock"]) * 100
        if not np.isfinite(ceiling) or not 0 < ceiling <= 100:
            raise ValueError("Invalid FUT ceiling")
        grouped[ceiling]["rows"].append(row)
        grouped[ceiling]["details"].append(details)
    return dict(sorted(grouped.items()))


def annual_values(scenario, key, scale):
    return [float(row[key]) * scale for row in scenario["rows"]]


def nested_values(scenario, section, item, key):
    return [run[section][item][key] for run in scenario["details"]]


def stats_row(base, metric, unit, values):
    return {**base, "metric": metric, "unit": unit,
            **summary(values, inferential=base.get("scenario_id") != CEILING)}


def annual_rows(scenarios):
    return [
        stats_row({"scenario_id": scenario_id}, label, unit, annual_values(scenario, key, scale))
        for scenario_id, scenario in scenarios.items()
        for key, label, unit, scale in ANNUAL
    ]


def reference_rows(scenarios):
    reference = scenarios[REFERENCE]
    groups = [(scenario_id, None, scenario) for scenario_id, scenario in scenarios.items()
              if scenario_id not in (REFERENCE, CEILING)]
    groups += [(CEILING, ceiling, group) for ceiling, group in ceiling_groups(scenarios).items()]
    rows = []
    for scenario_id, ceiling, scenario in groups:
        pairs = paired_rows(scenario, reference)
        for key, label, unit, scale in ANNUAL:
            left = [float(a[key]) * scale for a, _b in pairs]
            right = [float(b[key]) * scale for _a, b in pairs]
            rows.append({"scenario_id": scenario_id, "ceiling_pct": ceiling,
                         "metric": label, "unit": "p.p." if unit == "%" else unit,
                         **difference(left, right)})
    # Includes every annual metric and every ceiling, not only report columns.
    return holm(rows)


def diagnostic_rows(scenarios):
    rows = []
    groups = [(sid, None, group) for sid, group in scenarios.items() if sid != CEILING]
    groups += [(CEILING, ceiling, group) for ceiling, group in ceiling_groups(scenarios).items()]
    for sid, ceiling, group in groups:
        for key, label, unit, scale in ANNUAL:
            values = annual_values(group, key, scale)
            bounds = (0.0, 100.0) if key == "annual_fut_pct" or "coverage" in key else None
            rows.append({"scenario_id": sid, "ceiling_pct": ceiling, "metric": label,
                         "unit": unit, **summary(values), **diagnostics(values, bounds)})
    return rows


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
            fut = descriptive(nested_values(scenario, "months", month, "fut_pct"))
            deficit = descriptive(nested_values(scenario, "months", month, "deficit_mm3"))
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


def ceiling_rows(scenarios):
    reference = {row["run"]: row for row in scenarios[REFERENCE]["rows"]}
    runs = [
        {
            "ceiling_pct": float(row["fut_lock"]) * 100,
            "annual_fut_pct": float(row["annual_fut_pct"]),
            "production_mm3": float(row["annual_production_m3"]) / MEGA,
            "effective_coverage_pct": float(row["annual_effective_coverage"]) * 100,
            "effective_coverage_delta_pp": (
                float(row["annual_effective_coverage"]) - float(reference[row["run"]]["annual_effective_coverage"])
            )
            * 100,
            "deficit_mm3": float(row["annual_deficit_m3"]) / MEGA,
            "deficit_days": details["daily"]["deficit_days"],
            "deficit_sum_mm3": details["daily"]["deficit_sum_mm3"],
        }
        for row, details in zip(scenarios[CEILING]["rows"], scenarios[CEILING]["details"])
    ]
    by_ceiling = defaultdict(list)
    for run in runs:
        by_ceiling[run["ceiling_pct"]].append(run)
    return [
        stats_row({"ceiling_pct": ceiling}, metric, "", [run[metric] for run in group])
        for ceiling, group in sorted(by_ceiling.items())
        for metric in CEILING_METRICS
    ]


def write_csv(path, rows):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def fmt(value, places=2):
    if value is None:
        return "—"
    return f"{value:,.{places}f}".replace(",", "_").replace(".", ",").replace("_", ".")


def mean_std(values, places=2):
    result = descriptive(values)
    return f"{fmt(result['mean'], places)} ± {fmt(result['std'], places)}"


def table(headers, rows):
    lines = ["| " + " | ".join(headers) + " |", "|" + "|".join("---" for _ in headers) + "|"]
    lines += ["| " + " | ".join(str(cell) for cell in row) + " |" for row in rows]
    return lines + [""]


def annual_section(scenarios):
    rows = []
    for scenario_id, scenario in scenarios.items():
        effective = summary(annual_values(scenario, "annual_effective_coverage", 100.0),
                            inferential=scenario_id != CEILING)
        rows.append([
            scenario_id,
            len(scenario["rows"]),
            mean_std(annual_values(scenario, "annual_coverage", 100.0)),
            mean_std(annual_values(scenario, "annual_effective_coverage", 100.0)),
            interval_cell(effective),
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
        "dela, e divide pela demanda do país. Gasolina parada numa região não cobre outra. "
        "A linha mobilidade_fut é apenas descritiva: mistura tetos e não recebe IC agregado.",
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


def interval_cell(result, prefix=""):
    low, high = result.get(prefix + "ci95_low"), result.get(prefix + "ci95_high")
    return f"{fmt(low)} a {fmt(high)}" if low is not None and high is not None else "—"


def reference_section(comparisons):
    cells = {(r["scenario_id"], r["ceiling_pct"], r["metric"]): r for r in comparisons}
    groups = list(dict.fromkeys((r["scenario_id"], r["ceiling_pct"]) for r in comparisons))
    rows = []
    for sid, ceiling in groups:
        label = sid if ceiling is None else f"{sid} — teto {fmt(ceiling, 0)}%"
        row = [label]
        for metric, places in (("Cobertura nacional", 2), ("Cobertura efetiva", 2),
                               ("Déficit anual", 2), ("Produção", 2), ("FUT anual", 1)):
            item = cells[(sid, ceiling, metric)]
            suffix = " *" if item["significant"] else ""
            if item["inference_status"] != "ok":
                suffix += " NI"
            row.append(fmt(item["delta"], places) + suffix)
        rows.append(row)
    intro = [
        "## Efeito contra a referência", "",
        "Δ é a média das diferenças entre execuções de mesmo número e semente. Cada teto de FUT "
        "é comparado apenas com suas execuções correspondentes da referência. O teste principal é t pareado "
        "bilateral, sem seleção de método pelo diagnóstico de normalidade.", "",
        f"O asterisco marca p ajustado por Holm < 0,05 numa família única de {len(comparisons)} "
        "comparações planejadas (todas as 13 medidas, incluindo cada teto). NI indica inferência não "
        "estimável, inclusive diferenças constantes; nesses casos o p fica vazio. "
        "O asterisco não mede importância prática.", "",
        "Os valores p brutos e ajustados, o IC 95% e os diagnósticos das diferenças estão em "
        "`scenario_vs_reference.csv`.", "",
    ]
    return intro + table(["Cenário / teto", "Δ cobertura nacional (p.p.)", "Δ cobertura efetiva (p.p.)",
                          "Δ déficit nacional (Mm³)", "Δ produção (Mm³)", "Δ FUT (p.p.)"], rows)


def diagnostics_section(comparisons):
    rows = []
    for item in comparisons:
        if item["metric"] != "Cobertura efetiva":
            continue
        sid, ceiling = item["scenario_id"], item["ceiling_pct"]
        label = sid if ceiling is None else f"{sid} — teto {fmt(ceiling, 0)}%"
        rows.append([label, item["n"], fmt(item["delta"]), interval_cell(item),
                     f"{item['p_adjusted_holm']:.3g}" if item["p_adjusted_holm"] is not None else "—",
                     item["diagnostic_flags"]])
    unavailable = sum(r["inference_status"] != "ok" for r in comparisons)
    intro = ["## Diagnósticos da cobertura efetiva", "",
             "A tabela examina as diferenças pareadas, que são a amostra do teste. Os diagnósticos de cada "
             "cenário e teto estão em `statistical_diagnostics.csv`. Nenhuma execução é removida.", "",
             "Alertas: small_sample = menos de 30 pares; strong_skew = distribuição muito assimétrica; "
             "shapiro_p_below_0.05 = distribuição longe da normal; tukey_outliers = pontos muito afastados; "
             "boundary_mass = observações no limite da medida.", ""]
    result = intro + table(["Cenário / teto", "Pares", "Δ (p.p.)", "IC 95%", "p Holm", "Alertas"], rows)
    return result + ["", f"Das {len(comparisons)} comparações planejadas, {unavailable} ficam sem inferência "
                     "porque a diferença é constante.", ""]


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
        "coberta por importação e estoque, que ficam fora do modelo.",
        "",
        "A cobertura efetiva do Histórico é um intervalo, e não um valor único, porque a ANP informa quanto "
        "cada refinaria produziu, mas não quanta gasolina foi levada de uma região para outra. Na simulação, "
        "cada comboio é registrado, então a cobertura efetiva sai exata. O menor valor supõe que nenhuma "
        "região mandou gasolina para outra, e a sobra do Sul e do Sudeste ficou parada. O maior supõe que "
        "toda a sobra chegou onde faltava, e por isso é igual à cobertura nacional. O valor real de 2025 "
        "está entre os dois. Esse intervalo não é um intervalo de confiança: ele não vem da variação dos "
        "sorteios, e sim da falta de dado sobre o transporte, então não diminui com mais execuções.",
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


def ceiling_section(ceiling):
    cells = {(row["ceiling_pct"], row["metric"]): row for row in ceiling}
    ceilings = sorted({row["ceiling_pct"] for row in ceiling})
    places = {"annual_fut_pct": 1, "deficit_days": 0, "deficit_sum_mm3": 3}

    def cell(value, metric):
        result = cells[(value, metric)]
        digits = places.get(metric, 2)
        return f"{fmt(result['mean'], digits)} ± {fmt(result['std'], digits)}"

    rows = [
        [
            fmt(value, 0),
            cells[(value, "annual_fut_pct")]["n"],
            *(cell(value, metric) for metric in CEILING_METRICS),
        ]
        for value in ceilings
    ]
    headers = [
        "Teto (%)", "Execuções", "FUT (%)", "Produção (Mm³)", "Cobertura efetiva (%)",
        "Δ cobertura efetiva (p.p.)", "Déficit nacional (Mm³)", "Dias com falta", "Falta diária somada (Mm³)",
    ]
    intro = [
        "## Mobilidade do FUT por teto",
        "",
        f"Em `{CEILING}`, cada bloco de execuções seguidas tem o mesmo teto de FUT, e a média da tabela anual "
        "mistura tetos diferentes. Aqui cada linha junta as execuções de um teto. Média ± desvio padrão. Δ é a "
        "cobertura efetiva da execução menos a da execução de mesmo número da referência, que tem teto de 100% e "
        "os mesmos rendimentos e taxas de falha. O IC 95% de cada linha está em `scenario_ceiling.csv`.",
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


def seed_line(scenarios):
    seed = scenarios[REFERENCE]["rows"][0]["seed"]
    return [f"Semente `{seed}`. Rodar a bateria com a mesma semente reproduz estes números.", ""]


def report(study, scenarios, monthly, ceiling, comparisons):
    historical = json.loads(HISTORICAL.read_text(encoding="utf-8"))["annual"]
    lines = [
        f"# Análise da bateria `{study.name}`",
        "",
        *seed_line(scenarios),
        f"Cada cenário tem {len(scenarios[REFERENCE]['rows'])} execuções. Média ± desvio padrão (dp) resume as execuções. "
        "IC 95% é o intervalo de confiança de 95% da média, pela distribuição t de Student. "
        "Amostras constantes ficam sem inferência. "
        "Mm³ são milhões de m³ e p.p. são pontos percentuais.",
        "",
    ]
    lines += annual_section(scenarios)
    lines += reference_section(comparisons)
    lines += diagnostics_section(comparisons)
    lines += historical_section(scenarios, historical)
    lines += historical_coverage_section(scenarios, historical)
    lines += daily_section(scenarios)
    lines += ceiling_section(ceiling)
    lines += monthly_section(scenarios, monthly)
    lines += regional_coverage_section(scenarios)
    lines += region_section(scenarios)
    lines += refinery_section(scenarios)
    return "\n".join(lines)


def source_hashes(study):
    sources = [study / "manifest.csv"]
    sources += [(study / row["csv_path"]).resolve() for row in read_csv(study / "manifest.csv")]
    result = {}
    for path in sorted(set(sources)):
        digest = hashlib.sha256()
        with path.open("rb") as handle:
            for block in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(block)
        result[str(path.relative_to(study))] = digest.hexdigest()
    return result


def main():
    parser = argparse.ArgumentParser(description="Analisa uma bateria sem modificar os CSVs de simulação.")
    parser.add_argument("study", nargs="?", help="Pasta da bateria. Sem valor, usa a mais recente.")
    parser.add_argument("--output", type=Path, help="Pasta de saída alternativa; padrão: <bateria>/analysis.")
    args = parser.parse_args()
    study = (Path(args.study) if args.study else max(
        (p for p in STUDIES.iterdir() if (p / "manifest.csv").is_file()),
        key=lambda path: path.stat().st_mtime)).resolve()
    scenarios = collect(study)
    before = source_hashes(study)
    output = (args.output or study / "analysis").resolve()
    # Generated files must never collide with a simulation CSV, even with --output.
    if output == study or any(output == (study / r["csv_path"]).resolve().parent
                              for group in scenarios.values() for r in group["rows"]):
        raise ValueError("Output must be separate from simulation data directories")
    output.mkdir(parents=True, exist_ok=True)
    comparisons = reference_rows(scenarios)
    diagnostic = diagnostic_rows(scenarios)
    monthly = monthly_rows(scenarios)
    write_csv(output / "scenario_annual.csv", annual_rows(scenarios))
    write_csv(output / "scenario_vs_reference.csv", comparisons)
    write_csv(output / "statistical_diagnostics.csv", diagnostic)
    write_csv(output / "scenario_daily.csv", daily_rows(scenarios))
    write_csv(output / "scenario_monthly.csv", monthly)
    write_csv(output / "scenario_refineries.csv", entity_rows(scenarios, "plants", "refinery_id", PLANT))
    write_csv(output / "scenario_regions.csv", entity_rows(scenarios, "regions", "region", REGION))
    ceiling = ceiling_rows(scenarios)
    write_csv(output / "scenario_ceiling.csv", ceiling)
    text = report(study, scenarios, monthly, ceiling, comparisons)
    (output / "report.md").write_text(text + "\n", encoding="utf-8")
    after = source_hashes(study)
    if before != after:
        raise RuntimeError("Simulation inputs changed during analysis; generated results must be discarded")
    metadata = {
        "study": study.name, "analysis_version": 2, "simulation_inputs_unchanged": True,
        "input_sha256": before, "confidence": CONFIDENCE,
        "comparison_method": "paired_t", "p_adjustment": "holm",
        "family_size": len(comparisons), "estimable_tests": sum(r["p_value"] is not None for r in comparisons),
        "ci_scope": "pointwise, not simultaneous",
        "code_sha256": {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                        for path in (Path(__file__), Path(inference.__file__))},
        "python": platform.python_version(), "numpy": np.__version__, "scipy": scipy.__version__,
    }
    (output / "analysis_metadata.json").write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Análise gravada em {output}; {len(before)} arquivos de simulação preservados; "
          f"{len(comparisons)} comparações planejadas.")


if __name__ == "__main__":
    main()
