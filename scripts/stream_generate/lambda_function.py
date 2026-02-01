"""
Stream Generate Lambda
──────────────────────
Triggered by EventBridge every 5 minutes. Generates synthetic IoT sensor
readings for multiple sensors per city and pushes them to a Kinesis Firehose
delivery stream, which delivers to S3 raw/iot-sensors/.

Each sensor_id is a deterministic hash of (city + sensor_index) so that
downstream pseudonymization (re-hashing) produces stable, reproducible results.
"""
import json
import os
import random
import hashlib
from datetime import datetime, timezone

import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

FIREHOSE_CLIENT = boto3.client("firehose")
FIREHOSE_NAME = os.environ["FIREHOSE_NAME"]
ENVIRONMENT = os.environ["ENVIRONMENT"]
CITIES = json.loads(os.environ["CITIES"])
SENSORS_PER_CITY = int(os.environ.get("SENSORS_PER_CITY", "3"))

# Seed random for reproducibility within a single invocation
random.seed()


def generate_sensor_id(city_name: str, sensor_index: int) -> str:
    """Generate a deterministic sensor ID from city + index."""
    raw = f"{city_name.lower().replace(' ', '_')}_{sensor_index:03d}"
    return f"sensor-{hashlib.sha256(raw.encode()).hexdigest()[:12]}"


def generate_reading(sensor_id: str, city: dict) -> dict:
    """Generate a single realistic sensor reading."""
    # Simulate realistic ranges with some noise
    base_temp = 15.0 + (hash(city["name"]) % 30)  # 15-45°C base by city
    temperature_c = round(base_temp + random.gauss(0, 3), 1)
    humidity_pct = round(random.uniform(20, 95), 1)
    # AQI: mostly good/moderate, occasional spikes
    aqi = round(random.choices(
        population=[random.uniform(0, 50), random.uniform(51, 100), random.uniform(101, 200)],
        weights=[0.7, 0.2, 0.1],
        k=1
    )[0], 1)
    battery_level = round(random.uniform(15, 100), 1)

    return {
        "sensor_id": sensor_id,
        "city": city["name"],
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "temperature_c": temperature_c,
        "humidity_pct": humidity_pct,
        "aqi": aqi,
        "battery_level": battery_level
    }


def handler(event, context):
    """Lambda entry point — generates readings and pushes to Firehose."""
    logger.info("Generating IoT sensor events for %d cities", len(CITIES))

    records = []
    for city in CITIES:
        for i in range(SENSORS_PER_CITY):
            sensor_id = generate_sensor_id(city["name"], i)
            reading = generate_reading(sensor_id, city)
            records.append({
                "Data": json.dumps(reading) + "\n"  # Newline for Firehose record delimiter
            })

    # Push all records in one batch to Firehose
    if records:
        response = FIREHOSE_CLIENT.put_record_batch(
            DeliveryStreamName=FIREHOSE_NAME,
            Records=records
        )
        failed = response.get("FailedRecordCount", 0)
        logger.info(
            "Pushed %d records to Firehose '%s'. Failed: %d",
            len(records), FIREHOSE_NAME, failed
        )
        if failed > 0:
            raise Exception(f"{failed} records failed to deliver to Firehose")
    else:
        logger.warning("No records generated")

    return {
        "records_sent": len(records),
        "cities": len(CITIES),
        "sensors_per_city": SENSORS_PER_CITY,
        "environment": ENVIRONMENT
    }
