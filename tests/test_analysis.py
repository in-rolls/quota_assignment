import numpy as np
import pandas as pd
import pytest

from reservation_patterns.data import panel
from reservation_patterns.model import make_model, variance_partition
from reservation_patterns.simulation import simulate


def fixture():
    return pd.DataFrame(
        [
            dict(
                year=y,
                tier="gp_head",
                district="D",
                block="B",
                gram_panchayat=g,
                reserved_woman=w,
                election_type=None,
            )
            for y in [2005, 2010, 2015, 2020]
            for g, w in [("A", 1), ("B", 0)]
        ]
    )


def test_linkage_conservation():
    p, records, links = panel(fixture(), "rajasthan")
    assert len(p) == 6
    assert len(records) == 8
    assert links._merge.eq("both").all()
    assert not p.duplicated(["gp_id", "transition"]).any()


def test_unknown_duplicate_and_gap():
    d = fixture()
    d.loc[(d.year == 2010) & (d.gram_panchayat == "A"), "reserved_woman"] = np.nan
    d = pd.concat([d, d.iloc[[0]]], ignore_index=True)
    p, records, _ = panel(d, "rajasthan")
    assert records.exclusion.eq("ambiguous_key").sum() == 2
    assert records.exclusion.eq("missing_reservation").sum() == 1
    assert len(p[p.gram_panchayat == "a"]) == 1


def test_partition_identity_and_weights():
    x = np.array([[0.0, 1.0, 3.0]])
    d = np.array(["a", "a", "b"])
    total, between, within = variance_partition(x, d)
    np.testing.assert_allclose(total, between + within)
    np.testing.assert_allclose(total, np.var(x, axis=1))
    np.testing.assert_allclose(within, [1 / 6])
    assert variance_partition(x, d, [1, 1, 10])[0] != total


def test_bad_status_rejected():
    d = fixture()
    d.loc[0, "reserved_woman"] = 2
    with pytest.raises(ValueError):
        panel(d, "rajasthan")


def test_model_finite_and_quota():
    p, _ = simulate(districts=2, blocks=2, quota=True)
    for _, g in p.groupby(["transition", "block_id"]):
        assert g.current.sum() == round(len(g) * 0.4)
    model, _, _ = make_model(p)
    assert np.isfinite(model.compile_logp()(model.initial_point()))


def test_conditional_contrast_preserves_initial_history(tmp_path):
    import arviz as az
    from scipy.special import expit

    from reservation_patterns.model import summarize

    p = pd.DataFrame(
        dict(
            transition=["t", "t"],
            district=["d", "d"],
            block_id=["b", "b"],
            gp_id=["g0", "g1"],
            previous=[0, 1],
            current=[0, 1],
            initial=[0, 1],
        )
    )
    idata = az.from_dict(
        posterior={
            "base": np.zeros((2, 3, 1, 2)),
            "effect_district": np.zeros((2, 3, 1, 1, 2)),
            "effect_block_id": np.zeros((2, 3, 1, 1, 2)),
            "sd_gp": np.zeros((2, 3)),
            "z_gp": np.zeros((2, 3, 2)),
            "initial_association": np.full((2, 3), 2.0),
        }
    )
    summarize(p, idata, tmp_path)
    result = pd.read_csv(tmp_path / "block_contrasts.csv")
    np.testing.assert_allclose(result["median"], expit(2) - 0.5)
    p.previous = 0
    summarize(p, idata, tmp_path)
    assert pd.read_csv(tmp_path / "block_contrasts.csv").empty
    assert pd.read_csv(tmp_path / "heterogeneity.csv").empty


def test_all_simulation_failures_recorded(tmp_path, monkeypatch):
    import reservation_patterns.simulation as simulation

    def fail(*args, **kwargs):
        raise RuntimeError("deliberate test failure")

    monkeypatch.setattr(simulation, "fit", fail)
    simulation.validate(tmp_path, replicates=1)
    failures = pd.read_csv(tmp_path / "validation.csv")
    assert len(failures) == 4
    assert failures.error.str.contains("deliberate").all()
    summary = pd.read_csv(tmp_path / "validation_summary.csv")
    assert summary.completed_transition_estimates.eq(0).all()
