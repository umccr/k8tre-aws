variable "domain_name" {
  type        = string
  description = "Domain for the certificate, can be a wildcard"
}

variable "subject_alternative_names" {
  type        = list(string)
  default     = []
  description = "Subject alternative names (SANs), ignored for self-signed certificate"
}

variable "organisation" {
  type        = string
  default     = "TREvolution"
  description = "Organisation, only used for self signed certificate"
}

variable "request_acm_certificate" {
  type        = bool
  default     = true
  description = <<-EOT
  Request an AWS ACM certificate, this will require DNS validation records to be manually
  created (https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html).
  This module does not automatically create them since we don't have full control of
  the domain.
  Set this to false to generate a self-signed certificate for testing.
  EOT
}
