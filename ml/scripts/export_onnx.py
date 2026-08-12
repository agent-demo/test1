#!/usr/bin/env python3
"""Export the Hugging Face classifier to ONNX with its exact image preprocessing."""

import argparse
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-dir", type=Path, default=Path("ml/artifacts"))
    parser.add_argument("--output", type=Path, default=Path("ml/artifacts/crop_saathi_v0.onnx"))
    parser.add_argument("--opset", type=int, default=17)
    args = parser.parse_args()

    try:
        import torch
        from transformers import AutoImageProcessor, AutoModelForImageClassification
    except ImportError as exc:
        raise SystemExit("Install ml requirements first: pip install torch transformers onnx onnxruntime") from exc

    processor = AutoImageProcessor.from_pretrained(args.model_dir, local_files_only=True)
    model = AutoModelForImageClassification.from_pretrained(args.model_dir, local_files_only=True).eval()

    class LogitsOnly(torch.nn.Module):
        def __init__(self, wrapped):
            super().__init__()
            self.wrapped = wrapped

        def forward(self, pixel_values):
            return self.wrapped(pixel_values=pixel_values).logits

    model = LogitsOnly(model).eval()
    sample = torch.zeros(1, 3, 224, 224, dtype=torch.float32)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    torch.onnx.export(
        model,
        (sample,),
        args.output,
        input_names=["pixel_values"],
        output_names=["logits"],
        dynamic_axes={"pixel_values": {0: "batch"}, "logits": {0: "batch"}},
        opset_version=args.opset,
    )
    # Torch may emit a tiny graph plus an external-data sidecar. Android asset
    # loading is simpler and safer with one immutable model file.
    import onnx

    exported = onnx.load(args.output, load_external_data=True)
    onnx.save_model(exported, args.output, save_as_external_data=False)
    print(f"exported {args.output}")
    print(f"preprocessing: size={processor.size}, mean={processor.image_mean}, std={processor.image_std}")
    print("export is not deployment approval; run parity and field calibration before bundling")


if __name__ == "__main__":
    main()
