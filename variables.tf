variable "aws_region" {
  default     = "us-east-1"
  description = "AWS region"
}

variable "project_name" {
  default     = "thumbnail-project"
  description = "Project Name"
}

variable "queue_visibility_timeout" {
  default     = 60
  description = "Visibility timeout for SQS queue in seconds"
}

variable "queue_retention_period" {
  default     = 86400
  description = "Message retention period for SQS queue"
}

variable "lambda_timeout" {
  default     = 30
  description = "Timeout for the Lambda function in seconds"
}

variable "lambda_memory_size" {
  default     = 256
  description = "Memory size for the Lambda function in MB"
}

