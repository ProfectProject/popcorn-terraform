locals {
  base_tags = merge({ Name = var.zone_name }, var.tags)
}

resource "aws_route53_zone" "this" {
  name = var.zone_name

  tags = local.base_tags
}

resource "aws_acm_certificate" "this" {
  domain_name               = var.zone_name
  validation_method         = "DNS"
  subject_alternative_names = var.subject_alternative_names

  tags = local.base_tags
}

resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id         = aws_route53_zone.this.zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 60
  records         = [each.value.record]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}
