# Plan resource permissions without AWS access; replace the child module's outputs.
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "testing"
  secret_key                  = "testing"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

override_module {
  target = module.lambda
  outputs = {
    lambda_function_arn  = "arn:aws:lambda:us-east-1:123456789012:function:weasyprint-test"
    lambda_function_name = "weasyprint-test"
    lambda_function_url  = "https://example.lambda-url.us-east-1.on.aws/"
    lambda_role_name     = "weasyprint-test"
  }
}

variables {
  function_name = "weasyprint-test"
  image_uri     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/example-renderer:release-arm64"
  api_key       = "test-key-with-at-least-thirty-two-characters"
}

run "public_access_is_restricted_to_function_url" {
  command = plan

  assert {
    condition = (
      aws_lambda_permission.function_url.action == "lambda:InvokeFunctionUrl" &&
      aws_lambda_permission.function_url.function_url_auth_type == "NONE" &&
      aws_lambda_permission.function_url.principal == "*" &&
      aws_lambda_permission.function_url.function_name == "weasyprint-test" &&
      aws_lambda_permission.invoke_via_url.action == "lambda:InvokeFunction" &&
      aws_lambda_permission.invoke_via_url.invoked_via_function_url == true &&
      aws_lambda_permission.invoke_via_url.principal == "*" &&
      aws_lambda_permission.invoke_via_url.function_name == "weasyprint-test"
    )
    error_message = "Public invocation must be limited to this function's HTTP URL, without granting direct Lambda API access."
  }

  assert {
    condition     = length(aws_iam_role_policy_attachments_exclusive.execution.policy_arns) == 0
    error_message = "The renderer must not acquire managed policies beyond its scoped inline logging policy."
  }
}

run "reject_empty_key" {
  command = plan
  variables { api_key = "" }
  expect_failures = [var.api_key]
}

run "reject_whitespace_key" {
  command = plan
  variables { api_key = "                                " }
  expect_failures = [var.api_key]
}

run "reject_short_key" {
  command = plan
  variables { api_key = "short-key" }
  expect_failures = [var.api_key]
}

run "reject_key_list_with_empty_entry" {
  command = plan
  variables { api_key = "test-key-with-at-least-thirty-two-characters," }
  expect_failures = [var.api_key]
}
