terraform {
  backend "s3" {
    profile        = "default"
    bucket         = "master-cloud-terraform-state-us-east-2-005423366133"
    key            = "06-demo-final/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "master-cloud-terraform-state-locks-us-east-2-005423366133"
    encrypt        = true
  }
}
