# Thumbnail Generator Lambda
This project contains an AWS Lambda function that automatically generates thumbnails for images uploaded to an S3 bucket.

### 1. Clone the Repository

```bash
https://github.com/bacembs/bacem_immersion_program.git
cd bacem_immersion_program
```
### 2. Build the Lambda Function

```bash
./build_lambda.sh
```
### 3. Apply Terraform

```bash
cd infrastructure
terraform init
terraform plan
terraform apply
```