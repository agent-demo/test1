# ML integration

The first model target is `LishaV01/agriculture-crop-disease-detection`.

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
