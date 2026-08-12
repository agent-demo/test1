import json
from pathlib import Path


def test_manifest_has_exact_upstream_class_contract() -> None:
    manifest = json.loads((Path(__file__).parents[1] / "model_manifest.json").read_text())
    labels = manifest["labels"]
    assert [entry["id"] for entry in labels] == list(range(20))
    assert labels[3]["label"] == "invalid"
    assert labels[3]["abstain"] is True
    assert manifest["safety"]["field_validated"] is False
