"""Conservative exact linkage with an auditable exclusion ledger."""

import hashlib
import json
import subprocess
import unicodedata
from pathlib import Path

import pandas as pd

CYCLES = {
    "rajasthan": [2005, 2010, 2015, 2020],
    "uttar_pradesh": [2005, 2010, 2015, 2021],
}
KEY = ["district", "block", "gram_panchayat"]


def normalized(value):
    if pd.isna(value):
        return ""
    return " ".join(unicodedata.normalize("NFC", str(value)).casefold().split())


def panel(frame, state):
    d = frame.copy()
    d["year"] = pd.to_numeric(d.year, errors="raise").astype(int)
    d = d[(d.tier == "gp_head") & d.year.isin(CYCLES[state])].copy()
    for col in KEY:
        d[col + "_raw"] = d[col]
        d[col] = d[col].map(normalized)
    d["exclusion"] = ""
    d.loc[d[KEY].eq("").any(axis=1), "exclusion"] = "missing_geography"
    d.loc[d.duplicated(KEY + ["year"], keep=False), "exclusion"] = "ambiguous_key"
    d.loc[
        d.election_type.astype("string").fillna("").str.contains("by", case=False),
        "exclusion",
    ] = "by_election"
    d["reserved_woman"] = pd.to_numeric(d.reserved_woman, errors="raise")
    if (~d.reserved_woman.dropna().isin([0, 1])).any():
        raise ValueError("Reservation must be 0, 1, or missing")
    d.loc[d.reserved_woman.isna() & d.exclusion.eq(""), "exclusion"] = (
        "missing_reservation"
    )
    d["gp_id"] = d[KEY].apply(lambda r: json.dumps(list(r), ensure_ascii=False), axis=1)
    d["block_id"] = d[KEY[:2]].apply(
        lambda r: json.dumps(list(r), ensure_ascii=False), axis=1
    )
    good = d[d.exclusion.eq("")].copy()
    pairs, audits = [], []
    for before, after in zip(CYCLES[state][:-1], CYCLES[state][1:]):
        a, b = good[good.year.eq(before)], good[good.year.eq(after)]
        joined = a.merge(
            b,
            on=KEY,
            how="outer",
            suffixes=("_previous", ""),
            indicator=True,
            validate="one_to_one",
        )
        joined["transition"] = f"{before}-{after}"
        audits.append(joined)
        matched = joined[joined._merge.eq("both")].copy()
        matched["previous"] = matched.reserved_woman_previous.astype(int)
        matched["current"] = matched.reserved_woman.astype(int)
        matched["linkage"] = "unique_exact_normalized_name"
        pairs.append(matched.drop(columns="_merge"))
    result = pd.concat(pairs, ignore_index=True)
    if result.empty:
        raise ValueError(f"No reliable adjacent-cycle matches for {state}")
    result["initial"] = result.groupby("gp_id").previous.transform("first")
    return result, d, pd.concat(audits, ignore_index=True)


def build(source, out):
    source, out = Path(source).resolve(), Path(out)
    out.mkdir(parents=True, exist_ok=True)
    manifest = {"source_root": str(source), "inputs": {}}
    lock_path = Path(__file__).resolve().parent.parent / "source-lock.json"
    lock = json.loads(lock_path.read_text()) if lock_path.exists() else None
    for cmd, name in [
        (["rev-parse", "HEAD"], "commit"),
        (["status", "--porcelain"], "working_tree"),
    ]:
        manifest[name] = subprocess.check_output(
            ["git", "-C", str(source), *cmd], text=True
        ).strip()
    for state in CYCLES:
        path = source / "data/master" / f"master_{state}.parquet"
        manifest["inputs"][state] = {
            "path": str(path),
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        }
        if lock and manifest["inputs"][state]["sha256"] != lock["sha256"][state]:
            raise ValueError(
                f"Source hash changed for {state}; review source-lock.json"
            )
        p, records, links = panel(pd.read_parquet(path), state)
        dest = out / state
        dest.mkdir(exist_ok=True)
        p.to_parquet(dest / "panel.parquet", index=False)
        records.to_parquet(dest / "records.parquet", index=False)
        links.to_parquet(dest / "linkage.parquet", index=False)
        records.groupby(["year", "district", "exclusion"], dropna=False).size().rename(
            "n"
        ).to_csv(dest / "exclusions.csv")
        links.groupby(
            ["transition", "district", "_merge"], observed=True
        ).size().rename("n").to_csv(dest / "coverage.csv")
        p.groupby(
            ["transition", "district", "block", "previous", "current"]
        ).size().rename("n").to_csv(dest / "transitions.csv")
        histories = records[records.exclusion.eq("")].pivot(
            index="gp_id", columns="year", values="reserved_woman"
        )
        histories.to_parquet(dest / "histories.parquet")
        histories.apply(
            lambda row: "".join("?" if pd.isna(v) else str(int(v)) for v in row), axis=1
        ).value_counts().rename_axis("history").rename("n").to_csv(
            dest / "history_patterns.csv"
        )
        manifest["inputs"][state]["linked_transitions"] = len(p)
        manifest["inputs"][state]["panel_sha256"] = hashlib.sha256(
            (dest / "panel.parquet").read_bytes()
        ).hexdigest()
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
