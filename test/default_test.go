package test

import (
	"os"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func TestDefault(t *testing.T) {
	t.Parallel()

	terraformPath := test_structure.CopyTerraformFolderToTemp(t, "../", "examples/default")

	asgOptions := configASG(t)

	defer terraform.Destroy(t, asgOptions)
	terraform.InitAndApply(t, asgOptions)

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: terraformPath,
		Vars: map[string]interface{}{
			"endpoint_id": os.Getenv("MARBOT_ENDPOINT_ID"),
			"auto_scaling_group_name": terraform.Output(t, asgOptions, "auto_scaling_group_name"),
		},
	})

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)
}
