# ─── Remote State Backend ────────────────────────────────────────────────────
# This file documents the backend configuration used by envs/dev and envs/prod.
# The actual backend blocks are in each envs/<env>/backend.tf because Terraform
# does not allow variables in backend blocks.
#
# Prerequisites (run bootstrap/bootstrap.sh once before terraform init):
#   - S3 bucket:    aws-datalake-platform-tf-state
#   - DynamoDB:     aws-datalake-platform-tf-locks
#   - Both created in us-east-1
# ─────────────────────────────────────────────────────────────────────────────
