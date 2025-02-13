#!/bin/bash
set -e
# Build Go binary for Lambda
GOOS=linux GOARCH=amd64 go build -o bootstrap thumbnail_generator.go
# Create deployment package
zip thumbnail_generator.zip bootstrap
# Clean binary
rm bootstrap

echo "Build complete! Deployment package: thumbnail_generator.zip"
