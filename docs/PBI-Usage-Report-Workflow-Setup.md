# Power BI Usage Report — GitHub Actions Setup

## Required Repository Secrets

Create these under **Settings → Secrets and variables → Actions → Secrets**:

| Secret Name | Description |
|---|---|
| `PBI_TENANT_ID` | Azure AD / Entra ID Tenant ID (GUID) |
| `PBI_CLIENT_ID` | App Registration Client ID (must have "Allow public client flows" enabled) |
| `PBI_SVC_USERNAME` | UPN of the service account (e.g., `svc-powerbi@yourdomain.com`). Must hold the **Power BI Administrator** Entra role and must NOT require MFA. |
| `PBI_SVC_PASSWORD` | Password for the service account |
| `AWS_ACCESS_KEY_ID` | AWS IAM access key with `s3:PutObject` permission on the target bucket |
| `AWS_SECRET_ACCESS_KEY` | Corresponding AWS secret access key |

## Required Repository Variables

Create these under **Settings → Secrets and variables → Actions → Variables**:

| Variable Name | Description | Example |
|---|---|---|
| `S3_BUCKET_NAME` | Target S3 bucket name | `my-pbi-reports` |
| `S3_KEY_PREFIX` | Folder prefix inside the bucket (optional, can be empty) | `pbi-reports/monthly` |
| `S3_REGION` | AWS region of the S3 bucket | `us-west-2` |

## Prerequisites

### Azure / Entra ID
1. **App Registration** — Create (or reuse) an app registration with "Allow public client flows" enabled (required for ROPC grant).
2. **Service Account** — A user account with:
   - **Power BI Administrator** role assigned in Entra ID
   - MFA disabled (or excluded via Conditional Access for this account)
   - No Conditional Access policies blocking ROPC token requests
3. **Fabric Admin Portal** — Enable "Service principals can access read-only admin APIs" under Admin Portal → Tenant settings (even though ROPC is user-delegated, the admin APIs require this tenant toggle).

### AWS
1. **IAM User or Role** — Create an IAM user with programmatic access.
2. **Policy** — Attach a policy granting at minimum:
   ```json
   {
     "Effect": "Allow",
     "Action": ["s3:PutObject"],
     "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME/*"
   }
   ```
3. Generate an access key pair and store in the repository secrets above.

## Workflow Triggers

| Trigger | Details |
|---|---|
| **Scheduled** | Runs monthly on the 1st at 06:00 UTC |
| **Manual** | Use "Run workflow" in the Actions tab. Optionally override activity days, output format, and refresh history. |

## Output

- Reports are uploaded to S3 at the configured bucket/prefix.
- A GitHub Actions artifact (`pbi-usage-reports`) is retained for 30 days as a backup.
