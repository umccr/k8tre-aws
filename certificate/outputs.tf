locals {
  domain_validation_options = var.request_acm_certificate ? aws_acm_certificate.certificate[0].domain_validation_options : tolist([])
  domain_validation_records = { for dvo in local.domain_validation_options : dvo.domain_name => {
    name   = dvo.resource_record_name
    record = dvo.resource_record_value
    type   = dvo.resource_record_type
    }
  }
}

output "dns_validation_records" {
  description = "DNS validation records to be created for ACM certificate"
  value       = local.domain_validation_records
}
