project_name = "aws-datalake-platform"
environment  = "dev"
aws_region   = "us-east-1"

# Replace with your actual email address
alert_email  = "your-email@example.com"

cities = [
  { name = "New York",  latitude = 40.7128,  longitude = -74.0060  },
  { name = "London",    latitude = 51.5074,  longitude = -0.1278   },
  { name = "Tokyo",     latitude = 35.6762,  longitude = 139.6503  },
  { name = "Paris",     latitude = 48.8566,  longitude = 2.3522    },
  { name = "Sydney",    latitude = -33.8688, longitude = 151.2093  }
]

# Dev: run more frequently for faster testing feedback
batch_schedule     = "rate(1 hour)"
stream_schedule    = "rate(5 minutes)"
transform_schedule = "rate(30 minutes)"
