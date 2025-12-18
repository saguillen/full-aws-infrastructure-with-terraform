data "aws_caller_identity" "current" {}

locals {
  uploads_bucket_name    = lower("${var.project}-uploads-${var.region}-${data.aws_caller_identity.current.account_id}")
  thumbnails_bucket_name = lower("${var.project}-thumbnails-${var.region}-${data.aws_caller_identity.current.account_id}")
}

resource "aws_s3_bucket" "uploads" {
  bucket        = local.uploads_bucket_name
  tags          = merge(var.tags, { Name = "${var.project}-uploads", Project = var.project })
  force_destroy = true # <- vacía el bucket antes de borrarlo
}

// Lifecycle configuration is now handled by a separate resource to avoid provider deprecation

resource "aws_s3_bucket_lifecycle_configuration" "uploads_lifecycle" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    id     = "transition-to-glacier-after-1-day"
    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = 1
      storage_class = "GLACIER"
    }

    noncurrent_version_transition {
      noncurrent_days = 1
      storage_class = "GLACIER"
    }
  }
}

resource "aws_s3_bucket_versioning" "uploads_ver" {
  bucket = aws_s3_bucket.uploads.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "uploads_sse" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "uploads_block" {
  bucket                  = aws_s3_bucket.uploads.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "thumbnails" {
  bucket        = local.thumbnails_bucket_name
  tags          = merge(var.tags, { Name = "${var.project}-thumbnails", Project = var.project })
  force_destroy = true # <- vacía el bucket antes de borrarlo
}

resource "aws_s3_bucket_versioning" "thumbnails_ver" {
  bucket = aws_s3_bucket.thumbnails.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "thumbnails_sse" {
  bucket = aws_s3_bucket.thumbnails.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "thumbnails_block" {
  bucket                  = aws_s3_bucket.thumbnails.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
