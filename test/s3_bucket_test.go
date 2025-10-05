package test

import (
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestS3Bucket(t *testing.T) {
	//t.Parallel()

	start := time.Now()

	// Use the test logger from Terratest's options (new-style)
	tfOptions := &terraform.Options{
		TerraformDir:    "../infrastructure",
		TerraformBinary: "tflocal", // For LocalStack
		NoColor:         true,
		EnvVars: map[string]string{
			"AWS_ACCESS_KEY_ID":     "test",
			"AWS_SECRET_ACCESS_KEY": "test",
			"AWS_DEFAULT_REGION":    "us-east-1",
		},
	}

	t.Log("🚀 Starting Terraform test for S3 bucket using LocalStack...")

	// Ensure resources are destroyed at the end
	defer func() {
		t.Log("🧹 Cleaning up Terraform-managed infrastructure...")
		if _, err := terraform.DestroyE(t, tfOptions); err != nil {
			t.Logf("⚠️  Failed to destroy infra: %v", err)
		}
	}()

	// Init and apply Terraform
	t.Log("🧱 Running terraform init & apply...")
	if _, err := terraform.InitAndApplyE(t, tfOptions); err != nil {
		t.Fatalf("❌ Terraform apply failed: %v", err)
	}

	// Fetch outputs
	t.Log("📤 Fetching Terraform outputs...")
	outputs := terraform.OutputAll(t, tfOptions)

	// Validate outputs
	required := []string{"bucket_arn", "bucket_id", "bucket_domain_name"}
	for _, key := range required {
		value, ok := outputs[key].(string)
		require.Truef(t, ok, "Output '%s' missing or not string", key)
		assert.NotEmptyf(t, value, "Output '%s' should not be empty", key)
		t.Logf("✅ Output %s: %s", key, value)
	}

	// Additional format checks
	assert.Contains(t, outputs["bucket_arn"], "arn:aws:s3", "Bucket ARN format is invalid")
	assert.Contains(t, outputs["bucket_domain_name"], "s3", "Bucket domain name looks invalid")

	duration := time.Since(start)
	t.Logf("🎉 Test completed successfully in %s", duration)
}
