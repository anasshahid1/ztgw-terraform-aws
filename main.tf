# ---------------------------------------------------------------------------
# ZTGW output is created by zsec before Terraform runs
# ---------------------------------------------------------------------------

data "local_file" "ztgw_output" {
  count    = var.deploy_ztgw ? 1 : 0
  filename = "${path.module}/.ztgw-output.json"
}

locals {
  ztgw_result           = var.deploy_ztgw ? jsondecode(data.local_file.ztgw_output[0].content) : null
  endpoint_service_name = try(local.ztgw_result.endpoint_service_name, var.endpoint_service_name)
}

# ---------------------------------------------------------------------------
# Consumer side: VPC Gateway Load Balancer Endpoint
# ---------------------------------------------------------------------------

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
