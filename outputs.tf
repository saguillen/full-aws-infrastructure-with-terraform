output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = [for s in aws_subnet.private : s.id]
}

output "nat_gateway_ids" {
  description = "IDs of NAT Gateways"
  value       = [for n in aws_nat_gateway.nat : n.id]
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.igw.id
}

output "uploads_bucket" {
  description = "Name of the uploads S3 bucket"
  value       = aws_s3_bucket.uploads.bucket
}

output "thumbnails_bucket" {
  description = "Name of the thumbnails S3 bucket"
  value       = aws_s3_bucket.thumbnails.bucket
}

output "uploads_bucket_arn" {
  description = "ARN of the uploads S3 bucket"
  value       = aws_s3_bucket.uploads.arn
}

output "thumbnails_bucket_arn" {
  description = "ARN of the thumbnails S3 bucket"
  value       = aws_s3_bucket.thumbnails.arn
}

output "beanstalk_environment_cname" {
  description = "Elastic Beanstalk Environment CNAME"
  value       = aws_elastic_beanstalk_environment.env.cname
}