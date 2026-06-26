# ---------------------------------------------------------------------------
# Provider side: AWS Zero Trust Gateway (via Zscaler REST API)
# ---------------------------------------------------------------------------

data "external" "ztgw" {
  count   = var.deploy_ztgw ? 1 : 0
  program = ["bash", "${path.module}/scripts/deploy_ztgw.sh"]

  query = {
    client_id              = var.client_id
    client_secret          = var.client_secret
    vanity_domain          = var.vanity_domain
    cloud                  = var.cloud
    gateway_name           = var.gateway_name
    aws_region             = var.aws_region
    aws_region_code        = var.aws_region_code
    availability_zone_ids  = jsonencode(var.availability_zone_ids)
    location_name          = var.location_name
    allowed_accounts       = jsonencode(var.allowed_accounts)
    account_groups         = jsonencode(var.account_groups)
    location_template_id   = var.location_template_id
  }
}
