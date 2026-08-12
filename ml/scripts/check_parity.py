#!/usr/bin/env python3
"""Compare reference logits and ONNX logits from JSON fixtures."""

import argparse
import json
import math
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("reference", type=Path)
    parser.add_argument("onnx", type=Path)
    parser.add_argument("--max-abs-error", type=float, default=1e-3)
    args = parser.parse_args()
    reference = json.loads(args.reference.read_text())["logits"]
    candidate = json.loads(args.onnx.read_text())["logits"]
    if len(reference) != len(candidate):
        raise SystemExit("parity failed: batch sizes differ")
    errors = [abs(float(a) - float(b)) for row_a, row_b in zip(reference, candidate) for a, b in zip(row_a, row_b)]
    maximum = max(errors, default=0.0)
    mean = sum(errors) / len(errors) if errors else 0.0
    print(json.dumps({"max_abs_error": maximum, "mean_abs_error": mean}))
    if not math.isfinite(maximum) or maximum > args.max_abs_error:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
