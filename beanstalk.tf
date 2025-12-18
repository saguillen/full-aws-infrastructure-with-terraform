// Elastic Beanstalk application + environment to serve thumbnails
// Creates an S3 bucket for deployment artifacts, uploads the app bundle,
// creates EB application and a load-balanced environment that deploys
// the app into two AZs (subnets provided by existing subnet resources).

locals {
  beanstalk_app_zip = "${path.module}/artifacts/beanstalk_app_package.zip"
}

resource "aws_s3_bucket" "eb_deployments" {
  bucket        = lower("${var.project}-eb-deployments-${var.region}-${data.aws_caller_identity.current.account_id}")
  tags          = merge(var.tags, { Name = "${var.project}-eb-deployments", Project = var.project })
  force_destroy = true # <- vacía el bucket antes de borrarlo
}

resource "aws_s3_bucket_versioning" "eb_deployments_ver" {
  bucket = aws_s3_bucket.eb_deployments.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "eb_deployments_sse" {
  bucket = aws_s3_bucket.eb_deployments.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "beanstalk_app_object" {
  bucket = aws_s3_bucket.eb_deployments.id
  key    = "${var.project}-beanstalk-app.zip"
  source = local.beanstalk_app_zip
}

resource "aws_elastic_beanstalk_application" "app" {
  name        = "${var.project}-beanstalk-app"
  description = "Application that shows thumbnails from S3"
}

resource "aws_elastic_beanstalk_application_version" "app_version" {
  # Use a deterministic name derived from the application artifact contents so a new
  # Elastic Beanstalk application version is created only when the ZIP content changes.
  # We shorten the hash to a manageable label length.
  # Use a hex digest (MD5) so the label contains only safe characters (0-9a-f)
  name        = "v-${substr(filemd5(local.beanstalk_app_zip), 0, 16)}"
  application = aws_elastic_beanstalk_application.app.name

  # point to the S3 object that contains the application bundle
  bucket = aws_s3_bucket.eb_deployments.bucket
  key    = aws_s3_object.beanstalk_app_object.key

  lifecycle {
    ignore_changes = [description]
  }
}

// Instance profile role for EC2 instances in the Beanstalk environment
resource "aws_iam_role" "eb_instance_role" {
  name = "${var.project}-eb-instance-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "eb_instance_s3_policy" {
  name = "${var.project}-eb-instance-s3-access"
  role = aws_iam_role.eb_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["s3:ListBucket"],
        # ListBucket must be granted on the bucket ARN (no trailing /*)
        Resource = "${aws_s3_bucket.thumbnails.arn}"
      },
      {
        Effect = "Allow",
        Action = ["s3:GetObject"],
        Resource = [
          "${aws_s3_bucket.thumbnails.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "eb_instance_profile" {
  name = "${var.project}-eb-instance-profile"
  role = aws_iam_role.eb_instance_role.name
}

// Service role for Beanstalk itself
resource "aws_iam_role" "eb_service_role" {
  name = "${var.project}-eb-service-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = { Service = "elasticbeanstalk.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eb_service_managed" {
  role       = aws_iam_role.eb_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkService"
}

// Attach common managed policy to instance role to allow log delivery etc.
resource "aws_iam_role_policy_attachment" "eb_instance_managed" {
  role       = aws_iam_role.eb_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_elastic_beanstalk_environment" "env" {
  name                = "${var.project}-env"
  application         = aws_elastic_beanstalk_application.app.name
  solution_stack_name = "64bit Amazon Linux 2023 v4.8.0 running Python 3.11"

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "LoadBalanced"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.eb_instance_profile.name
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = aws_vpc.this.id
  }

  // Private subnets for instances (ensure they span two AZs)
  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", aws_subnet.private[*].id)
  }

  // Public subnets for the load balancer
  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBSubnets"
    value     = join(",", aws_subnet.public[*].id)
  }

  // Autoscaling: minimum 2 instances to ensure across two AZs
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = "2"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "4"
  }

  setting {
    namespace = "aws:elasticbeanstalk:xray"
    name      = "XRayEnabled"
    value     = "false"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "THUMBNAILS_BUCKET"
    value     = aws_s3_bucket.thumbnails.bucket
  }

  version_label = aws_elastic_beanstalk_application_version.app_version.name

  lifecycle {
    ignore_changes = [setting]
  }
}
