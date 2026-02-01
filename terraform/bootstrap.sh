#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Bootstrap script: creates the S3 bucket and DynamoDB table required for
# Terraform remote state + locking BEFORE you run `terraform init`.
#
# Run this ONCE per AWS account. It is idempotent.
#
# Usage:
#   export AWS_PROFILE=your-profile   # or ensure credentials are configured
#   bash terraform/bootstrap.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

STATE_BUCKET="aws-datalake-platform-tf-state"
LOCK_TABLE="aws-datalake-platform-tf-locks"
REGION="us-east-1"

echo "=== Bootstrapping Terraform remote state ==="
echo "  Bucket:  ${STATE_BUCKET}"
echo "  Table:   ${LOCK_TABLE}"
echo "  Region:  ${REGION}"
echo

# ─── S3 Bucket ───────────────────────────────────────────────────────────────
if aws s3api head-bucket --bucket "${STATE_BUCKET}" 2>/dev/null; then
  echo "[SKIP] S3 bucket ${STATE_BUCKET} already exists."
else
  echo "[CREATE] S3 bucket ${STATE_BUCKET}"
  aws s3api create-bucket \
    --bucket "${STATE_BUCKET}" \
    --region "${REGION}" \
    --create-bucket-configuration LocationConstraint="${REGION}" 2>/dev/null || \
  aws s3api create-bucket \
    --bucket "${STATE_BUCKET}" \
    --region "${REGION}"

  aws s3api put-bucket-versioning \
    --bucket "${STATE_BUCKET}" \
    --versioning-configuration Status=Enabled

  aws s3api put-bucket-encryption \
    --bucket "${STATE_BUCKET}" \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        },
        "BucketKeyEnabled": true
      }]
    }'

  aws s3api put-public-access-block \
    --bucket "${STATE_BUCKET}" \
    --public-access-block-configuration '{
      "BlockPublicAcls": true,
      "BlockPublicPolicy": true,
      "IgnorePublicAcls": true,
      "RestrictPublicBuckets": true
    }'

  echo "[DONE] S3 bucket ${STATE_BUCKET} created."
fi

# ─── DynamoDB Table ──────────────────────────────────────────────────────────
if aws dynamodb describe-table --table-name "${LOCK_TABLE}" --region "${REGION}" &>/dev/null; then
  echo "[SKIP] DynamoDB table ${LOCK_TABLE} already exists."
else
  echo "[CREATE] DynamoDB table ${LOCK_TABLE}"
  aws dynamodb create-table \
    --table-name "${LOCK_TABLE}" \
    --region "${REGION}" \
    --attribute-definitions '[
      {"AttributeName": "LockID", "AttributeType": "S"}
    ]' \
    --key-schema '[
      {"AttributeName": "LockID", "KeyType": "HASH"}
    ]' \
    --billing-mode PAY_PER_REQUEST \
    --tags '[
      {"Key": "Project", "Value": "aws-datalake-platform"},
      {"Key": "Purpose", "Value": "terraform-state-locking"}
    ]'

  echo "[DONE] DynamoDB table ${LOCK_TABLE} created."
fi

echo
echo "=== Bootstrap complete. You can now run: ==="
echo "  cd terraform/envs/dev && terraform init"
echo "  cd terraform/envs/prod && terraform init"
