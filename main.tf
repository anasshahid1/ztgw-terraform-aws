# ---------------------------------------------------------------------------
# Provider side: AWS Zero Trust Gateway (via Zscaler REST API)
# ---------------------------------------------------------------------------

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
    login_domain           = var.login_domain
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

# ---------------------------------------------------------------------------
# Consumer side: VPC Gateway Load Balancer Endpoint
# ---------------------------------------------------------------------------

locals {
  endpoint_service_name = try(data.external.ztgw[0].result["endpoint_service_name"], var.endpoint_service_name)
}

resource "aws_vpc_endpoint" "consumer" {
  count             = var.deploy_endpoint ? 1 : 0
  vpc_id            = var.consumer_vpc_id
  service_name      = local.endpoint_service_name
  vpc_endpoint_type = "GatewayLoadBalancer"
  subnet_ids        = var.consumer_subnet_ids

  tags = {
    Name = "${var.consumer_deploy_key}-gwlbe"
  }
}

data "aws_route_table" "subnet" {
  count     = var.deploy_endpoint ? length(var.consumer_subnet_ids) : 0
  subnet_id = var.consumer_subnet_ids[count.index]
}

resource "aws_route" "consumer" {
  count                  = var.deploy_endpoint ? length(var.consumer_subnet_ids) : 0
  route_table_id         = data.aws_route_table.subnet[count.index].id
  destination_cidr_block = var.consumer_route_cidr
  vpc_endpoint_id        = aws_vpc_endpoint.consumer[0].id

  depends_on = [aws_vpc_endpoint.consumer]
}
