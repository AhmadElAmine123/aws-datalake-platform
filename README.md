# AWS Data Lake Platform

An end-to-end AWS data lake for environmental monitoring, built as a Terraform-first infrastructure project. Ingests real weather data (batch) and simulated IoT sensor events (streaming), transforms and validates them, and exposes the results via Athena.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  INGESTION                                                          │
│                                                                     │
│  EventBridge (daily)  → Lambda → Open-Meteo API → S3 raw/weather/  │
│  EventBridge (5 min)  → Lambda → Kinesis Firehose → S3 raw/iot/    │
└─────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────┐
│  TRANSFORM & VALIDATE                                               │
│                                                                     │
│  EventBridge (1 hr) → Glue Job (PySpark)                           │
│    ├── Great Expectations validation                                │
│    ├── Pseudonymize sensor_id (SHA-256)                             │
│    ├── Derive columns (temp_f, quality_score, date partition)       │
│    └── Write Parquet → S3 curated/                                  │
└─────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌─────────────────────────────────────────────────────────────────────┐
│  SERVING                                                            │
│                                                                     │
│  Glue Data Catalog → Athena Workgroup → Ad-hoc queries             │
└─────────────────────────────────────────────────────────────────────┘
                                        │
┌─────────────────────────────────────────────────────────────────────┐
│  OBSERVABILITY                                                      │
│                                                                     │
│  CloudWatch Alarms (Lambda errors, Glue failures, Firehose health)  │
│  SNS → Email notifications                                         │
│  Encrypted CloudWatch Logs (KMS)                                    │
└─────────────────────────────────────────────────────────────────────┘
```

## S3 Data Lake Layout

```
s3://<project>-<env>-datalake/
├── raw/
│   ├── weather/          date=YYYY-MM-DD/   ← JSON from Open-Meteo
│   └── iot-sensors/      year/month/day/    ← JSON from Kinesis Firehose
├── curated/
│   ├── weather/          date=YYYY-MM-DD/   ← Parquet, partitioned
│   └── sensor-readings/  date=YYYY-MM-DD/   ← Parquet, pseudonymized
├── glue-scripts/                            ← PySpark job source
├── glue-temp/                               ← Glue temporary files
└── firehose-errors/                         ← Failed Firehose deliveries
```

## Security Highlights

| Control | Implementation |
|---|---|
| Encryption at rest | KMS keys with auto-rotation; SSE-KMS on all S3 buckets |
| Encryption in transit | S3 bucket policy denies non-TLS requests |
| Pseudonymization | `sensor_id` → SHA-256 hash in Glue transform |
| Least-privilege IAM | Separate roles for Lambda, Glue, Firehose; scoped to specific resources |
| Public access | Blocked on all buckets |
| Logging | S3 access logs, CloudWatch Logs (encrypted), Glue continuous logging |

## Prerequisites

- AWS CLI configured with credentials (profile or environment variables)
- Terraform >= 1.5.0
- Python 3.12 (for local Lambda testing)

## Getting Started

### 1. Create your `.env` file

Sensitive values (email, AWS profile) live in a gitignored `.env` — nothing personal is tracked in the repo.

```bash
cp .env.example .env
# Edit .env — fill in ALERT_EMAIL and optionally AWS_PROFILE
vim .env
```

### 2. Bootstrap Remote State

This creates the S3 bucket and DynamoDB table for Terraform state **before** `terraform init`:

```bash
bash terraform/bootstrap.sh
```

### 3. Deploy Dev Environment

Source the env loader first — it reads `.env` and exports `TF_VAR_*` variables that Terraform picks up automatically:

```bash
source scripts/load-env.sh

cd terraform/envs/dev
terraform init
terraform plan
terraform apply
```

### 4. Deploy Prod Environment

Same steps, in `terraform/envs/prod/`.

### 5. Verify the Pipeline

After deploy, wait ~5 minutes for the first stream_generate Lambda to fire, then:

```bash
# Check raw data landed
aws s3 ls s3://aws-datalake-platform-dev-datalake/raw/iot-sensors/ --recursive

# Trigger batch ingest manually
aws lambda invoke \
  --function-name aws-datalake-platform-batch-ingest-dev \
  /dev/null

# Trigger Glue transform manually
aws glue start-job-run \
  --job-name aws-datalake-platform-transform-dev

# Query with Athena (after transform completes)
aws athena start-query-execution \
  --query-string "SELECT city, COUNT(*) as cnt FROM curated_sensor_readings GROUP BY city" \
  --work-group aws-datalake-platform-analytics-dev \
  --output-location s3://aws-datalake-platform-dev-athena-results/
```

## CI/CD

GitHub Actions runs on PRs to `main` that touch `terraform/`:

| Check | What it does |
|---|---|
| `fmt` | `terraform fmt -check` on all modules and envs |
| `validate` | `terraform init -backend=false` + `terraform validate` for dev and prod |
| `plan` | Full `terraform plan` (requires AWS OIDC credentials — see workflow comments) |
| `python-lint` | `py_compile` syntax check on all Python scripts |

## Project Structure

```
.
├── terraform/
│   ├── bootstrap.sh              # One-time: create state bucket + lock table
│   ├── backend.tf                # Documents backend config
│   ├── modules/
│   │   ├── s3/                   # Data lake, results, and logs buckets
│   │   ├── kms/                  # KMS encryption keys + policies
│   │   ├── iam/                  # Lambda, Glue, Firehose IAM roles
│   │   ├── lambda/               # Batch ingest + stream generate functions
│   │   ├── kinesis/              # Firehose delivery stream
│   │   ├── glue/                 # Data Catalog + PySpark transform job
│   │   ├── athena/               # Athena workgroup
│   │   ├── eventbridge/          # Scheduled rules + targets
│   │   └── monitoring/           # CloudWatch alarms + SNS topic
│   └── envs/
│       ├── dev/                  # Dev: backend, variables, main, tfvars
│       └── prod/                 # Prod: backend, variables, main, tfvars
├── scripts/
│   ├── load-env.sh               # Sources .env → exports TF_VAR_* for Terraform
│   ├── batch_ingest/             # Lambda: fetch weather from Open-Meteo
│   ├── stream_generate/          # Lambda: synthetic IoT events → Firehose
│   └── glue_transform/           # PySpark: validate → transform → write Parquet
├── docs/
│   └── runbook.md                # Operational runbook
├── .github/workflows/
│   └── terraform-ci.yml          # GitHub Actions CI
├── .env.example                  # Template for sensitive values (copy → .env)
└── README.md
```

## Cost Estimate (Dev, light usage)

| Service | Estimated/month |
|---|---|
| S3 (small data) | ~$0.05 |
| Lambda (free tier covers this) | $0.00 |
| Kinesis Firehose | ~$0.50 |
| Glue (1-2 job runs) | ~$1-3 |
| KMS | ~$1.00 |
| CloudWatch + SNS | ~$0.50 |
| DynamoDB (on-demand) | ~$0.10 |
| **Total** | **~$3-6/month** |
