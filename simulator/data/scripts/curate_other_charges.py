"""Split ANP atmospheric charge into petroleum and other charges.

Rewrites the charge columns of the curated 2025 capacity file and the
historical summary. Petroleum is national plus imported. Other charges stay
in the FUT numerator and out of the gasoline yield denominator.

Reads data/original and data/curated. Does not download.
"""

import csv
import json
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ORIGINAL = ROOT / "data" / "original"
CURATED = ROOT / "data" / "curated"

MONTHS = {
    "JAN": "01",
    "FEV": "02",
    "MAR": "03",
    "ABR": "04",
    "MAI": "05",
    "JUN": "06",
    "JUL": "07",
    "AGO": "08",
    "SET": "09",
    "OUT": "10",
    "NOV": "11",
    "DEZ": "12",
}
NAMES = {"3R POTIGUAR (ex-RPCC)": "RPCC"}
SCOPE = {
    "REAM",
    "RECAP",
    "REDUC",
    "REFAP",
    "REFMAT",
    "REGAP",
    "REPAR",
    "REPLAN",
    "REVAP",
    "RNEST",
    "RPBC",
    "RPCC",
}


def number(value):
    return float((value or "0").replace(",", "."))


def code_of(name):
    return NAMES.get(name, name)


def month_of(label):
    return f"2025-{MONTHS[label]}"


def read_charge():
    path = ORIGINAL / "processamento-petroleo-m3-1990-2025.csv"
    charge = defaultdict(lambda: defaultdict(float))
    with path.open(encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle, delimiter=";"):
            if row["ANO"] != "2025":
                continue
            key = (code_of(row["REFINARIA"]), month_of(row["MÊS"]))
            charge[key][row["MATÉRIA PRIMA"]] += number(row["PROCESSADO"])
    return charge


def read_gasoline():
    path = ORIGINAL / "producao-derivados-petroleo-por-refinaria-m3-1990-2025.csv"
    gasoline = defaultdict(float)
    with path.open(encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle, delimiter=";"):
            if row["ANO"] != "2025" or row["PRODUTO"] != "GASOLINA A":
                continue
            key = (code_of(row["REFINARIA"]), month_of(row["MÊS"]))
            gasoline[key] += number(row["PRODUÇÃO"])
    return gasoline


def petroleum_of(parts):
    return parts["PETRÓLEO NACIONAL"] + parts["PETRÓLEO IMPORTADO"]


def national_yields(charge, gasoline):
    numer = defaultdict(float)
    denom = defaultdict(float)
    for (refinery, month), parts in charge.items():
        numer[month] += gasoline[(refinery, month)]
        denom[month] += petroleum_of(parts)
    return {month: numer[month] / denom[month] for month in denom}


def rewrite_capacity(charge, yields):
    path = CURATED / "anp_2025_refinery_capacity_monthly.csv"
    with path.open(newline="") as handle:
        reader = csv.DictReader(handle)
        fields = list(reader.fieldnames)
        rows = list(reader)

    insert_at = fields.index("utilized_throughput_provenance") + 1
    for column in (
        "petroleum_throughput_m3",
        "petroleum_throughput_provenance",
        "other_charges_m3",
        "other_charges_provenance",
    ):
        if column not in fields:
            fields.insert(insert_at, column)
            insert_at += 1

    scope_petroleum = defaultdict(float)
    scope_other = defaultdict(float)

    for row in rows:
        key = (row["refinery_code"], row["month"])
        parts = charge[key]
        petroleum = petroleum_of(parts)
        other = parts["OUTRAS CARGAS"]
        utilized = float(row["utilized_throughput_m3"])
        if abs(petroleum + other - utilized) > 0.5:
            raise SystemExit(f"charge split does not match utilized throughput for {key}")
        row["petroleum_throughput_m3"] = f"{petroleum:.1f}"
        row["petroleum_throughput_provenance"] = "observed"
        row["other_charges_m3"] = f"{other:.1f}"
        row["other_charges_provenance"] = "observed"
        park_yield = yields[row["month"]]
        row["national_avg_gasoline_a_yield_used"] = f"{park_yield:.6f}"
        capacity = float(row["capacity_m3_month"])
        row["capacity_gasoline_a_m3_month"] = f"{capacity * park_yield:.3f}"
        if row["refinery_code"] in SCOPE:
            scope_petroleum[row["month"]] += petroleum
            scope_other[row["month"]] += other

    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

    return scope_petroleum, scope_other


def rewrite_historical(scope_petroleum, scope_other):
    path = CURATED / "historical_2025_summary.json"
    summary = json.loads(path.read_text())
    annual_petroleum = 0.0
    annual_other = 0.0

    for month in summary["months"]:
        petroleum = scope_petroleum[month["month"]]
        other = scope_other[month["month"]]
        month["petroleum_processed_m3"] = petroleum
        month["other_charges_m3"] = other
        annual_petroleum += petroleum
        annual_other += other

    summary["annual"]["petroleum_processed_m3"] = annual_petroleum
    summary["annual"]["other_charges_m3"] = annual_other
    summary["schema_version"] = "4.0.0"
    summary["provenance"]["petroleum_processed"] = (
        "Sum of ANP national and imported petroleum in the 12-refinery scope. "
        "Excludes other charges."
    )
    summary["provenance"]["other_charges"] = (
        "Sum of ANP OUTRAS CARGAS in the 12-refinery scope: petroleum residues, "
        "terminal residues, and derivative residues reprocessed in atmospheric distillation."
    )
    summary["provenance"]["total_fut_pct"] = (
        "Ratio-of-sums total FUT: 100 times observed atmospheric distillation charge "
        "(petroleum plus other charges) across the fixed 12-refinery scope, divided by "
        "raw monthly processing capacity across the same scope. Never an arithmetic mean "
        "of individual refinery FUT."
    )
    summary["provenance"]["aggregation"] = (
        "Annual volumes are precomputed sums of the twelve monthly values. Annual total "
        "FUT is the ratio of annual atmospheric charge to annual processing capacity, "
        "not a mean of the twelve monthly total FUT percentages."
    )
    path.write_text(json.dumps(summary, indent=2) + "\n")


def main():
    charge = read_charge()
    yields = national_yields(charge, read_gasoline())
    scope_petroleum, scope_other = rewrite_capacity(charge, yields)
    rewrite_historical(scope_petroleum, scope_other)


if __name__ == "__main__":
    main()
