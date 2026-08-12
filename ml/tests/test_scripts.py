import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).parents[1]


def test_calibration_reports_ece(tmp_path: Path) -> None:
    data = tmp_path / "predictions.json"
    data.write_text(json.dumps([
        {"confidence": 0.9, "correct": True, "abstained": False},
        {"confidence": 0.8, "correct": False, "abstained": False},
        {"confidence": 0.2, "correct": False, "abstained": True},
    ]))
    result = subprocess.run(
        [sys.executable, str(ROOT / "scripts/calibrate.py"), str(data)],
        check=True,
        capture_output=True,
        text=True,
    )
    assert '"samples": 2' in result.stdout
    assert '"ece"' in result.stdout


def test_parity_passes_and_fails_on_threshold(tmp_path: Path) -> None:
    reference = tmp_path / "reference.json"
    candidate = tmp_path / "candidate.json"
    reference.write_text(json.dumps({"logits": [[1.0, 2.0, 3.0]]}))
    candidate.write_text(json.dumps({"logits": [[1.0, 2.0001, 3.0]]}))
    command = [sys.executable, str(ROOT / "scripts/check_parity.py"), str(reference), str(candidate)]
    subprocess.run(command, check=True)
    failed = subprocess.run([*command, "--max-abs-error", "0.00001"])
    assert failed.returncode != 0
