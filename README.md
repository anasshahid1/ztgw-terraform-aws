# Zscaler AWS ZTGW — Terraform Deployment

Provision an **AWS Zero Trust Gateway** (ZTGW) via the Zscaler REST API and optionally create a **VPC Gateway Load Balancer Endpoint** in your existing VPC — all from a single Terraform workflow.

---

## Architecture

```
Zscaler OneAPI
     │
     ▼
  AWS ZTGW ───► VPC Endpoint Service Name (com.amazonaws.vpce....)
                         │
                    ┌────┴────┐
                    │         │
               aws_vpc_endpoint (GatewayLoadBalancer)
                    │         │
                    ▼         ▼
              Subnet-1     Subnet-2
                    │         │
                    ▼         ▼
            aws_route_table (auto-discovered per subnet)
                    │         │
                    ▼         ▼
               aws_route (0.0.0.0/0 → vpce-xxx)
```

---

## Features

- **3 deployment modes**: Full, ZTGW-only, Endpoint-only
- **AZ auto-discovery**: Uses AWS CLI to discover availability zone IDs per region
- **Force activation**: Triggers Zscaler activation after deploy and destroy
- **Brownfield consumer**: Bring your own VPC, subnets, and route CIDR — route tables are auto-discovered
- **Interactive wrapper** (`./zsec up`): Guided prompts with config caching
- **No docs needed**: API schema was reverse-engineered from the live Zscaler API

---

## Prerequisites

| Tool | Purpose |
|------|---------|
| Python 3 | JSON parsing in shell scripts |
| AWS CLI | AZ discovery, credentials for VPC Endpoint |
| Terraform >= 1.0 | Infrastructure orchestration |
| Zscaler OneAPI OAuth2 credentials | Client ID, Client Secret, Vanity Domain |

---

## Quick Start

```bash
git clone https://github.com/anasshahid1/ztgw-terraform-aws
cd ztgw-terraform-aws
./zsec up
```

Follow the interactive prompts. On first run, `./zsec up` will:

1. Ask your deployment mode (Full / ZTGW-only / Endpoint-only)
2. Prompt for Zscaler OneAPI credentials
3. Prompt for AWS region, ZTGW name, and ZTGW configuration
4. Auto-discover AZs via AWS CLI
5. Prompt for consumer VPC details (if deploying endpoint)
6. Show a summary and ask for confirmation
7. Run `terraform init && terraform apply`

Configuration is cached in `.zsecrc`. Re-run `./zsec up` to apply with the same config.

---

## Deployment Modes

| Mode | `deploy_ztgw` | `deploy_endpoint` | What happens |
|------|:---:|:---:|---|
| **Full** | `true` | `true` | Create ZTGW → get endpoint service name → create VPC Endpoint + routes |
| **ZTGW-only** | `true` | `false` | Create ZTGW, output `endpoint_service_name` |
| **Endpoint-only** | `false` | `true` | Create VPC Endpoint from an existing `endpoint_service_name` |

---

## Variables

### Authentication

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `client_id` | `string` | — | Zscaler OneAPI OAuth2 client ID |
| `client_secret` | `string` (sensitive) | — | Zscaler OneAPI OAuth2 client secret |
| `vanity_domain` | `string` | — | Zscaler vanity domain (e.g. `acme` → `acme.zslogin.net`) |
| `cloud` | `string` | `zscalerbeta` | Zscaler cloud: `zscaler`, `zscalerone`, `zscalertwo`, `zscalerthree`, `zscalerbeta` |

### ZTGW

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `gateway_name` | `string` | `aws-ztgw` | ZTGW name |
| `aws_region` | `string` | `us-west-2` | AWS region |
| `aws_region_code` | `string` | `US_WEST_2` | AWS region in Zscaler format (uppercase underscored) |
| `availability_zone_ids` | `list(string)` | `[]` | AZ IDs (auto-discovered via AWS CLI if empty) |
| `location_name` | `string` | `aws-ztgw-location` | Zscaler location name |
| `allowed_accounts` | `list(number)` | `[]` | Zscaler account IDs for endpoint service (optional) |
| `account_groups` | `list(number)` | `[]` | Zscaler account group IDs (optional) |
| `location_template_id` | `number` | `164780` | Location template ID |

### Consumer VPC Endpoint

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `deploy_endpoint` | `bool` | `true` | Deploy consumer VPC Endpoint |
| `endpoint_service_name` | `string` | `""` | Existing endpoint service (required in Endpoint-only mode) |
| `consumer_vpc_id` | `string` | `""` | Existing VPC ID |
| `consumer_subnet_ids` | `list(string)` | `[]` | Existing subnet IDs (one per AZ) |
| `consumer_route_cidr` | `string` | `0.0.0.0/0` | Destination CIDR for VPC Endpoint route |
| `consumer_deploy_key` | `string` | `aws-ztgw` | Naming prefix for resources |
| `aws_endpoint_region` | `string` | `us-west-2` | AWS region for the AWS provider |

---

## Outputs

| Output | Description |
|--------|-------------|
| `gateway_id` | ZTGW ID in Zscaler |
| `gateway_name` | ZTGW name |
| `gateway_region` | AWS region |
| `gateway_health_status` | Health status (HEALTHY, INIT, etc.) |
| `endpoint_service_name` | **VPC Endpoint Service name** — use this to create GWLB Endpoints |
| `endpoints_count` | Number of connected VPC Endpoints |
| `vpc_endpoint_id` | ID of the created VPC Endpoint |
| `vpc_endpoint_service_name` | Service name used by the endpoint |
| `vpc_endpoint_state` | State (Available, Pending, etc.) |
| `vpc_endpoint_route_table_ids` | Route tables with endpoint routes |

---

## Destroy

```bash
./zsec destroy
```

The destroy flow:

1. **Delete ZTGW** via Zscaler REST API → sleep 10s → force activation
2. **Terraform destroy** — removes VPC Endpoint, routes, and state
3. **Cleanup** — removes `.terraform/`, state files, `bin/`, archives `.zsecrc`

---

## Troubleshooting

### Force Activation returns `NON_SUPER_ADMIN_FORCED_ACTIVATE_NOT_ALLOWED`

This is expected on `zscalerbeta` and non-super-admin accounts. The activation call is made but requires super admin privileges on production Zscaler clouds. The ZTGW itself is still fully functional.

### ZTGW stuck in `INIT` state

ZTGW provisioning typically takes 3–5 minutes. The script polls for up to 10 minutes. If it times out, the ZTGW may still be provisioning — run `./zsec up` again to pick up the existing gateway.

### AWS CLI not available

Without AWS CLI, AZ auto-discovery falls back to the `availability_zone_ids` variable. Set it explicitly:

```hcl
availability_zone_ids = ["usw2-az1", "usw2-az2"]
```

---

## Files

```
├── main.tf                 # Terraform resources
├── variables.tf            # All variables
├── outputs.tf              # All outputs
├── provider.tf             # AWS provider
├── versions.tf             # Version constraints
├── zsec                    # Interactive wrapper
├── LICENSE                 # MIT
└── scripts/
    ├── deploy_ztgw.sh      # ZTGW creation + polling + activation
    └── destroy_ztgw.sh     # ZTGW deletion + activation

```
