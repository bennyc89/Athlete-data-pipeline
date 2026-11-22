import csv
import io
import json
import os
import urllib.parse
from datetime import date

import boto3

s3 = boto3.client("s3")
PROCESSED_BUCKET = os.environ["PROCESSED_BUCKET"]
ALLOWED_TESTS = {"sprint_10m", "sprint_20m", "cmj", "broad_jump", "pro_agility"}


def clean_row(row):
    """Return a cleaned row, or None if the row is invalid."""
    try:
        athlete_id = row["athlete_id"].strip()
        test_date = date.fromisoformat(row["test_date"].strip())
        test_name = row["test_name"].strip().lower()
        value = float(row["value"])
    except (KeyError, ValueError, AttributeError):
        return None
    if not athlete_id or test_name not in ALLOWED_TESTS or value <= 0:
        return None
    return [athlete_id, test_date.isoformat(), test_name, round(value, 3)]


def handler(event, context):
    for record in event["Records"]:
        bucket = record["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])
        body = s3.get_object(Bucket=bucket, Key=key)["Body"].read().decode("utf-8-sig")

        good, rejected = [], 0
        for row in csv.DictReader(io.StringIO(body)):
            cleaned = clean_row(row)
            if cleaned:
                good.append(cleaned)
            else:
                rejected += 1

        out = io.StringIO()
        csv.writer(out).writerows(good)
        out_key = "results/" + key.rsplit("/", 1)[-1]
        s3.put_object(
            Bucket=PROCESSED_BUCKET,
            Key=out_key,
            Body=out.getvalue().encode("utf-8"),
            ContentType="text/csv",
        )
        print(json.dumps({"source": key, "kept": len(good), "rejected": rejected, "output": out_key}))

    return {"status": "ok"}

