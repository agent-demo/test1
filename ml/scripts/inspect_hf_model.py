#!/usr/bin/env python3
"""Download and inspect the published model without silently trusting its card."""

import argparse
import json
import urllib.request
from pathlib import Path


FILES = ("config.json", "preprocessor_config.json", "model.safetensors")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-id", default="LishaV01/agriculture-crop-disease-detection")
    parser.add_argument("--revision", default="main")
    parser.add_argument("--out", type=Path, default=Path("ml/artifacts"))
    parser.add_argument("--skip-weights", action="store_true")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    files = FILES[:-1] if args.skip_weights else FILES
    for filename in files:
        target = args.out / filename
        url = f"https://huggingface.co/{args.model_id}/resolve/{args.revision}/{filename}"
        print(f"fetching {url}")
        urllib.request.urlretrieve(url, target)

    config = json.loads((args.out / "config.json").read_text())
    labels = config.get("id2label", {})
    print(f"architecture: {config.get('architectures')}")
    print(f"labels: {len(labels)}")
    print(f"invalid labels: {[label for label in labels.values() if label.lower() == 'invalid']}")
    print(f"hidden size: {config.get('hidden_size')}; layers: {config.get('num_hidden_layers')}")
    print("model metadata downloaded; field validation and calibration are still required")


if __name__ == "__main__":
    main()
