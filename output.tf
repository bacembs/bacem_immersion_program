output "s3_bucket_name" {
  value = aws_s3_bucket.image_bucket.id
}

output "sqs_queue_name" {
  value = aws_sqs_queue.thumbnail_queue.name
}

output "lambda_function_name" {
  value = aws_lambda_function.thumbnail_generator.function_name
}

