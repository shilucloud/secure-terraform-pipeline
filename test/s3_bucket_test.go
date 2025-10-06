package test

import (
	"path/filepath"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestS3Bucket(t *testing.T) {
	start := time.Now()
	t.Log("🚀 Starting Terraform test for S3 bucket using LocalStack...")

	infraDir := "../infrastructure"
	backendFile := filepath.Join(infraDir, "envs/localstack.backend")

	// Terraform test options
	tfOptions := &terraform.Options{
		TerraformDir:    infraDir,
		TerraformBinary: "tflocal", // Use LocalStack’s Terraform wrapper
		NoColor:         true,
		EnvVars: map[string]string{
			"AWS_ACCESS_KEY_ID":     "test",
			"AWS_SECRET_ACCESS_KEY": "test",
			"AWS_DEFAULT_REGION":    "us-east-1",
			"AWS_ENDPOINT_URL":      "http://localhost:4566",
		},
	}

	// Run `terraform init -backend-config=envs/localstack.backend`
	t.Log("🔧 Initializing Terraform with backend config...")
	initArgs := terraform.FormatArgs(tfOptions, "init", "-backend-config="+backendFile)
	if _, err := terraform.RunTerraformCommandE(t, tfOptions, initArgs...); err != nil {
		t.Fatalf("❌ Terraform init failed: %v", err)
	}

	// Run `terraform apply`
	t.Log("🧱 Running terraform apply...")
	if _, err := terraform.ApplyE(t, tfOptions); err != nil {
		t.Fatalf("❌ Terraform apply failed: %v", err)
	}

	// Cleanup at the end
	defer func() {
		t.Log("🧹 Cleaning up Terraform-managed infrastructure...")
		if _, err := terraform.DestroyE(t, tfOptions); err != nil {
			t.Logf("⚠️ Failed to destroy infra: %v", err)
		}
	}()

	// Fetch outputs
	t.Log("📤 Fetching Terraform outputs...")
	outputs := terraform.OutputAll(t, tfOptions)

	// Validate outputs
	required := []string{"bucket_arn", "bucket_id", "bucket_domain_name"}
	for _, key := range required {
		value, ok := outputs[key].(string)
		require.Truef(t, ok, "Output '%s' missing or not a string", key)
		assert.NotEmptyf(t, value, "Output '%s' should not be empty", key)
		t.Logf("✅ Output %s: %s", key, value)
	}

	// Additional validations
	assert.Contains(t, outputs["bucket_arn"], "arn:aws:s3", "Bucket ARN format invalid")
	assert.Contains(t, outputs["bucket_domain_name"], "s3", "Bucket domain name looks invalid")

	duration := time.Since(start)
	t.Logf("🎉 Test completed successfully in %s", duration)
}
