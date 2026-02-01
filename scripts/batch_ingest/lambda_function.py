"""
Batch Ingest Lambda
───────────────────
Triggered by EventBridge on a schedule. Fetches hourly weather data
from the Open-Meteo API for configured cities and writes JSON records
to S3 at raw/weather/.

Open-Meteo is free, public, and requires no API key.
"""
import hashlib
import json
import os
import uuid
from datetime import datetime, timezone
from urllib.request import urlopen, Request
from urllib.error import URLError

import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

S3_CLIENT = boto3.client("s3")
DATALAKE_BUCKET = os.environ["DATALAKE_BUCKET"]
ENVIRONMENT = os.environ["ENVIRONMENT"]
CITIES = json.loads(os.environ["CITIES"])

OPEN_METEO_URL = (
    "https://api.open-meteo.com/v1/forecast"
    "?latitude={lat}&longitude={lon}"
    "&hourly=temperature_2m,relative_humidity_2m,wind_speed_10m,precipitation"
    "&forecast_days=1"
    "&timezone=UTC"
)


def fetch_weather(city: dict) -> dict | None:
    """Fetch weather data for a single city from Open-Meteo."""
    url = OPEN_METEO_URL.format(lat=city["latitude"], lon=city["longitude"])
    req = Request(url, headers={"User-Agent": "aws-datalake-platform/1.0"})
    try:
        with urlopen(req, timeout=10) as response:
            return json.loads(response.read().decode("utf-8"))
    except URLError as e:
        logger.error("Failed to fetch weather for %s: %s", city["name"], e)
        return None


def transform_response(city: dict, weather_data: dict, ingestion_id: str) -> list[dict]:
    """Flatten the Open-Meteo hourly response into one record per hour."""
    hourly = weather_data.get("hourly", {})
    times = hourly.get("time", [])
    temps = hourly.get("temperature_2m", [])
    humidity = hourly.get("relative_humidity_2m", [])
    wind = hourly.get("wind_speed_10m", [])
    precip = hourly.get("precipitation", [])

    records = []
    for i, t in enumerate(times):
        records.append({
            "ingestion_id": ingestion_id,
            "city": city["name"],
            "latitude": city["latitude"],
            "longitude": city["longitude"],
            "timestamp": t,
            "temperature_c": temps[i] if i < len(temps) else None,
            "humidity_pct": humidity[i] if i < len(humidity) else None,
            "windspeed_kmh": wind[i] if i < len(wind) else None,
            "precipitation_mm": precip[i] if i < len(precip) else None,
            "ingested_at": datetime.now(timezone.utc).isoformat()
        })
    return records


def write_to_s3(records: list[dict], city_name: str, date_str: str):
    """Write records as newline-delimited JSON to S3."""
    if not records:
        logger.warning("No records for %s, skipping write", city_name)
        return

    safe_city = city_name.replace(" ", "_").lower()
    key = f"raw/weather/date={date_str}/{safe_city}_{uuid.uuid4().hex[:8]}.json"

    payload = "\n".join(json.dumps(record) for record in records)

    S3_CLIENT.put_object(
        Bucket=DATALAKE_BUCKET,
        Key=key,
        Body=payload.encode("utf-8"),
        ContentType="application/json"
    )
    logger.info("Wrote %d records to s3://%s/%s", len(records), DATALAKE_BUCKET, key)


def handler(event, context):
    """Lambda entry point."""
    logger.info("Starting batch ingest for %d cities", len(CITIES))
    date_str = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    ingestion_id = uuid.uuid4().hex

    total_records = 0
    errors = 0

    for city in CITIES:
        weather_data = fetch_weather(city)
        if weather_data is None:
            errors += 1
            continue

        records = transform_response(city, weather_data, ingestion_id)
        write_to_s3(records, city["name"], date_str)
        total_records += len(records)

    summary = {
        "ingestion_id": ingestion_id,
        "date": date_str,
        "cities_processed": len(CITIES) - errors,
        "cities_failed": errors,
        "total_records": total_records,
        "environment": ENVIRONMENT
    }
    logger.info("Batch ingest complete: %s", json.dumps(summary))

    if errors > 0:
        raise Exception(f"Batch ingest completed with {errors} city failures")

    return summary
