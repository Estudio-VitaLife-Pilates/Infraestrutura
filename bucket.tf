data "aws_caller_identity" "current" {}

locals {
	data_lake_layers = {
		bronze = "Dados brutos recebidos das fontes"
		silver = "Dados limpos e tratados"
		gold   = "Dados prontos para consumo analítico"
	}
}

resource "aws_s3_bucket" "data_lake" {
	for_each = local.data_lake_layers

	bucket = "${var.project_name}-${each.key}-${data.aws_caller_identity.current.account_id}"

	tags = merge(var.tags, {
		Name        = "${var.project_name}-${each.key}"
		DataLayer   = each.key
		Description = each.value
	})
}

resource "aws_s3_bucket_public_access_block" "data_lake" {
	for_each = aws_s3_bucket.data_lake

	bucket = each.value.id

	block_public_acls       = true
	block_public_policy     = true
	ignore_public_acls      = true
	restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "data_lake" {
	for_each = aws_s3_bucket.data_lake

	bucket = each.value.id

	rule {
		object_ownership = "BucketOwnerEnforced"
	}
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
	for_each = aws_s3_bucket.data_lake

	bucket = each.value.id

	rule {
		apply_server_side_encryption_by_default {
			sse_algorithm = "AES256"
		}
	}
}

resource "aws_s3_bucket_versioning" "data_lake" {
	for_each = aws_s3_bucket.data_lake

	bucket = each.value.id

	versioning_configuration {
		status = "Enabled"
	}
}
