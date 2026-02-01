variable "environment" {
  type = string
}

variable "project_name" {
  type = string
}

variable "glue_role_arn" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "datalake_bucket_id" {
  type = string
}

variable "datalake_bucket_arn" {
  type = string
}

# ─── Glue Data Catalog Database ──────────────────────────────────────────────
resource "aws_glue_catalog_database" "datalake" {
  name = "${var.project_name}_${var.environment}"

  description = "Data catalog for ${var.project_name} (${var.environment})"

  catalog_id = data.aws_caller_identity.current.account_id
}

data "aws_caller_identity" "current" {}

# ─── Glue Catalog Table: raw_weather ─────────────────────────────────────────
resource "aws_glue_catalog_table" "raw_weather" {
  name          = "raw_weather"
  database_name = aws_glue_catalog_database.datalake.name
  catalog_id    = data.aws_caller_identity.current.account_id

  table_input {
    description       = "Raw weather data ingested from Open-Meteo API"
    retention         = 0
    storage_descriptor {
      location      = "s3://${var.datalake_bucket_id}/raw/weather/"
      input_format  = "org.apache.hadoop.mapred.TextInputFormat"
      output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"
      serde {
        serialization_library = "org.apache.hadoop.hive.serde2.OpenCSVSerde"
      }

      columns {
        name = "ingestion_id"
        type = "string"
      }
      columns {
        name = "city"
        type = "string"
      }
      columns {
        name = "latitude"
        type = "double"
      }
      columns {
        name = "longitude"
        type = "double"
      }
      columns {
        name = "timestamp"
        type = "string"
      }
      columns {
        name = "temperature_c"
        type = "double"
      }
      columns {
        name = "humidity_pct"
        type = "double"
      }
      columns {
        name = "windspeed_kmh"
        type = "double"
      }
      columns {
        name = "precipitation_mm"
        type = "double"
      }
      columns {
        name = "ingested_at"
        type = "string"
      }
    }

    partition_keys {
      name = "date"
      type = "string"
    }
  }
}

# ─── Glue Catalog Table: raw_iot_sensors ─────────────────────────────────────
resource "aws_glue_catalog_table" "raw_iot_sensors" {
  name          = "raw_iot_sensors"
  database_name = aws_glue_catalog_database.datalake.name
  catalog_id    = data.aws_caller_identity.current.account_id

  table_input {
    description       = "Raw IoT sensor events from Kinesis Firehose"
    retention         = 0
    storage_descriptor {
      location      = "s3://${var.datalake_bucket_id}/raw/iot-sensors/"
      input_format  = "org.apache.hadoop.mapred.TextInputFormat"
      output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"
      serde {
        serialization_library = "org.apache.hadoop.hive.serde2.JsonSerDe"
      }

      columns {
        name = "sensor_id"
        type = "string"
      }
      columns {
        name = "city"
        type = "string"
      }
      columns {
        name = "timestamp"
        type = "string"
      }
      columns {
        name = "temperature_c"
        type = "double"
      }
      columns {
        name = "humidity_pct"
        type = "double"
      }
      columns {
        name = "aqi"
        type = "double"
      }
      columns {
        name = "battery_level"
        type = "double"
      }
    }

    partition_keys {
      name = "year"
      type = "string"
    }
    partition_keys {
      name = "month"
      type = "string"
    }
    partition_keys {
      name = "day"
      type = "string"
    }
  }
}

# ─── Glue Catalog Table: curated_weather ─────────────────────────────────────
resource "aws_glue_catalog_table" "curated_weather" {
  name          = "curated_weather"
  database_name = aws_glue_catalog_database.datalake.name
  catalog_id    = data.aws_caller_identity.current.account_id

  table_input {
    description       = "Cleaned and partitioned weather data (Parquet)"
    retention         = 0
    storage_descriptor {
      location      = "s3://${var.datalake_bucket_id}/curated/weather/"
      input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
      output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
      serde {
        serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      }

      columns {
        name = "ingestion_id"
        type = "string"
      }
      columns {
        name = "city"
        type = "string"
      }
      columns {
        name = "latitude"
        type = "double"
      }
      columns {
        name = "longitude"
        type = "double"
      }
      columns {
        name = "timestamp"
        type = "string"
      }
      columns {
        name = "temperature_c"
        type = "double"
      }
      columns {
        name = "humidity_pct"
        type = "double"
      }
      columns {
        name = "windspeed_kmh"
        type = "double"
      }
      columns {
        name = "precipitation_mm"
        type = "double"
      }
      columns {
        name = "ingested_at"
        type = "string"
      }
      columns {
        name = "temperature_f"
        type = "double"
      }
    }

    partition_keys {
      name = "date"
      type = "string"
    }
  }
}

# ─── Glue Catalog Table: curated_sensor_readings ─────────────────────────────
resource "aws_glue_catalog_table" "curated_sensor_readings" {
  name          = "curated_sensor_readings"
  database_name = aws_glue_catalog_database.datalake.name
  catalog_id    = data.aws_caller_identity.current.account_id

  table_input {
    description       = "Pseudonymized and validated IoT sensor readings (Parquet)"
    retention         = 0
    storage_descriptor {
      location      = "s3://${var.datalake_bucket_id}/curated/sensor-readings/"
      input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
      output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"
      serde {
        serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      }

      columns {
        name = "sensor_id_hash"
        type = "string"
      }
      columns {
        name = "city"
        type = "string"
      }
      columns {
        name = "timestamp"
        type = "string"
      }
      columns {
        name = "temperature_c"
        type = "double"
      }
      columns {
        name = "humidity_pct"
        type = "double"
      }
      columns {
        name = "aqi"
        type = "double"
      }
      columns {
        name = "battery_level"
        type = "double"
      }
      columns {
        name = "quality_score"
        type = "string"
      }
    }

    partition_keys {
      name = "date"
      type = "string"
    }
  }
}

# ─── Upload Glue Script to S3 ────────────────────────────────────────────────
resource "aws_s3_object" "glue_transform_script" {
  bucket      = var.datalake_bucket_id
  key         = "glue-scripts/transform.py"
  source      = "${path.module}/../../scripts/glue_transform/transform.py"
  content_type = "text/x-python"

  etag = filemd5("${path.module}/../../scripts/glue_transform/transform.py")

  server_side_encryption = "aws:kms"
  kms_key_id             = var.kms_key_arn
}

# ─── Glue Job: Transform ─────────────────────────────────────────────────────
resource "aws_glue_job" "transform" {
  name     = "${var.project_name}-transform-${var.environment}"
  role_arn = var.glue_role_arn

  command {
    name         = "glueetl"
    script_location = "s3://${var.datalake_bucket_id}/glue-scripts/transform.py"
  }

  default_arguments = {
    "--job-language"            = "python"
    "--TempDir"                 = "s3://${var.datalake_bucket_id}/glue-temp/"
    "--enable-metrics"          = "true"
    "--enable-continuous-logging" = "true"
    "--continuous-logging-level" = "INFO"
    "--DATALAKE_BUCKET"         = var.datalake_bucket_id
    "--ENVIRONMENT"             = var.environment
    "--DATABASE_NAME"           = aws_glue_catalog_database.datalake.name
    "--KMS_KEY_ARN"             = var.kms_key_arn
  }

  max_concurrent_runs = 1
  glue_version        = "4.0"

  resource_config {
    node_type      = "G.1X"
    number_of_nodes = 2
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# ─── Outputs ─────────────────────────────────────────────────────────────────
output "glue_database_name" {
  value = aws_glue_catalog_database.datalake.name
}

output "glue_job_name" {
  value = aws_glue_job.transform.name
}
