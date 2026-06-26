# ---------------------------------------------------------------------------
# Deployment mode
# ---------------------------------------------------------------------------

variable "deploy_ztgw" {
  description = "Deploy a new AWS ZTGW."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Zscaler OneAPI authentication
# ---------------------------------------------------------------------------

variable "client_id" {
  description = "Zscaler OneAPI OAuth2 client ID."
  type        = string
}

variable "client_secret" {
  description = "Zscaler OneAPI OAuth2 client secret."
  type        = string
  sensitive   = true
}

variable "vanity_domain" {
  description = "Zscaler vanity domain (e.g. 'acme' -> acme.zslogin.net)."
  type        = string
}

variable "cloud" {
  description = "Zscaler cloud name: zscaler, zscalerone, zscalertwo, zscalerthree, zscalerbeta."
  type        = string
  default     = "zscalerbeta"
}

# ---------------------------------------------------------------------------
# AWS ZTGW deployment parameters
# ---------------------------------------------------------------------------

variable "gateway_name" {
  description = "Name for the AWS Zero Trust Gateway."
  type        = string
  default     = "aws-ztgw"
}

variable "aws_region" {
  description = <<-EOT
    AWS region (e.g. us-west-2, us-east-1, eu-west-1).
    EOT
  type        = string
  default     = "us-west-2"
}

variable "aws_region_code" {
  description = <<-EOT
    AWS region code in Zscaler format (e.g. US_WEST_2, US_EAST_1, EU_WEST_1).
    This is the uppercase underscored version of the AWS region.
    EOT
  type        = string
  default     = "US_WEST_2"
}

variable "availability_zone_ids" {
  description = <<-EOT
    List of AWS Availability Zone IDs for the ZTGW.
    Use the AZ ID format (e.g. usw2-az1, usw2-az2), not the AZ name.
    Example: ["usw2-az1", "usw2-az2"]
    EOT
  type        = list(string)
  default     = ["usw2-az1", "usw2-az2"]
}

variable "location_name" {
  description = "Location name for the ZTGW (auto-created in Zscaler)."
  type        = string
  default     = "aws-ztgw-location"
}

variable "allowed_accounts" {
  description = <<-EOT
    List of allowed AWS accounts for the ZTGW endpoint service.
    Each entry must have 'id' (integer) and 'name' (string).
    These are configured in your Zscaler admin portal.
    Example: [{id = 12345678, name = "My-AWS-Account"}]
    EOT
  type = list(object({
    id   = number
    name = string
  }))
  default = []
}

variable "account_groups" {
  description = <<-EOT
    List of Zscaler account groups for the ZTGW.
    Each entry must have 'id' (integer) and 'name' (string).
    These are configured in your Zscaler admin portal.
    Example: [{id = 12345678, name = "My-Group"}]
    EOT
  type = list(object({
    id   = number
    name = string
  }))
  default = []
}

variable "location_template_id" {
  description = "Zscaler location template ID (defaults to the 'Default Location Template')."
  type        = number
  default     = 164780
}
