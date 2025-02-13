#!/bin/bash
set -e

# Build the Go binary for AWS Lambda
GOOS=linux GOARCH=amd64 go build -o bootstrap thumbnail_generator.go

# Create the deployment package
zip thumbnail_generator.zip bootstrap

# Clean up the binary
rm bootstrap

echo "Build complete! Deployment package: thumbnail_generator.zip"