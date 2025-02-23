provider "aws" {
  region = var.aws_region
}

# S3 Bucket for Image Uploads
resource "aws_s3_bucket" "image_bucket" {
  bucket = "${var.project_name}-bucket"
}

resource "aws_s3_bucket_public_access_block" "image_bucket" {
  bucket = aws_s3_bucket.image_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket for Thumbnail Uploads
resource "aws_s3_bucket" "thumbnail_bucket" {
  bucket = "${var.project_name}-thumbnail-bucket"
}

resource "aws_s3_bucket_public_access_block" "thumbnail_bucket" {
  bucket = aws_s3_bucket.thumbnail_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SQS Queue for Processing Events
resource "aws_sqs_queue" "thumbnail_queue" {
  name                      = "${var.project_name}-queue"
  visibility_timeout_seconds = var.queue_visibility_timeout
  message_retention_seconds  = var.queue_retention_period
}

# IAM Role for Lambda Function
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# IAM Policy for Lambda to Access S3, SQS, and Logs
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["s3:GetObject", "s3:PutObject"],
        Resource = [
          "${aws_s3_bucket.image_bucket.arn}/*",
          "${aws_s3_bucket.thumbnail_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"],
        Resource = aws_sqs_queue.thumbnail_queue.arn
      },
      {
        Effect = "Allow",
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow",
        Action = ["cloudwatch:PutMetricData"],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = ["xray:PutTelemetryRecords", "xray:PutTraceSegments"],
        Resource = "*"
      }
    ]
  })
}

# Lambda Function
resource "aws_lambda_function" "thumbnail_generator" {
  filename         = "../thumbnail_generator.zip"
  function_name    = "${var.project_name}-function"
  role            = aws_iam_role.lambda_role.arn
  handler         = "bootstrap"
  runtime         = "provided.al2"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size
  
  environment {
    variables = {
      THUMBNAIL_BUCKET = aws_s3_bucket.thumbnail_bucket.id
    }
  }

  tracing_config {
    mode = "Active"
  }


  depends_on = [
    aws_iam_role_policy.lambda_policy
  ]
}

# S3 Event Notification to SQS
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.image_bucket.id
  
  queue {
    queue_arn     = aws_sqs_queue.thumbnail_queue.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "images/"
  }

  depends_on = [aws_sqs_queue_policy.queue_policy]
}

# Allow S3 to Send Messages to SQS
resource "aws_sqs_queue_policy" "queue_policy" {
  queue_url = aws_sqs_queue.thumbnail_queue.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "s3.amazonaws.com"
      },
      Action = "sqs:SendMessage",
      Resource = aws_sqs_queue.thumbnail_queue.arn,
      Condition = {
        ArnLike = {
          "aws:SourceArn" = aws_s3_bucket.image_bucket.arn
        }
      }
    }]
  })
}

# Connect Lambda to SQS
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.thumbnail_queue.arn
  function_name    = aws_lambda_function.thumbnail_generator.function_name
  batch_size       = 1
}