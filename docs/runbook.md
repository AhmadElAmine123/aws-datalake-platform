# Runbook — AWS Data Lake Platform

## Architecture at a Glance

```
EventBridge (daily)  ──► Lambda (batch_ingest)  ──► Open-Meteo API ──► S3 raw/weather/
EventBridge (5 min)  ──► Lambda (stream_generate) ──► Kinesis Firehose ──► S3 raw/iot-sensors/
EventBridge (1 hr)   ──► Glue Job (transform)    ──► validates ──► pseudonymizes ──► S3 curated/
Athena               ──► queries curated/ tables via Glue Data Catalog
CloudWatch Alarms    ──► SNS ──► Email
```

---

## What Can Break and How to Respond

### 1. Batch Ingest Lambda Fails

**Symptoms:**
- CloudWatch alarm `batch-ingest-errors` fires
- SNS notification received
- No new files in `s3://<bucket>/raw/weather/`

**Likely causes:**
| Cause | How to check | Fix |
|---|---|---|
| Open-Meteo API down | Check https://open-meteo.com/status | Wait and re-invoke manually |
| Lambda timeout (>120s) | CloudWatch Logs → `/aws/lambda/<name>-batch-ingest` | Increase timeout in Terraform, redeploy |
| S3 permission denied | Lambda logs show `AccessDenied` | Verify IAM role policy in `modules/iam` |
| KMS permission denied | Lambda logs show `AccessDeniedException` on KMS | Check KMS key policy allows Lambda service |

**Manual re-invoke:**
```bash
aws lambda invoke --function-name aws-datalake-platform-batch-ingest-dev /dev/null
```

---

### 2. Stream Generate Lambda Fails

**Symptoms:**
- CloudWatch alarm `stream-generate-errors` fires
- No new data arriving in `raw/iot-sensors/`

**Likely causes:**
| Cause | How to check | Fix |
|---|---|---|
| Firehose permission denied | Lambda logs show `AccessDenied` | Check IAM role has `firehose:PutRecordBatch` |
| Firehose stream deleted | AWS Console → Kinesis Firehose | Redeploy Terraform to recreate |

**Manual re-invoke:**
```bash
aws lambda invoke --function-name aws-datalake-platform-stream-generate-dev /dev/null
```

---

### 3. Kinesis Firehose Delivery Fails

**Symptoms:**
- Data is pushed to Firehose but not appearing in S3
- Files appearing in `firehose-errors/` prefix instead

**Likely causes:**
| Cause | How to check | Fix |
|---|---|---|
| S3 bucket policy blocking writes | Check Firehose CloudWatch logs | Verify Firehose IAM role has S3 write access |
| KMS key issue | Firehose error logs mention encryption | Check KMS key policy includes `firehose.amazonaws.com` |
| Buffering delay | Normal — Firehose buffers up to 60s | Wait for the buffering interval |

---

### 4. Glue Transform Job Fails

**Symptoms:**
- CloudWatch alarm `glue-transform-failures` fires
- `curated/` data is stale

**Likely causes:**
| Cause | How to check | Fix |
|---|---|---|
| No raw data to process | Glue logs show empty DataFrame | Verify batch/stream Lambdas ran successfully first |
| Data validation failure | Glue logs show validation FAILED | Inspect raw data for nulls/out-of-range values |
| Schema mismatch | Glue logs show `AnalysisException` | Update Glue catalog table schema in `modules/glue` |
| S3 permission on curated/ | Glue logs show `AccessDenied` | Check Glue IAM role policy |
| Script not found | Glue logs reference missing script | Re-upload script: `terraform apply` (re-runs S3 object upload) |

**Manual re-run:**
```bash
aws glue start-job-run \
  --job-name aws-datalake-platform-transform-dev
```

**Check recent Glue job runs:**
```bash
aws glue get-job-runs --job-name aws-datalake-platform-transform-dev --max-results 5
```

---

### 5. Athena Queries Return No Data

**Symptoms:**
- `SELECT * FROM curated_weather` returns 0 rows

**Likely causes:**
| Cause | How to check | Fix |
|---|---|---|
| Partitions not registered | Athena shows "no partitions found" | Run `MSCK REPAIR TABLE` manually |
| Glue transform hasn't run yet | Check curated/ S3 prefix is empty | Trigger Glue job manually |
| Wrong workgroup | Query runs on default workgroup | Specify workgroup: `aws-datalake-platform-analytics-dev` |

**Repair partitions manually:**
```sql
-- Run in Athena
MSCK REPAIR TABLE aws_datalake_platform_dev.curated_weather;
MSCK REPAIR TABLE aws_datalake_platform_dev.curated_sensor_readings;
```

---

### 6. Terraform Apply Fails

**Symptoms:**
- `terraform apply` errors in CI or locally

**Common issues:**
| Issue | Fix |
|---|---|
| Backend not initialized | Run `bash terraform/bootstrap.sh` first |
| State lock conflict | Another apply is in progress — wait, or break the lock in DynamoDB |
| IAM permission denied | Ensure your AWS credentials have sufficient permissions |
| Resource name conflict | S3 bucket names are globally unique — check if name is taken |

**Break a stuck DynamoDB lock:**
```bash
aws dynamodb delete-item \
  --table-name aws-datalake-platform-tf-locks \
  --key '{"LockID": {"S": "aws-datalake-platform-tf-state/dev/terraform.tfstate-md5"}}'
```

---

## Monitoring Dashboard (Quick Links)

After deployment, bookmark these AWS Console pages:

- **CloudWatch Alarms:** Console → CloudWatch → Alarms
- **Lambda Logs:** Console → CloudWatch → Log Groups → `/aws/lambda/aws-datalake-platform-*`
- **Glue Job History:** Console → Glue → Jobs → `aws-datalake-platform-transform-<env>`
- **S3 Data Lake:** Console → S3 → `aws-datalake-platform-<env>-datalake`
- **Athena:** Console → Athena → select workgroup `aws-datalake-platform-analytics-<env>`

---

## Operational Checklist (Weekly)

- [ ] Check CloudWatch Alarms dashboard — any in ALARM state?
- [ ] Verify `raw/` has recent data (last 24h)
- [ ] Verify `curated/` has recent Parquet files
- [ ] Run a quick Athena sanity query: `SELECT COUNT(*) FROM curated_sensor_readings WHERE date = current_date`
- [ ] Check S3 lifecycle — confirm old raw/ data is transitioning to IA
