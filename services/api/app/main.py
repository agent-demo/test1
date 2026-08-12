import os
import hashlib
from datetime import UTC, datetime
from pathlib import Path

from fastapi import Depends, FastAPI, File, Header, HTTPException, UploadFile

from .agmarknet import AgmarknetClient
from .schemas import (
    AdvisoryRequest,
    AdvisoryResponse,
    ActionValue,
    ObservationCreate,
    ObservationResponse,
    PriceQuery,
    PriceSnapshot,
    ReviewCreate,
    ReviewResponse,
)
from .storage import SQLiteStore


async def reviewer_required(x_reviewer_token: str | None = Header(default=None)) -> str:
    expected = os.getenv("CROP_SAATHI_REVIEWER_TOKEN")
    if not expected:
        raise HTTPException(status_code=503, detail="Reviewer access is not configured")
    if x_reviewer_token != expected:
        raise HTTPException(status_code=403, detail="Reviewer authentication failed")
    return x_reviewer_token


def create_app(store: SQLiteStore | None = None) -> FastAPI:
    api = FastAPI(title="Crop Saathi API", version="0.2.0")
    api.state.store = store or SQLiteStore(os.getenv("CROP_SAATHI_DB", "data/crop_saathi.db"))
    api.state.image_dir = Path(os.getenv("CROP_SAATHI_IMAGE_DIR", "data/images"))
    api.state.image_dir.mkdir(parents=True, exist_ok=True)

    @api.get("/health")
    async def health() -> dict[str, str]:
        return {"status": "ok", "service": "crop-saathi-api", "storage": "sqlite"}

    @api.post("/api/v1/observations", response_model=ObservationResponse)
    async def receive_observation(observation: ObservationCreate) -> ObservationResponse:
        existing = api.state.store.get_observation(observation.observation_id)
        if existing:
            return existing
        response = ObservationResponse(
            **observation.model_dump(),
            received_at=datetime.now(UTC),
            status="needs_review" if observation.abstained else "received",
        )
        return api.state.store.save_observation(response)

    @api.get("/api/v1/observations/{observation_id}", response_model=ObservationResponse)
    async def get_observation(observation_id: str) -> ObservationResponse:
        observation = api.state.store.get_observation(observation_id)
        if not observation:
            raise HTTPException(status_code=404, detail="Observation not found")
        return observation

    @api.post("/api/v1/observations/{observation_id}/image")
    async def upload_observation_image(
        observation_id: str,
        image: UploadFile = File(...),
    ) -> dict[str, str | int]:
        observation = api.state.store.get_observation(observation_id)
        if not observation:
            raise HTTPException(status_code=404, detail="Observation not found")
        allowed_types = {"image/jpeg", "image/png", "image/webp"}
        if image.content_type not in allowed_types:
            raise HTTPException(status_code=415, detail="Only JPEG, PNG, or WebP images are accepted")
        maximum_bytes = 8 * 1024 * 1024
        content = await image.read(maximum_bytes + 1)
        if len(content) > maximum_bytes:
            raise HTTPException(status_code=413, detail="Image exceeds the 8 MB limit")
        digest = hashlib.sha256(content).hexdigest()
        if observation.image_sha256 and observation.image_sha256 != digest:
            raise HTTPException(status_code=422, detail="Image checksum does not match observation metadata")
        target = api.state.image_dir / f"{observation_id}-{digest}.{image.filename.rsplit('.', 1)[-1].lower() if image.filename and '.' in image.filename else 'bin'}"
        target.write_bytes(content)
        return {"observation_id": observation_id, "sha256": digest, "bytes": len(content)}

    @api.post("/api/v1/observations/{observation_id}/review", response_model=ReviewResponse)
    async def review_observation(
        observation_id: str,
        review: ReviewCreate,
        _: str = Depends(reviewer_required),
    ) -> ReviewResponse:
        observation = api.state.store.get_observation(observation_id)
        if not observation:
            raise HTTPException(status_code=404, detail="Observation not found")
        reviewed = ReviewResponse(
            **review.model_dump(),
            observation_id=observation_id,
            reviewed_at=datetime.now(UTC),
            training_candidate=observation.consent_for_training and review.reviewer_confidence >= 0.8,
        )
        updated = observation.model_copy(update={"status": "verified"})
        api.state.store.save_review(reviewed, updated)
        return reviewed

    @api.post("/api/v1/prices", response_model=PriceSnapshot)
    async def cache_price(price: PriceSnapshot) -> PriceSnapshot:
        return api.state.store.save_price(price)

    @api.post("/api/v1/prices/query", response_model=PriceSnapshot)
    async def query_latest_price(query: PriceQuery) -> PriceSnapshot:
        price = api.state.store.latest_price(query.commodity, query.market, query.variety)
        if not price:
            raise HTTPException(status_code=404, detail="No cached price snapshot")
        return price

    @api.post("/api/v1/prices/refresh", response_model=list[PriceSnapshot])
    async def refresh_prices(
        query: PriceQuery,
        _: str = Depends(reviewer_required),
    ) -> list[PriceSnapshot]:
        try:
            prices = AgmarknetClient().fetch(query.commodity, query.market, query.variety)
        except (RuntimeError, OSError, ValueError) as exc:
            raise HTTPException(status_code=502, detail=str(exc)) from exc
        for price in prices:
            api.state.store.save_price(price)
        return prices

    @api.post("/api/v1/advisory", response_model=AdvisoryResponse)
    async def advisory(request: AdvisoryRequest) -> AdvisoryResponse:
        now = datetime.now(UTC)
        age_days = max(0, (now.date() - request.price.observed_on.date()).days)
        modal = request.price.modal
        if modal is None:
            return AdvisoryResponse(
                recommendation="uncertain",
                values=[],
                price_age_days=age_days,
                warning="No modal price is available; do not force an economic recommendation.",
            )

        price_per_kg = modal / 100 if request.price.unit == "quintal" else modal
        treat_value = request.expected_treatable_yield_kg * price_per_kg - request.transport_cost - request.treatment_cost
        sell_value = request.expected_sellable_yield_kg * price_per_kg - request.transport_cost
        salvage_value = request.expected_salvage_yield_kg * price_per_kg - request.transport_cost
        values = [
            ActionValue(action="treat", estimated_value=treat_value, caveat="Treatment effectiveness and disease confidence must be verified."),
            ActionValue(action="sell", estimated_value=sell_value, caveat="Agmarknet is a wholesale reference, not a guaranteed farm-gate price."),
            ActionValue(action="abandon", estimated_value=salvage_value, caveat="Salvage safely; do not spread potentially infectious plant material."),
        ]
        best = max(values, key=lambda value: value.estimated_value)
        warning = None
        if age_days > 3:
            warning = "Price data is more than three days old; realized price may differ materially."
        return AdvisoryResponse(
            recommendation=best.action if not warning else "uncertain",
            values=values,
            price_age_days=age_days,
            warning=warning,
        )

    return api


app = create_app()
