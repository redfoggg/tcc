"""Inference across independent runs; related scenarios are compared within run."""

import hashlib
import warnings
from functools import lru_cache

import numpy as np
from scipy import stats

CONFIDENCE = 0.95
ALPHA = 1 - CONFIDENCE
BOOTSTRAP_RESAMPLES = 9999
BOOTSTRAP_SEED = 20261022


def sample(values):
    data = np.asarray(values, dtype=float)
    if data.ndim != 1 or data.size == 0 or not np.all(np.isfinite(data)):
        raise ValueError("Expected a nonempty, finite, one-dimensional sample")
    return data


def constant(data, scale=None):
    data = sample(data)
    magnitude = max(float(np.max(np.abs(data))), np.finfo(float).tiny) if scale is None else scale
    return bool(np.ptp(data) <= 16 * np.finfo(float).eps * magnitude)


def configure(resamples, seed):
    if not 99 <= resamples <= 1_000_000 or seed < 0:
        raise ValueError("Bootstrap requires 99..1000000 resamples and a nonnegative seed")
    global BOOTSTRAP_RESAMPLES, BOOTSTRAP_SEED
    BOOTSTRAP_RESAMPLES, BOOTSTRAP_SEED = resamples, seed
    _summary.cache_clear()


def descriptive(values):
    data = sample(values)
    mean = float(np.mean(data))
    std = float(np.std(data, ddof=1)) if data.size > 1 else None
    return {
        "n": int(data.size), "mean": mean, "std": std,
        "sem": std / np.sqrt(data.size) if std is not None else None,
        "cv": std / abs(mean) if std is not None and mean else None,
        "min": float(np.min(data)), "max": float(np.max(data)),
        "median": float(np.median(data)),
        "q025": float(np.quantile(data, 0.025)), "q975": float(np.quantile(data, 0.975)),
    }


def diagnostics(values, bounds=None):
    data = sample(values)
    degenerate = constant(data)
    q1, q3 = np.quantile(data, [0.25, 0.75])
    iqr = q3 - q1
    outliers = int(np.count_nonzero((data < q1 - 1.5 * iqr) | (data > q3 + 1.5 * iqr)))
    shapiro = stats.shapiro(data) if data.size >= 3 and not degenerate else None
    skew = float(stats.skew(data, bias=False)) if data.size >= 3 and not degenerate else None
    kurtosis = float(stats.kurtosis(data, bias=False)) if data.size >= 4 and not degenerate else None
    low = int(np.count_nonzero(np.isclose(data, bounds[0], atol=1e-10, rtol=0))) if bounds else None
    high = int(np.count_nonzero(np.isclose(data, bounds[1], atol=1e-10, rtol=0))) if bounds else None
    if bounds and (np.any(data < bounds[0] - 1e-10) or np.any(data > bounds[1] + 1e-10)):
        raise ValueError("Observed value outside the metric's bounds")
    flags = []
    if data.size < 30:
        flags.append("small_sample")
    if degenerate:
        flags.append("constant_sample")
    if shapiro is not None and shapiro.pvalue < ALPHA:
        flags.append("shapiro_p_below_0.05")
    if skew is not None and abs(skew) > 1:
        flags.append("strong_skew")
    if outliers:
        flags.append("tukey_outliers")
    if (low or 0) + (high or 0):
        flags.append("boundary_mass")
    return {
        "skewness": skew, "excess_kurtosis": kurtosis,
        "shapiro_w": float(shapiro.statistic) if shapiro is not None else None,
        "shapiro_p": float(shapiro.pvalue) if shapiro is not None else None,
        "tukey_outliers": outliers, "at_lower_bound": low, "at_upper_bound": high,
        "diagnostic_flags": ";".join(flags) or "none",
    }


def summary(values, inferential=True):
    return dict(_summary(tuple(sample(values)), inferential))


@lru_cache(maxsize=8192)
def _summary(values, inferential):
    data = sample(values)
    result = descriptive(data)
    result.update({"ci95_low": None, "ci95_high": None,
                   "bootstrap_ci95_low": None, "bootstrap_ci95_high": None,
                   "bootstrap_status": "not_estimated"})
    status = "ok"
    if not inferential:
        result["sem"] = None
        status = "mixed_conditions_descriptive_only"
    elif data.size < 2:
        status = "insufficient_sample"
    elif constant(data):
        status = "constant_sample_no_inference"
    if status != "ok":
        return {**result, "inference_status": status}
    low, high = stats.t.interval(CONFIDENCE, data.size - 1, loc=result["mean"], scale=result["sem"])
    # Resample centered observations to reduce cancellation for nearly constant metrics.
    centered = data - result["mean"]
    digest = hashlib.sha256(np.asarray(data, dtype="<f8").tobytes()).digest()
    rng = np.random.default_rng(np.random.SeedSequence([BOOTSTRAP_SEED, int.from_bytes(digest[:8], "little")]))
    with warnings.catch_warnings(record=True) as caught:
        warnings.simplefilter("always", stats.DegenerateDataWarning)
        boot = stats.bootstrap((centered,), np.mean, confidence_level=CONFIDENCE,
                               n_resamples=BOOTSTRAP_RESAMPLES, batch=256,
                               method="BCa", rng=rng)
    boot_low, boot_high = np.asarray(boot.confidence_interval) + result["mean"]
    boot_ok = np.isfinite([boot_low, boot_high]).all() and not caught
    return {**result, "ci95_low": float(low), "ci95_high": float(high),
            "bootstrap_ci95_low": float(boot_low) if boot_ok else None,
            "bootstrap_ci95_high": float(boot_high) if boot_ok else None,
            "bootstrap_status": "ok" if boot_ok else "bca_not_estimable",
            "inference_status": status}


def difference(values, reference):
    left, right = sample(values), sample(reference)
    if left.shape != right.shape:
        raise ValueError("Paired samples must have equal lengths")
    delta = left - right
    scale = max(float(np.max(np.abs(left))), float(np.max(np.abs(right))), np.finfo(float).tiny)
    result = summary(delta, inferential=not constant(delta, scale))
    result.update(diagnostics(delta))
    result.update({"delta": result.pop("mean"), "method": "paired_t",
                   "t_statistic": None, "degrees_of_freedom": None,
                   "p_value": None, "bootstrap_excludes_zero": None,
                   "ci_direction_agreement": None})
    if constant(delta, scale):
        result["inference_status"] = "constant_differences_no_inference"
        result["diagnostic_flags"] = "constant_differences"
        return result
    if left.size < 2:
        return result
    test = stats.ttest_rel(left, right)
    if not np.isfinite([test.statistic, test.pvalue]).all():
        result["inference_status"] = "numerical_failure_no_inference"
        return result
    result.update({"t_statistic": float(test.statistic), "degrees_of_freedom": int(left.size - 1),
                   "p_value": float(test.pvalue)})
    if result["bootstrap_status"] == "ok":
        def direction(low, high):
            return 1 if low > 0 else -1 if high < 0 else 0
        bdir = direction(result["bootstrap_ci95_low"], result["bootstrap_ci95_high"])
        result["bootstrap_excludes_zero"] = bool(bdir)
        result["ci_direction_agreement"] = bdir == direction(result["ci95_low"], result["ci95_high"])
    return result


def holm(rows):
    """One planned family, including non-estimable hypotheses in its size.

    Missing p-values occupy the last positions and cannot be rejected.
    """
    m = len(rows)
    valid = sorted((r["p_value"], i) for i, r in enumerate(rows) if r["p_value"] is not None)
    adjusted, previous = {}, 0.0
    for rank, (p, index) in enumerate(valid):
        if not 0 <= p <= 1:
            raise ValueError("Invalid p-value")
        previous = max(previous, min(1.0, (m - rank) * p))
        adjusted[index] = previous
    return [{**row, "p_adjusted_holm": adjusted.get(i),
             "significant": adjusted.get(i, 1.0) < ALPHA,
             "family_size": m, "adjustment": "holm"} for i, row in enumerate(rows)]
