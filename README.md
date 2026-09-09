# Terraform AWS WeasyPrint Lambda

Deploy an ARM64 WeasyPrint container on AWS Lambda with a streaming HTTPS Function URL and API-key authentication for PDF conversion.

## Usage

Supply a Lambda-compatible image meeting the [image requirements](#image-requirements) below. The consuming stack supplies naming, image selection, and application configuration.

```hcl
resource "random_password" "renderer_api_key" {
  length  = 64
  special = false
}

module "renderer" {
  source = "git::https://github.com/denkungsart/terraform-aws-weasyprint-lambda.git?ref=v1.0.0"

  function_name = "html-to-pdf"
  image_uri     = var.renderer_image_uri
  api_key       = random_password.renderer_api_key.result

  tags = { service = "pdf-renderer" }
}
```

Configure the client with `module.renderer.function_url` and the same secret. Send conversion requests with `X-API-Key: <secret>`, for example `POST /convert/html` with `Content-Type: text/html; charset=utf-8` and the HTML document as its body. AWS credentials and request signing are unnecessary.

The bare Function URL (`/`) has no route and returns `404 {"detail":"Not Found"}`. Use `GET /health` for health checks and `POST /convert/html` for HTML conversion. For example:

```http
POST /convert/html?pdf_variant=pdf%2Fua-1&file_name=document.pdf
Content-Type: text/html; charset=utf-8
X-API-Key: <secret>

<!doctype html><html lang="en"><head><title>Example</title></head><body><p>Hello</p></body></html>
```

## Image requirements

Use an immutable ARM64 Lambda-compatible image based on [weasyprint-service](https://github.com/SchweizerischeBundesbahnen/weasyprint-service) 69.0.1 or later with `API_KEY` support, and Lambda Web Adapter configured for response streaming. Upstream 69.0.0 ignores `API_KEY` and is unsuitable for this module.

The image and Lambda must be in the [same AWS region](https://docs.aws.amazon.com/lambda/latest/dg/images-create.html), including when ECR belongs to another account. The module does not build images, publish releases, configure replication, or manage repository policies.

For cross-account ECR, configure image retrieval permissions for the deploying account and the Lambda service in every destination region. [ECR replication](https://docs.aws.amazon.com/AmazonECR/latest/userguide/replication.html) does not copy repository permissions by default. Repository creation templates can set permissions on future replicas; existing repositories need their policies checked separately. An image can be present in the correct region and still fail Lambda creation with ECR access denied if that regional policy is missing.

## Authentication

The Function URL uses `NONE` authorization at the AWS layer; the container enforces `API_KEY` on conversion routes. Use an image that implements this contract: older images ignore the key and would leave conversion unauthenticated. This module requires one key of at least 32 characters without commas or whitespace, preventing configurations that disable upstream authentication.

Upstream health, version, dashboard, and documentation routes remain public. Rejected conversion requests still invoke Lambda. API-key authentication does not restrict URLs or file access within submitted HTML; use a suitably hardened renderer for untrusted documents.

The function resource policy grants both permissions required by [AWS Function URLs](https://docs.aws.amazon.com/lambda/latest/dg/urls-auth.html), with `lambda:InvokeFunction` restricted to invocation through the URL. The execution role has scoped CloudWatch logging permissions. The module creates no caller IAM users, access keys, or invoker roles.

`api_key` is sensitive in Terraform output, but is stored in Terraform state and the Lambda environment. Protect state access. Coordinate key changes with clients; replacing a generated key changes authentication immediately when the function configuration is updated.

## Configuration

| Input | Required | Description |
| --- | --- | --- |
| `function_name` | Yes | Function and execution-role name, 1–64 letters, digits, underscores, or hyphens |
| `image_uri` | Yes | Immutable ARM64 image URI in the provider's region |
| `api_key` | Yes | Sensitive, randomly generated conversion key, at least 32 characters |
| `description` | No | Lambda description |
| `tags` | No | Resource tags; defaults to an empty map |

Outputs are `function_url` and `function_name`. Region, credentials, naming, image registry, and application configuration belong to the caller.

The function uses 4096 MiB memory, a 180-second timeout, 1024 MiB ephemeral storage, reserved concurrency 2, JSON logs with 90-day retention, and `RESPONSE_STREAM`. Versions are published; the URL follows `$LATEST`. Terraform creates the log group, so the execution role needs only stream creation and log-event writes. No VPC or provisioned concurrency is configured.

Requires Terraform >= 1.5.7, AWS provider >= 6.28 and < 7.0, and `terraform-aws-modules/lambda/aws ~> 8.0`. The example also uses the Random provider.

## Development

Terraform 1.7 or later is required for the tests:

```sh
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
terraform test
```

Tests plan URL-only public permissions and reject unsafe key configurations without contacting AWS.

## License

MIT. See [LICENSE](LICENSE).
