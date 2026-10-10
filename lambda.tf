data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

resource "aws_lambda_function" "datainjector_bronze" {
  function_name = var.function_name
  role          = data.aws_iam_role.lab_role.arn
  handler       = "app.lambda_handler"
  runtime       = "python3.12"

  filename = "${path.module}/lambda.zip"

  timeout     = 120
  memory_size = 256

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash
    ]
  }
}