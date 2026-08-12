#!/usr/bin/env python3
"""Compute reliability statistics from reviewed field predictions."""

import argparse
import json
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("predictions", type=Path, help="JSON list of {confidence, correct, abstained}")
    parser.add_argument("--bins", type=int, default=10)
    args = parser.parse_args()
    rows = json.loads(args.predictions.read_text())
    actionable = [row for row in rows if not row.get("abstained", False)]
    if not actionable:
        raise SystemExit("no actionable predictions to calibrate")
    ece = 0.0
    report = []
    for index in range(args.bins):
        low, high = index / args.bins, (index + 1) / args.bins
        bucket = [row for row in actionable if low <= row["confidence"] <= high and (index == args.bins - 1 or row["confidence"] < high)]
        if not bucket:
            continue
        accuracy = sum(bool(row["correct"]) for row in bucket) / len(bucket)
        confidence = sum(float(row["confidence"]) for row in bucket) / len(bucket)
        ece += len(bucket) / len(actionable) * abs(accuracy - confidence)
        report.append({"low": low, "high": high, "count": len(bucket), "accuracy": accuracy, "confidence": confidence})
    print(json.dumps({"samples": len(actionable), "ece": ece, "bins": report}, indent=2))
    print("thresholds must be selected using disease/action costs; ECE alone is not a safety guarantee")


if __name__ == "__main__":
    main()
