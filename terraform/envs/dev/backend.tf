terraform {
  backend "s3" {
    bucket         = "aws-datalake-platform-tf-state"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "aws-datalake-platform-tf-locks"
    encrypt        = true
  }
}
