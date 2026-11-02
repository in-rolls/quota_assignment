"""Hierarchical descriptive transition model and probability-scale estimands."""

import json
from pathlib import Path

import arviz as az
import numpy as np
import pandas as pd
import pymc as pm
from scipy.special import expit


def encode(p):
    indices, levels = {}, {}
    for col in ["transition", "district", "block_id", "gp_id"]:
        indices[col], levels[col] = pd.factorize(p[col], sort=True)
    return indices, levels


def make_model(p, scale=0.5, adjusted=False):
    idx, levels = encode(p)
    coords = {k: list(v) for k, v in levels.items()}
    coords["coefficient"] = ["intercept", "lag"]
    if adjusted:
        p = p.copy()
        p["category"] = p.reserved_caste_previous + "→" + p.reserved_caste
        idx["category"], levels["category"] = pd.factorize(p.category, sort=True)
        coords["category"] = list(levels["category"])
    with pm.Model(coords=coords) as model:
        base = pm.Normal("base", 0, 1.5, dims=("transition", "coefficient"))
        coef = base[idx["transition"]]
        for name in ["district", "block_id"]:
            sd = pm.HalfNormal(f"sd_{name}", scale, dims="coefficient")
            z = pm.Normal(f"z_{name}", 0, 1, dims=(name, "transition", "coefficient"))
            effect = pm.Deterministic(
                f"effect_{name}", z * sd, dims=(name, "transition", "coefficient")
            )
            coef = coef + effect[idx[name], idx["transition"]]
        gp_sd = pm.HalfNormal("sd_gp", scale)
        gp_z = pm.Normal("z_gp", 0, 1, dims="gp_id")
        initial = pm.Normal("initial_association", 0, 1)
        eta = (
            coef[:, 0]
            + coef[:, 1] * p.previous.to_numpy()
            + gp_sd * gp_z[idx["gp_id"]]
            + initial * p.initial.to_numpy()
        )
        if adjusted:
            cat = pm.Normal("category_effect", 0, 1, dims=("category", "coefficient"))
            eta = (
                eta
                + cat[idx["category"], 0]
                + cat[idx["category"], 1] * p.previous.to_numpy()
            )
        pm.Bernoulli("outcome", logit_p=eta, observed=p.current.to_numpy())
    return model, idx, levels


def variance_partition(values, districts, weights=None):
    """Law of total variance, including district weights implied by block weights."""
    w = np.ones(len(districts)) if weights is None else np.asarray(weights, float)
    w = w / w.sum()
    mean = np.sum(values * w, axis=-1)
    total = np.sum((values - mean[..., None]) ** 2 * w, axis=-1)
    between = np.zeros_like(total)
    for district in np.unique(districts):
        mask = districts == district
        mass = w[mask].sum()
        dm = np.sum(values[..., mask] * w[mask], axis=-1) / mass
        between += mass * (dm - mean) ** 2
    return total, between, np.maximum(total - between, 0)


def summarize(p, idata, dest, adjusted=False):
    idx, levels = encode(p)
    post = idata.posterior.stack(sample=("chain", "draw"))

    def draws(name):
        x = post[name]
        return x.transpose("sample", *[d for d in x.dims if d != "sample"]).values

    base, de, be = [draws(n) for n in ["base", "effect_district", "effect_block_id"]]
    gp_sd, initial = draws("sd_gp"), draws("initial_association")
    gp_effects = draws("z_gp") * gp_sd[:, None]
    gp_lookup = {g: i for i, g in enumerate(levels["gp_id"])}
    rows, distributions, block_orders = [], {}, {}
    category_levels = None
    if adjusted:
        cats = p.reserved_caste_previous + "→" + p.reserved_caste
        category_levels = sorted(cats.unique())
        cat_effect = draws("category_effect")
    for t, transition in enumerate(levels["transition"]):
        pt = p[p.transition.eq(transition)]
        values, districts, sizes, block_names = [], [], [], []
        for b, block in enumerate(levels["block_id"]):
            subset = pt[pt.block_id.eq(block)]
            if subset.empty:
                continue
            district = subset.district.iloc[0]
            d = list(levels["district"]).index(district)
            coef = base[:, t] + de[:, d, t] + be[:, b, t]
            if subset.previous.nunique() != 2:
                continue
            groups = [(subset, 1.0)]
            if adjusted:
                local = subset.assign(
                    category=subset.reserved_caste_previous
                    + "→"
                    + subset.reserved_caste
                )
                support = local.groupby("category").previous.nunique()
                required = set(
                    (pt.reserved_caste_previous + "→" + pt.reserved_caste).unique()
                )
                if not required.issubset(set(support[support.eq(2)].index)):
                    continue
                freq = (
                    pt.reserved_caste_previous + "→" + pt.reserved_caste
                ).value_counts(normalize=True)
                groups = [
                    (local[local.category.eq(c)], mass) for c, mass in freq.items()
                ]
            delta = np.zeros(len(coef))
            for group, mass in groups:
                c = coef.copy()
                if adjusted:
                    c += cat_effect[:, category_levels.index(group.category.iloc[0])]
                for lag, sign in [(0, -1), (1, 1)]:
                    g = group[group.previous.eq(lag)]
                    positions = [gp_lookup[x] for x in g.gp_id]
                    eta = (
                        c[:, 0, None]
                        + c[:, 1, None] * lag
                        + initial[:, None] * g.initial.to_numpy()
                        + gp_effects[:, positions]
                    )
                    delta += mass * sign * expit(eta).mean(axis=1)
            values.append(delta)
            block_names.append(block)
            districts.append(district)
            sizes.append(len(subset))
            lo, median, hi = np.quantile(delta, [0.025, 0.5, 0.975])
            rows.append(
                dict(
                    transition=transition,
                    district=district,
                    block_id=block,
                    n=len(subset),
                    previous_0=int(subset.previous.eq(0).sum()),
                    previous_1=int(subset.previous.eq(1).sum()),
                    lower=lo,
                    median=median,
                    upper=hi,
                )
            )
        if not values:
            continue
        block_orders[transition] = block_names
        distributions[transition] = (
            np.array(values).T,
            np.array(districts),
            np.array(sizes),
        )
    if len(distributions) == len(levels["transition"]):
        common = sorted(set.intersection(*(set(v) for v in block_orders.values())))
        if common:
            arrays, counts = [], []
            for transition, (v, d, n) in distributions.items():
                order = [block_orders[transition].index(b) for b in common]
                arrays.append(v[:, order])
                counts.append(n[order])
            districts = np.array(
                [p.loc[p.block_id.eq(b), "district"].iloc[0] for b in common]
            )
            distributions["equal_transition_average_common_blocks"] = (
                np.mean(arrays, axis=0),
                districts,
                np.sum(counts, axis=0),
            )
    pd.DataFrame(
        rows,
        columns=[
            "transition",
            "district",
            "block_id",
            "n",
            "previous_0",
            "previous_1",
            "lower",
            "median",
            "upper",
        ],
    ).to_csv(dest / "block_contrasts.csv", index=False)
    summaries = []
    for transition, (v, d, n) in distributions.items():
        for label, w in [("equal_blocks", None), ("equal_seats", n)]:
            total, between, within = variance_partition(v, d, w)
            for metric, draws_ in [
                ("total_sd", np.sqrt(total)),
                ("between_district_sd", np.sqrt(between)),
                ("within_district_sd", np.sqrt(within)),
                (
                    "district_share",
                    np.divide(
                        between,
                        total,
                        out=np.full_like(total, np.nan),
                        where=total > 1e-12,
                    ),
                ),
            ]:
                lo, med, hi = (
                    np.nanquantile(draws_, [0.025, 0.5, 0.975])
                    if np.isfinite(draws_).any()
                    else [np.nan] * 3
                )
                summaries.append(
                    dict(
                        transition=transition,
                        weighting=label,
                        metric=metric,
                        lower=lo,
                        median=med,
                        upper=hi,
                    )
                )
    pd.DataFrame(
        summaries,
        columns=["transition", "weighting", "metric", "lower", "median", "upper"],
    ).to_csv(dest / "heterogeneity.csv", index=False)
    return distributions


def fit(
    panel_path,
    dest,
    draws=1000,
    tune=1000,
    chains=4,
    seed=20261101,
    scale=0.5,
    adjusted=False,
    complete_history=False,
):
    dest = Path(dest)
    dest.mkdir(parents=True, exist_ok=True)
    p = pd.read_parquet(panel_path)
    for col in ["reserved_caste", "reserved_caste_previous"]:
        p[col] = p[col].astype("string")
    if adjusted:
        p = p.dropna(subset=["reserved_caste", "reserved_caste_previous"])
    if complete_history:
        expected = p.transition.nunique()
        p = p[p.groupby("gp_id").transition.transform("nunique").eq(expected)]
    if p.empty:
        raise ValueError("No observations meet analysis restrictions")
    p = p.reset_index(drop=True)
    model, _, _ = make_model(p, scale, adjusted)
    with model:
        prior = pm.sample_prior_predictive(samples=100, random_seed=seed)
        idata = pm.sample(
            draws=draws,
            tune=tune,
            chains=chains,
            cores=min(chains, 4),
            blas_cores=min(chains, 4),
            target_accept=0.95,
            random_seed=seed,
        )
        pm.sample_posterior_predictive(
            idata, random_seed=seed, extend_inferencedata=True
        )
    idata.to_netcdf(dest / "posterior.nc")
    prior.to_netcdf(dest / "prior.nc")
    diagnostics = az.summary(idata, kind="diagnostics")
    diagnostics.to_csv(dest / "diagnostics.csv")
    passed = (
        chains >= 4
        and diagnostics.r_hat.le(1.01).all()
        and diagnostics.ess_bulk.ge(400).all()
        and diagnostics.ess_tail.ge(400).all()
        and int(idata.sample_stats.diverging.sum()) == 0
    )
    import hashlib

    settings = dict(
        draws=draws,
        tune=tune,
        chains=chains,
        seed=seed,
        scale=scale,
        adjusted=adjusted,
        complete_history=complete_history,
        observations=len(p),
        diagnostics_passed=bool(passed),
        panel_sha256=hashlib.sha256(Path(panel_path).read_bytes()).hexdigest(),
    )
    (dest / "settings.json").write_text(json.dumps(settings, indent=2) + "\n")
    summarize(p, idata, dest, adjusted)
    checks = []
    for group, g in p.groupby(["transition", "previous"]):
        indices = p.index.get_indexer(g.index)
        for label, arr in [
            ("prior", prior.prior_predictive.outcome.values),
            ("posterior", idata.posterior_predictive.outcome.values),
        ]:
            rates = arr[..., indices].mean(axis=-1).ravel()
            checks.append(
                dict(
                    transition=group[0],
                    previous=int(group[1]),
                    kind=label,
                    observed=g.current.mean(),
                    lower=float(np.quantile(rates, 0.025)),
                    upper=float(np.quantile(rates, 0.975)),
                )
            )
    pd.DataFrame(checks).to_csv(dest / "predictive_checks.csv", index=False)
    return idata
