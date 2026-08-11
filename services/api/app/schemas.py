from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class Prediction(BaseModel):
    label: str
    score: float = Field(ge=0, le=1)


class ObservationCreate(BaseModel):
    observation_id: str = Field(min_length=8, max_length=128)
    crop: str
    captured_at: datetime
    model_version: str
    predictions: list[Prediction]
    abstained: bool = False
    abstain_reason: str | None = None
    consent_for_training: bool = False


class ObservationResponse(ObservationCreate):
    received_at: datetime
    status: Literal["received", "needs_review"]


class PriceSnapshot(BaseModel):
    commodity: str
    market: str
    variety: str | None = None
    minimum: float | None = Field(default=None, ge=0)
    maximum: float | None = Field(default=None, ge=0)
    modal: float | None = Field(default=None, ge=0)
    observed_on: datetime
    source: str = "agmarknet"


class AdvisoryRequest(BaseModel):
    crop: str
    market: str
    quantity_kg: float = Field(gt=0)
    transport_cost: float = Field(default=0, ge=0)
    treatment_cost: float = Field(default=0, ge=0)
    expected_treatable_yield_kg: float = Field(ge=0)
    expected_sellable_yield_kg: float = Field(ge=0)
    expected_salvage_yield_kg: float = Field(ge=0)
    price: PriceSnapshot


class ActionValue(BaseModel):
    action: Literal["treat", "sell", "abandon"]
    estimated_value: float
    caveat: str


class AdvisoryResponse(BaseModel):
    recommendation: Literal["treat", "sell", "abandon", "uncertain"]
    values: list[ActionValue]
    price_age_days: int
    warning: str | None = None
