# Design Document

## Overview

This project automates the deployment of Zscaler AWS Zero Trust Gateways (ZTGW) and their consumer-side VPC Gateway Load Balancer Endpoints using Terraform. Since no official Terraform provider exists for ZTGW resources, the Zscaler REST API is invoked via Terraform's `external` data source.

---

## API Discovery

No public documentation exists for the Zscaler AWS ZTGW API. The request schema was reverse-engineered by probing the live `zscalerbeta` Zscaler API:

1. **List existing gateways** — `GET /ztGateway?platform=AWS` revealed the full JSON structure of an existing AWS ZTGW, including all required and optional fields.
2. **Probe create schema** — `POST /ztGateway` with a minimal payload (`name` + `platform`) returned validation errors that revealed the next required field. This was repeated iteratively with 2s delays to respect the 1 req/s rate limit.
3. **Confirm optional fields** — Testing with and without `allowedAccounts`/`accountGroups` confirmed they are optional.

### Payload structure discovered

```json
{
  "name": "string",
  "platform": "AWS",
  "region": "us-west-2",
  "awsRegion": "US_WEST_2",
  "availabilityZoneIds": ["usw2-az1", "usw2-az2"],
  "provData": {
    "locationName": "string",
    "locationTemplate": {"id": 164780},
    "allowedAccounts": [{"id": 12345678}],
    "accountGroups": [{"id": 87654321}]
  }
}
```

### Account and group entities

`allowedAccounts` and `accountGroups` reference Zscaler-internal entities configured in the Zscaler Admin Portal. No public API endpoint was found to list or resolve them. They are both optional — if omitted, the ZTGW is created with empty arrays and can be configured later via the admin portal.

---

## Key Differences from GCP ZTGW

| Aspect | GCP | AWS |
|--------|-----|-----|
| Region field | `region` | `region` + `awsRegion` (uppercase underscored) |
| AZ format | `us-central1-a` | `usw2-az1` (AWS AZ ID format) |
| IAM integration | `provData.iamPrincipals` | `provData.allowedAccounts` + `provData.accountGroups` |
| Consumer output | `interceptDeploymentGroup` | `endpointServiceName` |
| Consumer resource | GCP NSI Intercept Endpoint Group | AWS VPC Endpoint (GatewayLoadBalancer) |
| AZ discovery | Not needed (GCP AZs are predictable) | Auto-discovered via AWS CLI |

---

## Availability Zone Auto-Discovery

AWS AZ IDs (`usw2-az1`, `use1-az2`, etc.) vary per AWS account and cannot be derived from the region name alone. The `deploy_ztgw.sh` script:

1. Checks if `availability_zone_ids` is empty (`[]`)
2. If empty, runs `aws ec2 describe-availability-zones --region $region --query "AvailabilityZones[*].ZoneId" --output json`
3. If AWS CLI is not available, exits with an error instructing the user to set the variable manually

---

## Force Activation

After every ZTGW create and destroy, the script calls the OneAPI activation endpoint:

```
PUT https://api.{cloud}.zsapi.net/ztw/api/v1/ecAdminActivateStatus/forcedActivate
```

On `zscalerbeta` and non-super-admin accounts, this returns `NON_SUPER_ADMIN_FORCED_ACTIVATE_NOT_ALLOWED`. This is expected. The call is best-effort — failures are logged as warnings and do not block the deploy/destroy flow.

---

## Consumer-Side Design

The consumer VPC Endpoint follows a brownfield pattern:

- **User provides**: VPC ID, subnet IDs (one per AZ), route CIDR
- **Auto-discovered**: Route tables — a `data.aws_route_table` lookup is performed for each subnet to find its attached route table
- **Route created**: One `aws_route` per route table, pointing `consumer_route_cidr → vpc_endpoint_id`

This avoids requiring users to know their route table IDs while still being explicit about which subnets are used.

---

## Interactive Wrapper (`zsec`)

The `zsec` script mirrors the same structure as the GCP `ztgw-terraform-gcp` project:

1. Downloads Terraform binary for the detected OS/arch
2. Provides a 3-mode interactive menu
3. Prompts for all required and optional parameters
4. Caches configuration in `.zsecrc`
5. On destroy, deletes the ZTGW via API first, then runs `terraform destroy`
6. Archives `.zsecrc` on destroy for recovery
7. Supports `AUTO_APPROVE` env var for CI/CD

---

## File Structure

```
├── main.tf                 # data.local_file.ztgw_output, aws_vpc_endpoint, aws_route
├── variables.tf            # 20 variables across 4 categories
├── outputs.tf              # 8 outputs (ZTGW + endpoint)
├── provider.tf             # AWS provider configuration
├── versions.tf             # Version constraints (Terraform >= 1.0, AWS >= 5.0, local >= 2.0)
├── zsec                    # Interactive deployment wrapper
├── LICENSE                 # MIT
└── scripts/
    ├── deploy_ztgw.sh      # ZTGW deployment with health polling
    └── destroy_ztgw.sh     # ZTGW deletion with force activation
```

---

## Terraform Provider

The `hashicorp/aws` provider is configured via `provider.tf` with the region set from `var.aws_endpoint_region`. No AWS credentials are hardcoded — the provider uses the standard AWS credential chain (environment variables, `~/.aws/credentials`, IAM role, etc.).

The Zscaler API is called by `zsec` (not Terraform). `zsec` invokes `deploy_ztgw.sh` before `terraform init`, writing the result to `.ztgw-output.json`. Terraform's `data.local_file.ztgw_output` reads this file, avoiding the premature ZTGW creation that `data.external` would trigger during `terraform plan`.
