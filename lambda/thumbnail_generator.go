package main

import (
    "bytes"
    "context"
    "encoding/json"
    "fmt"
    "image"
    "image/jpeg"
    "log"
    "os"
    "time"

    "github.com/aws/aws-lambda-go/events"
    "github.com/aws/aws-lambda-go/lambda"
    "github.com/aws/aws-sdk-go/aws"
    "github.com/aws/aws-sdk-go/aws/session"
    "github.com/aws/aws-sdk-go/service/cloudwatch"
    "github.com/aws/aws-sdk-go/service/s3"
    "github.com/aws/aws-sdk-go/service/s3/s3iface"
    "github.com/nfnt/resize"
)

var (
    s3Client         s3iface.S3API
    cloudwatchClient *cloudwatch.CloudWatch
    thumbnailBucket  string
)

func init() {
    sess := session.Must(session.NewSession())
    s3Client = s3.New(sess)
    cloudwatchClient = cloudwatch.New(sess)
    thumbnailBucket = os.Getenv("THUMBNAIL_BUCKET")
}

func sendMetrics(resizeTime float64) {
    _, err := cloudwatchClient.PutMetricData(&cloudwatch.PutMetricDataInput{
        Namespace: aws.String("ThumbnailGeneration"),
        MetricData: []*cloudwatch.MetricDatum{
            {
                MetricName: aws.String("ThumbnailsGenerated"),
                Value:      aws.Float64(1),
                Unit:       aws.String(cloudwatch.StandardUnitCount),
            },
            {
                MetricName: aws.String("ThumbnailGenerationTime"),
                Value:      aws.Float64(resizeTime),
                Unit:       aws.String(cloudwatch.StandardUnitSeconds),
            },
        },
    })
    if err != nil {
        log.Printf("Failed to send metrics: %v", err)
    }
}

func processImage(bucketName, fileKey string) error {
    startTime := time.Now()
    // Get original image
    result, err := s3Client.GetObject(&s3.GetObjectInput{
        Bucket: aws.String(bucketName),
        Key:    aws.String(fileKey),
    })
    if err != nil {
        return fmt.Errorf("failed to get object: %w", err)
    }
    defer result.Body.Close()

    // Decode image
    img, _, err := image.Decode(result.Body)
    if err != nil {
        return fmt.Errorf("failed to decode image: %w", err)
    }

    // Resize image
    resizedImg := resize.Resize(128, 128, img, resize.Lanczos3)
    // Encode to JPEG
    buf := new(bytes.Buffer)
    if err := jpeg.Encode(buf, resizedImg, nil); err != nil {
        return fmt.Errorf("failed to encode image: %w", err)
    }
    // Upload thumbnail
    _, err = s3Client.PutObject(&s3.PutObjectInput{
        Bucket: aws.String(thumbnailBucket),
        Key:    aws.String(fmt.Sprintf("thumbnails/%s", fileKey)),
        Body:   bytes.NewReader(buf.Bytes()),
    })
    if err != nil {
        return fmt.Errorf("failed to upload thumbnail: %w", err)
    }

    // Send metrics
    sendMetrics(time.Since(startTime).Seconds())
    return nil
}

func lambdaHandler(ctx context.Context, sqsEvent events.SQSEvent) error {
    for _, message := range sqsEvent.Records {
        // Parse S3 event directly from SQS message body
        var s3Event events.S3Event
        if err := json.Unmarshal([]byte(message.Body), &s3Event); err != nil {
            log.Printf("Error parsing S3 event: %v", err)
            continue
        }
        // Skip test events
        if len(s3Event.Records) == 0 {
            log.Println("Received empty S3 event - skipping")
            continue
        }
        // Process each record
        for _, record := range s3Event.Records {
            bucket := record.S3.Bucket.Name
            key := record.S3.Object.Key

            if err := processImage(bucket, key); err != nil {
                log.Printf("Error processing %s: %v", key, err)
            }
        }
    }
    return nil
}

func main() {
    lambda.Start(lambdaHandler)
}