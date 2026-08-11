from datetime import UTC, datetime

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_observation_upload_is_idempotent() -> None:
    payload = {
        "observation_id": "obs-demo-001",
        "crop": "rice",
        "captured_at": datetime.now(UTC).isoformat(),
        "model_version": "mock-0.1",
        "predictions": [{"label": "brown_spot", "score": 0.72}],
        "abstained": True,
        "abstain_reason": "mock inference",
        "consent_for_training": True,
    }
    first = client.post("/api/v1/observations", json=payload)
    second = client.post("/api/v1/observations", json=payload)
    assert first.status_code == second.status_code == 200
    assert first.json()["received_at"] == second.json()["received_at"]
