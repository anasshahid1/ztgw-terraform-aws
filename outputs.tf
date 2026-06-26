output "gateway_id" {
  description = "ID of the AWS ZTGW."
  value       = var.deploy_ztgw ? data.external.ztgw[0].result["gateway_id"] : null
}

output "gateway_name" {
  description = "Name of the AWS ZTGW."
  value       = var.deploy_ztgw ? data.external.ztgw[0].result["gateway_name"] : null
}

output "gateway_region" {
  description = "AWS region where the ZTGW is deployed."
  value       = var.deploy_ztgw ? data.external.ztgw[0].result["region"] : null
}

output "gateway_health_status" {
  description = "Health status of the AWS ZTGW."
  value       = var.deploy_ztgw ? data.external.ztgw[0].result["health_status"] : null
}

output "endpoint_service_name" {
  description = <<-EOT
    AWS VPC Endpoint Service Name for the ZTGW.
    Use this to create a Gateway Load Balancer Endpoint in your consumer VPC.
    EOT
  value       = var.deploy_ztgw ? data.external.ztgw[0].result["endpoint_service_name"] : null
}

output "endpoints_count" {
  description = "Number of connected VPC endpoints."
  value       = var.deploy_ztgw ? data.external.ztgw[0].result["endpoints_count"] : null
}
