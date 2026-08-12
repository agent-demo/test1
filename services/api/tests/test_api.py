from datetime import UTC, datetime, timedelta
import hashlib

from app.agmarknet import AgmarknetClient
from app.main import create_app
from app.schemas import PriceSnapshot
from app.storage import SQLiteStore


class ASGIClient:
    """Minimal in-process ASGI request runner for deterministic API tests."""

    def __init__(self, app):
        self.app = app

    def request(
        self,
        method: str,
        path: str,
        body: dict | None = None,
        headers: dict[str, str] | None = None,
        raw_body: bytes | None = None,
        raw_headers: dict[str, str] | None = None,
    ):
        import asyncio
        import json

        request_body = raw_body if raw_body is not None else (json.dumps(body).encode() if body is not None else b"")
        response = {"status": None, "headers": [], "body": bytearray()}
        sent = False

        async def receive():
            nonlocal sent
            if sent:
                await asyncio.sleep(0)
                return {"type": "http.disconnect"}
            sent = True
            return {"type": "http.request", "body": request_body, "more_body": False}

        async def send(message):
            if message["type"] == "http.response.start":
                response["status"] = message["status"]
                response["headers"] = message.get("headers", [])
            elif message["type"] == "http.response.body":
                response["body"].extend(message.get("body", b""))

        scope = {
            "type": "http",
            "http_version": "1.1",
            "method": method,
            "path": path,
            "raw_path": path.encode(),
            "query_string": b"",
            "headers": [(key.lower().encode(), value.encode()) for key, value in {**(headers or {}), **(raw_headers or {})}.items()],
            "scheme": "http",
            "server": ("testserver", 80),
            "client": ("testclient", 123),
            "root_path": "",
        }

        asyncio.run(self.app(scope, receive, send))
        return ASGIResponse(response["status"], bytes(response["body"]))

    def get(self, path: str):
        return self.request("GET", path)

    def post(self, path: str, body: dict, headers: dict[str, str] | None = None):
        return self.request("POST", path, body, headers)

    def multipart(self, path: str, field: str, filename: str, content_type: str, content: bytes):
        boundary = "crop-saathi-test-boundary"
        body = (
            f"--{boundary}\r\n"
            f"Content-Disposition: form-data; name=\"{field}\"; filename=\"{filename}\"\r\n"
            f"Content-Type: {content_type}\r\n\r\n"
        ).encode() + content + f"\r\n--{boundary}--\r\n".encode()
        return self.request(
            "POST",
            path,
            raw_body=body,
            raw_headers={"content-type": f"multipart/form-data; boundary={boundary}"},
        )


class ASGIResponse:
    def __init__(self, status: int, body: bytes):
        import json

        self.status_code = status
        self._json = json.loads(body) if body else None

    def json(self):
        return self._json


def make_client(tmp_path, monkeypatch) -> ASGIClient:
    monkeypatch.setenv("CROP_SAATHI_REVIEWER_TOKEN", "test-reviewer-token")
    return ASGIClient(create_app(SQLiteStore(str(tmp_path / "test.db"))))


def test_health(tmp_path, monkeypatch) -> None:
    response = make_client(tmp_path, monkeypatch).get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "service": "crop-saathi-api", "storage": "sqlite"}


def test_observation_upload_is_idempotent(tmp_path, monkeypatch) -> None:
    client = make_client(tmp_path, monkeypatch)
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
    first = client.post("/api/v1/observations", payload)
    second = client.post("/api/v1/observations", payload)
    assert first.status_code == second.status_code == 200
    assert first.json()["received_at"] == second.json()["received_at"]


def test_review_requires_token_and_marks_training_candidate(tmp_path, monkeypatch) -> None:
    client = make_client(tmp_path, monkeypatch)
    payload = {
        "observation_id": "obs-review-001",
        "crop": "wheat",
        "captured_at": datetime.now(UTC).isoformat(),
        "model_version": "mock-0.1",
        "predictions": [{"label": "yellow_rust", "score": 0.6}],
        "abstained": False,
        "consent_for_training": True,
    }
    assert client.post("/api/v1/observations", payload).status_code == 200
    review = {
        "verified_label": "yellow_rust",
        "reviewer_confidence": 0.9,
        "reviewer_notes": "Field worker confirmed symptoms and growth stage.",
        "follow_up_result": "Improved after verified management advice.",
    }
    unauthorized = client.post("/api/v1/observations/obs-review-001/review", review)
    assert unauthorized.status_code == 403
    authorized = client.post(
        "/api/v1/observations/obs-review-001/review",
        review,
        {"X-Reviewer-Token": "test-reviewer-token"},
    )
    assert authorized.status_code == 200
    assert authorized.json()["training_candidate"] is True
    assert client.get("/api/v1/observations/obs-review-001").json()["status"] == "verified"


def test_price_query_is_persistent(tmp_path) -> None:
    store = SQLiteStore(str(tmp_path / "prices.db"))
    price = PriceSnapshot(
        commodity="Rice",
        market="Wardha",
        modal=2800,
        minimum=2500,
        maximum=3000,
        observed_on=datetime.now(UTC),
    )
    store.save_price(price)
    reopened = SQLiteStore(str(tmp_path / "prices.db"))
    assert reopened.latest_price("Rice", "Wardha").modal == 2800


def test_stale_price_forces_uncertain_advisory(tmp_path, monkeypatch) -> None:
    client = make_client(tmp_path, monkeypatch)
    old = (datetime.now(UTC) - timedelta(days=5)).isoformat()
    request = {
        "crop": "rice",
        "market": "Wardha",
        "quantity_kg": 1000,
        "transport_cost": 500,
        "treatment_cost": 1000,
        "expected_treatable_yield_kg": 900,
        "expected_sellable_yield_kg": 500,
        "expected_salvage_yield_kg": 100,
        "price": {"commodity": "Rice", "market": "Wardha", "modal": 2800, "unit": "quintal", "observed_on": old},
    }
    result = client.post("/api/v1/advisory", request)
    assert result.status_code == 200
    assert result.json()["recommendation"] == "uncertain"
    assert result.json()["price_age_days"] >= 5


def test_agmarknet_record_parser_handles_common_field_names() -> None:
    parsed = AgmarknetClient._parse_record(
        {
            "commodity": "Rice",
            "market": "Wardha",
            "variety": "Common",
            "min_price": "2500",
            "max_price": "3000",
            "modal_price": "2800",
            "arrival_date": "12/08/2026",
        },
        "Rice",
        "Wardha",
        None,
    )
    assert parsed.modal == 2800
    assert parsed.source == "agmarknet/data.gov.in"


def test_image_upload_validates_type_size_and_checksum(tmp_path, monkeypatch) -> None:
    client = make_client(tmp_path, monkeypatch)
    content = b"not-really-a-jpeg-but-the-upload-boundary-is-tested"
    digest = hashlib.sha256(content).hexdigest()
    payload = {
        "observation_id": "obs-image-001",
        "crop": "rice",
        "captured_at": datetime.now(UTC).isoformat(),
        "model_version": "mock-0.1",
        "predictions": [],
        "image_sha256": digest,
        "consent_for_training": True,
    }
    assert client.post("/api/v1/observations", payload).status_code == 200
    assert client.multipart(
        "/api/v1/observations/obs-image-001/image",
        "image",
        "leaf.jpg",
        "image/jpeg",
        content,
    ).status_code == 200
    invalid = payload | {"image_sha256": "bad"}
    assert client.post("/api/v1/observations", invalid).status_code == 422
    assert client.multipart(
        "/api/v1/observations/obs-image-001/image",
        "image",
        "leaf.txt",
        "text/plain",
        content,
    ).status_code == 415
