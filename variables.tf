variable "function_name" {
  description = "Name of the Lambda function and execution role."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{1,64}$", var.function_name))
    error_message = "function_name must contain 1–64 letters, digits, underscores, or hyphens."
  }
}

variable "description" {
  description = "Description of the Lambda function."
  type        = string
  default     = "WeasyPrint HTML-to-PDF renderer with API-key authentication"
}

variable "image_uri" {
  description = "Immutable ARM64 Lambda-compatible WeasyPrint image URI in the Lambda's AWS region; must enforce API_KEY on conversion routes."
  type        = string
}

variable "api_key" {
  description = "Secret passed to the renderer as API_KEY. Clients send it in X-API-Key. Supply a randomly generated key of at least 32 characters."
  type        = string
  sensitive   = true
  nullable    = false

  validation {
    condition     = length(var.api_key) >= 32 && !can(regex("[\\s,]", var.api_key))
    error_message = "api_key must contain at least 32 characters, without whitespace or commas. Empty keys disable upstream authentication and are not allowed."
  }
}

variable "tags" {
  description = "Additional tags for the Lambda, log group, and execution role."
  type        = map(string)
  default     = {}
}
