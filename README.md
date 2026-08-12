# Crop Saathi

Offline-first crop health screening and economic advisory prototype for Indian smallholder farmers.

The product requirements are documented in [PROJECT_SPEC.md](PROJECT_SPEC.md). The repository is intentionally split into a Flutter client, a FastAPI service, and an ML conversion/training area.

Security assumptions and prototype gaps are documented in [SECURITY.md](SECURITY.md).

## Repository layout

```text
apps/mobile/       Flutter application
services/api/      FastAPI synchronization and advisory service
ml/                Model conversion, evaluation, and calibration work
scripts/           Development utilities
```

## Current status

The initial scaffold includes a runnable Flutter UI flow and a small FastAPI API contract. The Hugging Face model is not yet bundled: it must first be exported to ONNX and tested on a target Android device. Until then, the mobile app uses a clearly labelled mock inference service.

## Safety boundary

This is a screening prototype. It must not present model scores as validated probabilities or prescribe pesticides without crop-specific, verified guidance.
