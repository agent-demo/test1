import json
import os
from datetime import UTC, datetime
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from .schemas import PriceSnapshot


class AgmarknetClient:
    """Adapter for the data.gov.in resource generated from AGMARKNET.

    The resource ID is deployment configuration because it can differ between
    published catalog resources. No credentials or endpoint is hard-coded.
    """

    def __init__(self, resource_id: str | None = None, api_key: str | None = None) -> None:
        self.resource_id = resource_id or os.getenv("DATA_GOV_AGMARKNET_RESOURCE_ID")
        self.api_key = api_key or os.getenv("DATA_GOV_API_KEY")
        self.base_url = os.getenv("DATA_GOV_BASE_URL", "https://api.data.gov.in/resource")

    def fetch(self, commodity: str, market: str, variety: str | None = None, limit: int = 100) -> list[PriceSnapshot]:
        if not self.resource_id or not self.api_key:
            raise RuntimeError("Agmarknet resource ID and data.gov.in API key are not configured")
        query = {
            "api-key": self.api_key,
            "format": "json",
            "limit": str(limit),
            "filters[commodity]": commodity,
            "filters[market]": market,
        }
        if variety:
            query["filters[variety]"] = variety
        request = Request(f"{self.base_url}/{self.resource_id}?{urlencode(query)}", headers={"Accept": "application/json"})
        with urlopen(request, timeout=20) as response:  # noqa: S310 - deployment-configured government endpoint
            payload = json.load(response)
        return [self._parse_record(record, commodity, market, variety) for record in payload.get("records", [])]

    @staticmethod
    def _parse_record(record: dict, commodity: str, market: str, variety: str | None) -> PriceSnapshot:
        def value(*keys: str) -> float | None:
            for key in keys:
                raw = record.get(key)
                if raw not in (None, "", "NA", "N/A"):
                    return float(str(raw).replace(",", ""))
            return None

        raw_date = record.get("arrival_date") or record.get("reported_date") or record.get("date")
        observed_on = datetime.now(UTC)
        if raw_date:
            for fmt in ("%d/%m/%Y", "%Y-%m-%d", "%d-%m-%Y"):
                try:
                    observed_on = datetime.strptime(str(raw_date), fmt).replace(tzinfo=UTC)
                    break
                except ValueError:
                    continue
        return PriceSnapshot(
            commodity=str(record.get("commodity") or commodity),
            market=str(record.get("market") or record.get("market_name") or market),
            variety=record.get("variety") or variety,
            minimum=value("min_price", "min", "minimum_price"),
            maximum=value("max_price", "max", "maximum_price"),
            modal=value("modal_price", "modal", "modal_price_rs"),
            unit="quintal",
            observed_on=observed_on,
            source="agmarknet/data.gov.in",
        )
