"""Reviewable HTML report with diagnostics and descriptive figures."""

import html
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd


def report(dest):
    dest = Path(dest)
    settings = json.loads((dest / "settings.json").read_text())
    contrasts = pd.read_csv(dest / "block_contrasts.csv")
    summary = pd.read_csv(dest / "heterogeneity.csv")
    content = [
        "<h1>Women's reservation transitions</h1>",
        "<p>Descriptive associations among exact-name linked GP heads. "
        "Negative contrasts indicate less immediate repetition. They do not establish "
        "rotation-rule compliance, randomization, or bureaucratic discretion.</p>",
        "<p>Intervals are equal-tailed 95% Bayesian credible intervals. "
        "Contrasts average fitted probabilities within observed lag groups, "
        "preserving each GP’s initial history.</p>",
    ]
    content.append(
        f"<p><strong>Sampling diagnostics passed: {settings['diagnostics_passed']}. "
        "Simulation coverage, linkage validity, predictive fit and prior sensitivity "
        "require review before substantive interpretation.</strong></p>"
    )
    if contrasts.empty:
        content.append("<p>No blocks meet common-support requirements.</p>")
    else:
        for i, (transition, g) in enumerate(contrasts.groupby("transition")):
            fig, ax = plt.subplots(figsize=(8, 4))
            ax.hist(g["median"] * 100, bins=30)
            ax.set(
                xlabel="Posterior median transition contrast (percentage points)",
                ylabel="Blocks",
                title=str(transition),
            )
            fig.tight_layout()
            fig.savefig(dest / f"distribution_{i}.png", dpi=160)
            plt.close(fig)
            interval = g.sort_values("block_id").reset_index(drop=True)
            fig, ax = plt.subplots(figsize=(9, 4))
            ax.errorbar(
                range(len(interval)),
                interval["median"] * 100,
                yerr=[
                    (interval["median"] - interval.lower) * 100,
                    (interval.upper - interval["median"]) * 100,
                ],
                fmt=".",
                alpha=0.5,
                linewidth=0.6,
            )
            ax.set(
                xlabel="Blocks in geographic identifier order",
                ylabel="Transition contrast (percentage points)",
            )
            fig.tight_layout()
            fig.savefig(dest / f"intervals_{i}.png", dpi=160)
            plt.close(fig)
            content.append(
                f'<img src="intervals_{i}.png" alt="Block credible intervals">'
            )
            content.append(
                f"<h2>{html.escape(str(transition))}</h2>"
                f'<img src="distribution_{i}.png" alt="Block contrasts">'
            )
        content.append(
            "<p>The histogram shows shrunken estimates; its width is not the estimated "
            "underlying heterogeneity. Use the variance decomposition below.</p>"
        )
    content += [
        "<h2>Geographic heterogeneity (probability units)</h2>",
        summary.to_html(index=False),
        "<h2>Block estimates and sample sizes</h2>",
        contrasts.to_html(index=False),
        "<h2>Predictive checks</h2>",
        pd.read_csv(dest / "predictive_checks.csv").to_html(index=False),
        "<h2>Run settings</h2><pre>"
        + html.escape(json.dumps(settings, indent=2))
        + "</pre>",
    ]
    (dest / "report.html").write_text(
        '<!doctype html><meta charset="utf-8"><title>Reservation patterns</title>'
        "<style>body{font:16px system-ui;max-width:1100px;margin:40px auto}"
        "table{border-collapse:collapse}td,th{padding:5px}img{max-width:100%}</style>"
        + "\n".join(content)
    )
