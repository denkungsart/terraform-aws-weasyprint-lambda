locals {
  function_name = var.function_name
}

module "lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 8.0"

  function_name = local.function_name
  description   = var.description

  create_package = false
  package_type   = "Image"
  image_uri      = var.image_uri
  architectures  = ["arm64"]
  publish        = true

  memory_size                    = 4096
  timeout                        = 180
  ephemeral_storage_size         = 1024
  reserved_concurrent_executions = 2

  create_lambda_function_url                   = true
  create_unqualified_alias_lambda_function_url = true
  authorization_type                           = "NONE"
  invoke_mode                                  = "RESPONSE_STREAM"

  logging_log_format                = "JSON"
  cloudwatch_logs_retention_in_days = 90
  attach_cloudwatch_logs_policy     = true
  # Terraform creates the log group; the renderer only writes streams/events.
  attach_create_log_group_permission = false
  attach_tracing_policy              = false

  environment_variables = { API_KEY = var.api_key }

  tags = var.tags
}

# The execution role uses only the scoped inline logging policy above.
resource "aws_iam_role_policy_attachments_exclusive" "execution" {
  role_name   = module.lambda.lambda_role_name
  policy_arns = []

  depends_on = [module.lambda]
}

# The image enforces API-key authentication on conversion routes. These grants
# expose its HTTP endpoint without granting public direct Lambda API invocation.
resource "aws_lambda_permission" "function_url" {
  statement_id           = "AllowPublicFunctionUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = module.lambda.lambda_function_name
  principal              = "*"
  function_url_auth_type = "NONE"

  depends_on = [module.lambda]
}

resource "aws_lambda_permission" "invoke_via_url" {
  statement_id             = "AllowPublicInvokeViaFunctionUrl"
  action                   = "lambda:InvokeFunction"
  function_name            = module.lambda.lambda_function_name
  principal                = "*"
  invoked_via_function_url = true

  depends_on = [module.lambda]
}
