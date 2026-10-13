resource "aws_glue_catalog_database" "logs" {
  name        = "infra_pilates_logs"
  description = "Catalogo dos logs NDJSON armazenados no bucket bronze"
}

resource "aws_glue_crawler" "logs" {
  name          = "infra-pilates-logs"
  database_name = aws_glue_catalog_database.logs.name
  role          = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  table_prefix  = "pilates_"

  s3_target {
    path = "s3://infra-pilates-bronze/logs/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  recrawl_policy {
    recrawl_behavior = "CRAWL_EVERYTHING"
  }
}

resource "aws_athena_workgroup" "logs" {
  name        = "infra-pilates-logs"
  description = "Consultas Athena para logs do bucket bronze"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://infra-pilates-bronze/athena-results/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
}
