# ML integration

The first model target is `LishaV01/agriculture-crop-disease-detection`.

The checked-in [model manifest](model_manifest.json) is the application-facing label contract. The upstream config currently contains 20 classes, including `Invalid`, and has separate near-duplicate rice labels. Do not infer a cleaner taxonomy without a reviewed mapping and a new model evaluation.

## Reproducible workflow

```bash
python ml/scripts/inspect_hf_model.py
python ml/scripts/export_onnx.py
```

The scripts require the packages in [requirements.txt](requirements.txt). The model binary is deliberately ignored by Git. Pin a Hugging Face commit revision for a release instead of using `main`.

The current `shell.nix` provides Python 3.12 and CUDA libraries, but it does not itself declare PyTorch/Transformers. Install [requirements.txt](requirements.txt) into a Python 3.12 virtual environment inside that shell, or add equivalent pinned Nix packages for a fully hermetic build.

For CPU-only model export, prefer [requirements-cpu.txt](requirements-cpu.txt). The unconstrained PyPI Torch resolver may select a CUDA wheel; that is unnecessary for ONNX conversion and can consume hundreds of megabytes.

Required work before bundling it:

1. Download the model and inspect whether the Safetensors file is a full classifier or an adapter requiring a base model.
2. Load the repository preprocessing configuration exactly.
3. Verify the label mapping from model output indices.
4. Export to ONNX.
5. Run numerical parity checks between Transformers and ONNX Runtime.
6. Quantize only after parity checks.
7. Measure CPU latency and memory on a low-cost Android phone.
8. Add a field-image evaluation set and calibrate abstention thresholds.

Until this work is complete, the Flutter app deliberately reports mock inference and does not claim a real diagnosis.
