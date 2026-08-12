#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
model_dir="${repo_root}/ml/artifacts"
mobile_dir="${repo_root}/apps/mobile/assets/models"

mkdir -p "${model_dir}" "${mobile_dir}"

if [[ ! -f "${model_dir}/crop_saathi_v0.onnx" ]]; then
  python "${repo_root}/ml/scripts/inspect_hf_model.py" --out "${model_dir}"
  python "${repo_root}/ml/scripts/export_onnx.py" \
    --model-dir "${model_dir}" \
    --output "${model_dir}/crop_saathi_v0.onnx"
fi

cp "${model_dir}/crop_saathi_v0.onnx" "${mobile_dir}/crop_saathi_v0.onnx"
sha256sum "${mobile_dir}/crop_saathi_v0.onnx"
