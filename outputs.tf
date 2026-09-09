output "function_url" {
  description = "HTTPS Function URL. Conversion requests require the configured X-API-Key."
  value       = module.lambda.lambda_function_url
}

output "function_name" {
  description = "WeasyPrint Lambda function name."
  value       = module.lambda.lambda_function_name
}
