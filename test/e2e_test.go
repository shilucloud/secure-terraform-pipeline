package test

import (
	"io"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
)

func TestE2E(t *testing.T) {
	// t.Parallel()

	start := time.Now()
	region := "us-east-1"
	infraDir := "../infrastructure"
	backendFile := filepath.Join(infraDir, "envs/localstack.backend")
	localstackEndpoint := "http://localhost:4566"

	testFileKey := "terratest-test-file.txt"
	testFileName := "../objects/s3_test_object.txt"

	// Terraform Options
	tfOptions := &terraform.Options{
		TerraformBinary: "tflocal",
		TerraformDir:    infraDir,
		NoColor:         true,
		EnvVars: map[string]string{
			"AWS_ACCESS_KEY_ID":     "test",
			"AWS_SECRET_ACCESS_KEY": "test",
			"AWS_DEFAULT_REGION":    region,
			"AWS_ENDPOINT_URL":      localstackEndpoint,
		},
	}

	// Terraform init
	t.Log("🔧 Initializing Terraform with backend config...")
	initArgs := terraform.FormatArgs(tfOptions, "init", "-backend-config="+backendFile)
	if _, err := terraform.RunTerraformCommandE(t, tfOptions, initArgs...); err != nil {
		t.Fatalf("❌ Terraform init failed: %v", err)
	}

	// Terraform apply
	t.Log("🧱 Running terraform apply...")
	if _, err := terraform.ApplyE(t, tfOptions); err != nil {
		t.Fatalf("❌ Terraform apply failed: %v", err)
	}

	// Fetch outputs
	t.Log("📤 Fetching Terraform outputs...")
	outputs := terraform.OutputAll(t, tfOptions)
	bucketName := outputs["bucket_id"].(string)
	t.Logf("🪣 Using bucket: %s", bucketName)

	// AWS Session for LocalStack
	sess := session.Must(session.NewSession(&aws.Config{
		Region:           aws.String(region),
		Endpoint:         aws.String(localstackEndpoint),
		S3ForcePathStyle: aws.Bool(true),
	}))

	s3Client := s3.New(sess)

	// Cleanup: delete all objects & versions, then destroy Terraform at the end
	defer func() {
		t.Logf("🧹 Emptying versioned bucket %s...", bucketName)
		emptyVersionedBucket(t, s3Client, bucketName)

		t.Log("🧹 Destroying Terraform-managed infrastructure...")
		if _, err := terraform.DestroyE(t, tfOptions); err != nil {
			t.Logf("⚠️ Failed to destroy infra: %v", err)
		}
	}()

	// Check if bucket exists
	t.Log("🔍 Verifying S3 bucket existence in LocalStack...")
	_, err := s3Client.HeadBucket(&s3.HeadBucketInput{Bucket: aws.String(bucketName)})
	require.NoErrorf(t, err, "❌ No Bucket Named %s found in LocalStack", bucketName)
	t.Logf("✅ Bucket %s found in LocalStack", bucketName)

	// Upload test file
	t.Log("📤 Uploading test file to bucket...")
	file, err := os.OpenFile(testFileName, os.O_RDONLY, 0644)
	require.NoErrorf(t, err, "❌ Error opening file %s", testFileName)
	defer file.Close()

	_, err = s3Client.PutObject(&s3.PutObjectInput{
		Bucket: aws.String(bucketName),
		Key:    aws.String(testFileKey),
		Body:   file,
	})
	require.NoErrorf(t, err, "❌ Error uploading file %s to bucket %s", testFileName, bucketName)
	t.Logf("✅ Successfully uploaded %s to %s", testFileName, bucketName)

	// Download & verify file
	t.Log("📥 Reading back the uploaded file from S3...")
	result, err := s3Client.GetObject(&s3.GetObjectInput{
		Bucket: aws.String(bucketName),
		Key:    aws.String(testFileKey),
	})
	require.NoErrorf(t, err, "❌ Error downloading file %s from bucket %s", testFileKey, bucketName)
	defer result.Body.Close()

	body, err := io.ReadAll(result.Body)
	require.NoErrorf(t, err, "❌ Failed reading S3 object body from bucket %s", bucketName)

	t.Logf("📄 File content retrieved successfully (%d bytes): %s", len(body), string(body))
	t.Logf("🎉 Test completed successfully in %s", time.Since(start))
}

// Helper function to empty a versioned S3 bucket
func emptyVersionedBucket(t *testing.T, s3Client *s3.S3, bucketName string) {
	for {
		versionsOutput, err := s3Client.ListObjectVersions(&s3.ListObjectVersionsInput{
			Bucket: aws.String(bucketName),
		})
		require.NoError(t, err, "Failed to list object versions")

		if len(versionsOutput.Versions) == 0 && len(versionsOutput.DeleteMarkers) == 0 {
			t.Logf("✅ Bucket %s is now empty", bucketName)
			break
		}

		var objectsToDelete []*s3.ObjectIdentifier
		for _, v := range versionsOutput.Versions {
			objectsToDelete = append(objectsToDelete, &s3.ObjectIdentifier{
				Key:       v.Key,
				VersionId: v.VersionId,
			})
		}
		for _, dm := range versionsOutput.DeleteMarkers {
			objectsToDelete = append(objectsToDelete, &s3.ObjectIdentifier{
				Key:       dm.Key,
				VersionId: dm.VersionId,
			})
		}

		_, err = s3Client.DeleteObjects(&s3.DeleteObjectsInput{
			Bucket: aws.String(bucketName),
			Delete: &s3.Delete{
				Objects: objectsToDelete,
				Quiet:   aws.Bool(true),
			},
		})
		require.NoError(t, err, "Failed to delete object versions")
		t.Logf("🗑 Deleted %d object(s)/versions from bucket %s", len(objectsToDelete), bucketName)
	}
}
