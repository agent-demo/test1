#!/usr/bin/env python3
"""Validate the exported model contract and run one deterministic CPU inference."""

import argparse
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("model", type=Path)
    args = parser.parse_args()
    import numpy as np
    import onnx
    import onnxruntime as ort

    model = onnx.load(args.model, load_external_data=True)
    onnx.checker.check_model(model)
    session = ort.InferenceSession(str(args.model), providers=["CPUExecutionProvider"])
    inputs = session.get_inputs()
    outputs = session.get_outputs()
    if len(inputs) != 1 or inputs[0].name != "pixel_values":
        raise SystemExit(f"unexpected inputs: {[item.name for item in inputs]}")
    if len(outputs) != 1 or outputs[0].name != "logits":
        raise SystemExit(f"unexpected outputs: {[item.name for item in outputs]}")
    logits = session.run(None, {"pixel_values": np.zeros((1, 3, 224, 224), dtype=np.float32)})[0]
    if logits.shape != (1, 20) or not np.isfinite(logits).all():
        raise SystemExit(f"unexpected logits: shape={logits.shape}")
    print(f"valid ONNX model: input={inputs[0].shape}; output={outputs[0].shape}; classes=20")


if __name__ == "__main__":
    main()
