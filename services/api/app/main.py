from datetime import UTC, datetime

from fastapi import FastAPI, HTTPException

from .schemas import (
    AdvisoryRequest,
    AdvisoryResponse,
    ActionValue,
    ObservationCreate,
    ObservationResponse,
    PriceSnapshot,
)

app = FastAPI(title="Crop Saathi API", version="0.1.0")
_observations: dict[str, ObservationResponse] = {}
_prices: list[PriceSnapshot] = []


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "crop-saathi-api"}


@app.post("/api/v1/observations", response_model=ObservationResponse)
def receive_observation(observation: ObservationCreate) -> ObservationResponse:
    now = datetime.now(UTC)
    existing = _observations.get(observation.observation_id)
    if existing:
        return existing

    response = ObservationResponse(
        **observation.model_dump(),
        received_at=now,
        status="needs_review" if observation.abstained else "received",
    )
    _observations[observation.observation_id] = response
    return response


@app.get("/api/v1/observations/{observation_id}", response_model=ObservationResponse)
def get_observation(observation_id: str) -> ObservationResponse:
    try:
        return _observations[observation_id]
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="Observation not found") from exc


@app.post("/api/v1/prices", response_model=PriceSnapshot)
def cache_price(price: PriceSnapshot) -> PriceSnapshot:
    _prices.append(price)
    return price


@app.post("/api/v1/advisory", response_model=AdvisoryResponse)
def advisory(request: AdvisoryRequest) -> AdvisoryResponse:
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

    treat_value = request.expected_treatable_yield_kg * modal - request.transport_cost - request.treatment_cost
    sell_value = request.expected_sellable_yield_kg * modal - request.transport_cost
    salvage_value = request.expected_salvage_yield_kg * modal - request.transport_cost
    values = [
        ActionValue("treat", treat_value, "Treatment effectiveness and disease confidence must be verified."),
        ActionValue("sell", sell_value, "Agmarknet is a wholesale reference, not a guaranteed farm-gate price."),
        ActionValue("abandon", salvage_value, "Salvage safely; do not spread potentially infectious plant material."),
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
