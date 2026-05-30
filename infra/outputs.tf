output "alb_dns_name" {
  description = "ALB DNS name - paste this in your browser"
  value       = aws_lb.main.dns_name
}

output "rds_endpoint" {
  description = "RDS endpoint - use this in Flask config"
  value       = aws_db_instance.main.address
}

output "sns_topic_arn" {
  description = "SNS topic ARN - use this in Flask config"
  value       = aws_sns_topic.main.arn
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "cloudfront_domain" {
  description = "CloudFront domain name"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "shop_url" {
  description = "Live site URL"
  value       = "https://shop.kevinlutes.com"
}