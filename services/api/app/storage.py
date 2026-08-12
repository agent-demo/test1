import sqlite3
from pathlib import Path

from .schemas import ObservationResponse, PriceSnapshot, ReviewResponse


class SQLiteStore:
    """Small durable store for the prototype; replaceable by PostgreSQL later."""

    def __init__(self, path: str = "data/crop_saathi.db") -> None:
        self.path = path
        if path != ":memory:":
            Path(path).parent.mkdir(parents=True, exist_ok=True)
        self._initialize()

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.path)
        connection.row_factory = sqlite3.Row
        return connection

    def _initialize(self) -> None:
        with self._connect() as connection:
            connection.executescript(
                """
                CREATE TABLE IF NOT EXISTS observations (
                    observation_id TEXT PRIMARY KEY,
                    payload TEXT NOT NULL,
                    received_at TEXT NOT NULL,
                    status TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS reviews (
                    observation_id TEXT PRIMARY KEY,
                    payload TEXT NOT NULL,
                    reviewed_at TEXT NOT NULL,
                    FOREIGN KEY(observation_id) REFERENCES observations(observation_id)
                );
                CREATE TABLE IF NOT EXISTS prices (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    commodity TEXT NOT NULL,
                    market TEXT NOT NULL,
                    variety TEXT,
                    payload TEXT NOT NULL,
                    observed_on TEXT NOT NULL
                );
                """
            )

    def get_observation(self, observation_id: str) -> ObservationResponse | None:
        with self._connect() as connection:
            row = connection.execute(
                "SELECT payload FROM observations WHERE observation_id = ?",
                (observation_id,),
            ).fetchone()
        return ObservationResponse.model_validate_json(row["payload"]) if row else None

    def save_observation(self, observation: ObservationResponse) -> ObservationResponse:
        with self._connect() as connection:
            connection.execute(
                "INSERT OR IGNORE INTO observations(observation_id, payload, received_at, status) VALUES (?, ?, ?, ?)",
                (
                    observation.observation_id,
                    observation.model_dump_json(),
                    observation.received_at.isoformat(),
                    observation.status,
                ),
            )
        return self.get_observation(observation.observation_id) or observation

    def save_review(self, review: ReviewResponse, observation: ObservationResponse) -> None:
        with self._connect() as connection:
            connection.execute(
                "UPDATE observations SET payload = ?, status = ? WHERE observation_id = ?",
                (observation.model_dump_json(), observation.status, observation.observation_id),
            )
            connection.execute(
                "INSERT OR REPLACE INTO reviews(observation_id, payload, reviewed_at) VALUES (?, ?, ?)",
                (review.observation_id, review.model_dump_json(), review.reviewed_at.isoformat()),
            )

    def save_price(self, price: PriceSnapshot) -> PriceSnapshot:
        with self._connect() as connection:
            connection.execute(
                "INSERT INTO prices(commodity, market, variety, payload, observed_on) VALUES (?, ?, ?, ?, ?)",
                (
                    price.commodity,
                    price.market,
                    price.variety,
                    price.model_dump_json(),
                    price.observed_on.isoformat(),
                ),
            )
        return price

    def latest_price(self, commodity: str, market: str, variety: str | None = None) -> PriceSnapshot | None:
        with self._connect() as connection:
            row = connection.execute(
                """
                SELECT payload FROM prices
                WHERE commodity = ? AND market = ? AND (variety = ? OR (? IS NULL AND variety IS NULL))
                ORDER BY observed_on DESC, id DESC LIMIT 1
                """,
                (commodity, market, variety, variety),
            ).fetchone()
        return PriceSnapshot.model_validate_json(row["payload"]) if row else None

    def close(self) -> None:
        # Connections are short-lived per operation; this method exists for test/documentation symmetry.
        return None
