package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func configASG(t *testing.T) *terraform.Options {
	asgPath := test_structure.CopyTerraformFolderToTemp(t, "../", "examples/asg")

	return terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: asgPath,
	})
}
