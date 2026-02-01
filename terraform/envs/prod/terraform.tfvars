project_name = "aws-datalake-platform"
environment  = "prod"
aws_region   = "us-east-1"

# alert_email is intentionally omitted here.
# Set it via: source scripts/load-env.sh   (reads from .env)

cities = [
  { name = "New York",    latitude = 40.7128,  longitude = -74.0060  },
  { name = "London",      latitude = 51.5074,  longitude = -0.1278   },
  { name = "Tokyo",       latitude = 35.6762,  longitude = 139.6503  },
  { name = "Paris",       latitude = 48.8566,  longitude = 2.3522    },
  { name = "Sydney",      latitude = -33.8688, longitude = 151.2093  },
  { name = "Dubai",       latitude = 25.2048,  longitude = 55.2708   },
  { name = "São Paulo",   latitude = -23.5505, longitude = -46.6333  },
  { name = "Mumbai",      latitude = 19.0760,  longitude = 72.8777   }
]

# Prod: production schedules
batch_schedule     = "cron(0 6 * * ? *)"    # 6 AM UTC daily
stream_schedule    = "rate(5 minutes)"
transform_schedule = "rate(1 hour)"
