"""Explicit stages; fitting never rebuilds or changes source data."""

import argparse


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    build = sub.add_parser("build")
    build.add_argument("--source", default="../local_elections")
    build.add_argument("--out", default="outputs/data")
    fit = sub.add_parser("fit")
    fit.add_argument("panel")
    fit.add_argument("--out", required=True)
    fit.add_argument("--draws", type=int, default=1000)
    fit.add_argument("--tune", type=int, default=1000)
    fit.add_argument("--chains", type=int, default=4)
    fit.add_argument("--seed", type=int, default=20261101)
    fit.add_argument("--scale", type=float, default=0.5)
    fit.add_argument("--adjusted", action="store_true")
    fit.add_argument("--complete-history", action="store_true")
    report = sub.add_parser("report")
    report.add_argument("directory")
    bench = sub.add_parser("benchmark")
    bench.add_argument("panel")
    bench.add_argument("--out", required=True)
    bench.add_argument("--replicates", type=int, default=1000)
    validate = sub.add_parser("validate")
    validate.add_argument("--out", default="outputs/validation")
    validate.add_argument("--replicates", type=int, default=20)
    validate.add_argument("--draws", type=int, default=1000)
    validate.add_argument("--tune", type=int, default=1000)
    validate.add_argument("--districts", type=int, default=6)
    validate.add_argument("--blocks", type=int, default=5)
    args = vars(parser.parse_args())
    command = args.pop("command")
    if command == "build":
        from .data import build

        build(**args)
    elif command == "fit":
        from .model import fit

        args["panel_path"] = args.pop("panel")
        args["dest"] = args.pop("out")
        fit(**args)
    elif command == "report":
        from .report import report

        report(args["directory"])
    elif command == "benchmark":
        from .simulation import benchmark

        benchmark(**args)
    else:
        from .simulation import validate

        validate(**args)


if __name__ == "__main__":
    main()
