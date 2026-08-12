#!/usr/bin/env python3
"""Compare Transformers and ONNX logits on one deterministic preprocessed image."""

import argparse
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-dir", type=Path, default=Path("ml/artifacts"))
    parser.add_argument("--onnx", type=Path, default=Path("ml/artifacts/crop_saathi_v0.onnx"))
    args = parser.parse_args()
    import numpy as np
    import onnxruntime as ort
    import torch
    from PIL import Image
    from transformers import AutoImageProcessor, AutoModelForImageClassification

    processor = AutoImageProcessor.from_pretrained(args.model_dir, local_files_only=True)
    model = AutoModelForImageClassification.from_pretrained(args.model_dir, local_files_only=True).eval()
    image = Image.new("RGB", (224, 224), (127, 83, 41))
    batch = processor(images=image, return_tensors="pt")
    with torch.no_grad():
        reference = model(**batch).logits.numpy()
    session = ort.InferenceSession(str(args.onnx), providers=["CPUExecutionProvider"])
    candidate = session.run(None, {"pixel_values": batch["pixel_values"].numpy()})[0]
    maximum = float(np.max(np.abs(reference - candidate)))
    print(f"max_abs_error={maximum:.8f}; shape={candidate.shape}")
    if maximum > 1e-3:
        raise SystemExit("Transformers/ONNX parity failed")


if __name__ == "__main__":
    main()
