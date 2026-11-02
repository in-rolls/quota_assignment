"""Known-truth validation, including quota-conditioned stress tests."""

from pathlib import Path

import numpy as np
import pandas as pd
from scipy.special import expit

from .model import fit, variance_partition


def simulate(
    seed=1, heterogeneous=True, quota=False, districts=6, blocks=5, gp_scale=0.0
):
    rng = np.random.default_rng(seed)
    rows, truth = [], []
    district_slopes = (
        rng.normal(0, 0.6, districts) if heterogeneous else np.zeros(districts)
    )
    for d in range(districts):
        for b in range(blocks):
            size = int(rng.integers(12, 100))
            slope = (
                -0.8 + district_slopes[d] + (rng.normal(0, 0.5) if heterogeneous else 0)
            )
            previous = rng.binomial(1, 0.4, size)
            initial = previous.copy()
            gp_effect = rng.normal(0, gp_scale, size)
            for t in range(3):
                prob = expit(-0.2 + 0.15 * t + slope * previous + gp_effect)
                current = rng.binomial(1, prob)
                if quota:
                    # Conditional Bernoulli with fixed count via elementary symmetric
                    # sums.
                    odds = prob / (1 - prob)
                    k = round(size * 0.4)
                    table = np.zeros((size + 1, k + 1))
                    table[:, 0] = 1
                    for i in range(1, size + 1):
                        for j in range(1, min(i, k) + 1):
                            table[i, j] = (
                                table[i - 1, j] + odds[i - 1] * table[i - 1, j - 1]
                            )
                    current = np.zeros(size, dtype=int)
                    left = k
                    for i in range(size, 0, -1):
                        if (
                            left
                            and rng.random()
                            < odds[i - 1] * table[i - 1, left - 1] / table[i, left]
                        ):
                            current[i - 1] = 1
                            left -= 1
                for g in range(size):
                    rows.append(
                        dict(
                            transition=str(t),
                            district=str(d),
                            block_id=f"{d}/{b}",
                            gp_id=f"{d}/{b}/{g}",
                            previous=int(previous[g]),
                            current=int(current[g]),
                            initial=int(initial[g]),
                            reserved_caste="NONE",
                            reserved_caste_previous="NONE",
                        )
                    )
                truth.append(
                    dict(
                        transition=str(t),
                        district=str(d),
                        delta=prob[previous == 1].mean() - prob[previous == 0].mean(),
                    )
                )
                previous = current
    return pd.DataFrame(rows), pd.DataFrame(truth)


def validate(out, replicates=20, draws=1000, tune=1000, districts=6, blocks=5):
    out = Path(out)
    results = []
    for scenario, hetero, quota, gp_scale in [
        ("homogeneous", False, False, 0.0),
        ("heterogeneous", True, False, 0.0),
        ("fixed_quota_stress", True, True, 0.0),
        ("persistent_gp", True, False, 0.6),
    ]:
        for r in range(replicates):
            dest = out / scenario / str(r)
            dest.mkdir(parents=True, exist_ok=True)
            p, truth = simulate(
                20261101 + r,
                hetero,
                quota,
                districts=districts,
                blocks=blocks,
                gp_scale=gp_scale,
            )
            p.to_parquet(dest / "panel.parquet")
            truth.to_csv(dest / "truth.csv", index=False)
            try:
                fit(
                    dest / "panel.parquet",
                    dest,
                    draws=draws,
                    tune=tune,
                    seed=20261101 + r,
                )
                estimates = pd.read_csv(dest / "heterogeneity.csv")
                for transition, g in truth.groupby("transition"):
                    total, _, _ = variance_partition(
                        g.delta.to_numpy(), g.district.to_numpy()
                    )
                    estimate = estimates[
                        (estimates.transition.astype(str) == transition)
                        & estimates.weighting.eq("equal_blocks")
                        & estimates.metric.eq("total_sd")
                    ].iloc[0]
                    target = float(np.sqrt(total))
                    # Under quotas this is a generating-logit contrast, not the marginal
                    # truth.
                    results.append(
                        dict(
                            scenario=scenario,
                            replicate=r,
                            transition=transition,
                            target=target,
                            estimate=estimate["median"],
                            lower=estimate.lower,
                            upper=estimate.upper,
                            coverage=(estimate.lower <= target <= estimate.upper)
                            if not quota and target > 1e-10
                            else np.nan,
                            error="",
                        )
                    )
            except Exception as exc:
                results.append(dict(scenario=scenario, replicate=r, error=repr(exc)))
            pd.DataFrame(results).to_csv(out / "validation.csv", index=False)
    valid = pd.DataFrame(results).reindex(
        columns=[
            "scenario",
            "replicate",
            "transition",
            "target",
            "estimate",
            "lower",
            "upper",
            "coverage",
            "error",
        ]
    )
    valid["error_value"] = valid.get("estimate") - valid.get("target")
    summary = valid.groupby("scenario").agg(
        completed_transition_estimates=("estimate", "count"),
        bias=("error_value", "mean"),
        coverage=("coverage", "mean"),
    )
    summary["completed_replicates"] = (
        valid[valid.error.eq("")].groupby("scenario").replicate.nunique()
    )
    summary["attempted_replicates"] = valid.groupby("scenario").replicate.nunique()
    summary.to_csv(out / "validation_summary.csv")


def benchmark(panel, out, replicates=1000, seed=20261101):
    """Common transition probabilities, observed lag groups and sample sizes fixed."""
    rng = np.random.default_rng(seed)
    p = pd.read_parquet(panel)
    results = []
    for transition, g in p.groupby("transition"):
        rates = g.groupby("previous").current.mean()
        if len(rates) != 2:
            continue
        counts = (
            g.groupby(["block_id", "previous"]).current.agg(["sum", "count"]).unstack()
        )
        counts = counts.dropna()
        n0, n1 = counts["count"][0].to_numpy(), counts["count"][1].to_numpy()
        observed = np.std(counts["sum"][1] / n1 - counts["sum"][0] / n0)
        for r in range(replicates):
            delta = (
                rng.binomial(n1.astype(int), rates[1]) / n1
                - rng.binomial(n0.astype(int), rates[0]) / n0
            )
            results.append(
                dict(
                    transition=transition,
                    replicate=r,
                    sd=float(np.std(delta)),
                    observed_raw_sd=float(observed),
                    blocks=len(n0),
                )
            )
    pd.DataFrame(results).to_csv(out, index=False)
