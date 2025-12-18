// Use pre-built, static artifacts to avoid archive content changing on every apply.
// Run the scripts in `scripts/` to regenerate these zips deterministically.
// See scripts/package_*.sh

locals {
  lambda_zip_path       = "${path.module}/artifacts/lambda_package.zip"
  lambda_layer_zip_path = "${path.module}/artifacts/lambda_layer_package.zip"
}

resource "aws_iam_role" "lambda_exec" {
  name = "${var.project}-lambda-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
      }
    ]
  })
  tags = merge(var.tags, { Name = "${var.project}-lambda-role", Project = var.project })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project}-lambda-policy"
  role = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ],
        Resource = [
          "${aws_s3_bucket.uploads.arn}/*",
          "${aws_s3_bucket.thumbnails.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_lambda_function" "thumbnailer" {
  filename         = local.lambda_zip_path
  function_name    = "${var.project}-thumbnailer"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = filebase64sha256(local.lambda_zip_path)

  layers = [aws_lambda_layer_version.pil_layer.arn]

  environment {
    variables = {
      THUMBNAILS_BUCKET = aws_s3_bucket.thumbnails.bucket
      WATERMARK_TEXT    = "© ${var.project}"
    }
  }

  tags = merge(var.tags, { Name = "${var.project}-thumbnailer", Project = var.project })
}

resource "aws_cloudwatch_log_group" "thumbnailer" {
  # Use the same logical lambda name so we avoid circular references
  name              = "/aws/lambda/${var.project}-thumbnailer"
  retention_in_days = 30
  tags              = merge(var.tags, { Name = "${var.project}-thumbnailer-logs", Project = var.project })
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.thumbnailer.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.uploads.arn
}

resource "aws_s3_bucket_notification" "uploads_notify" {
  bucket = aws_s3_bucket.uploads.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.thumbnailer.arn
    events              = ["s3:ObjectCreated:Put"]
    filter_prefix       = ""
    filter_suffix       = ""
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

resource "aws_lambda_layer_version" "pil_layer" {
  filename            = local.lambda_layer_zip_path
  layer_name          = "${var.project}-pil"
  compatible_runtimes = ["python3.11"]
  description         = "Pillow layer for image processing"
  source_code_hash    = filebase64sha256(local.lambda_layer_zip_path)
}
