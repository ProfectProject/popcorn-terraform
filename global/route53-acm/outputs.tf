output "zone_id" {
  value = module.route53_acm.zone_id
}

output "name_servers" {
  value = module.route53_acm.name_servers
}

output "certificate_arn" {
  value = module.route53_acm.certificate_arn
}
