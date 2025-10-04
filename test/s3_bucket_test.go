package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestS3Bucket(t *testing.T) {

	t.Parallel()

	//bucketName := os.Getenv("TF_VAR_bucket_name")
	//bucketRegion := os.Getenv("TF_VAR_region")
	//testFileKey := "test-object-from-terratest"
	//testFileName := "objects/s3_test_object.txt"

	tfOptions := terraform.Options{
		TerraformDir:    "../infrastructure",
		TerraformBinary: "tflocal",
	}

	_, err := terraform.InitE(t, &tfOptions)
	if err != nil {
		t.Error("Error while init terraform")
	}

	_, err = terraform.PlanE(t, &tfOptions)
	if err != nil {
		t.Error("Error while plan terraform")
	}

	_, err = terraform.ApplyE(t, &tfOptions)
	if err != nil {
		t.Error("Error while apply terraform")
	}

	defer func() {
		_, err := terraform.DestroyE(t, &tfOptions)
		if err != nil {
			t.Error("Error while destroying the Infra")
		}
	}()

	tfOutputs, err := terraform.OutputAllE(t, &tfOptions)
	if err != nil {
		t.Error("Error while getting the output")
	}

	bucketArn := tfOutputs["bucket_arn"]
	bucketID := tfOutputs["bucket_id"]
	bucketDomainName := tfOutputs["bucket_domain_name"]

	assert.NotEmpty(t, bucketArn)
	assert.NotEmpty(t, bucketID)
	assert.NotEmpty(t, bucketDomainName)

	//	err = aws.AssertS3BucketExistsE(t, bucketRegion, bucketName)
	//	if err != nil {
	//		t.Errorf("Error while getting the bucket: %s", bucketName)
	//	}
	//
	//	data, err := os.OpenFile(testFileName, 1, 066)
	//	if err != nil {
	//		t.Errorf("Error while reading file: %s", testFileName)
	//	}
	//	err = aws.PutS3ObjectContentsE(t, bucketRegion, bucketName, testFileKey, data)
	//	if err != nil {
	//		t.Errorf("Error while uploading file to bucket: %s", bucketName)
	//	}

}
