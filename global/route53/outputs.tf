output "hosted_zone_id" {
  description = "ID of the Route 53 hosted zone"
  value       = aws_route53_zone.main.zone_id
}

output "hosted_zone_name_servers" {
  description = "Name servers of the Route 53 hosted zone"
  value       = aws_route53_zone.main.name_servers
}

output "certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = aws_acm_certificate_validation.main.certificate_arn
}

output "domain_name" {
  description = "Domain name"
  value       = var.domain_name
}