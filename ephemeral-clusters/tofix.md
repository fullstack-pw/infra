I'm reviewing the infra/.github/workflows/ephemeral-cluster.yml that you created:

* 'Create Cloudflare API token secret' this probably will leak secret and it's very poor safety, we have all secrets available as env vars on all runners, also we dont need cloudflare to ephemeral
* workflow is broken, syntax issues whithin posting comments to PR
* cloudnativepg operator and database can be optional, ie wont be used on/by cks-* apps
* I removed all VAULT_TOKEN exports as we have this env already available on runners
* I moved VAULT_ADDRESS to workflow envs to avoid repetition
* 'Copy proxmox-credentials secret' is not needed at all, we dont need proxmox secret on workload clusters (dev, prod, ephemeral), we only need proxmox secret where we interact with proxmox that is tools cluster
* 'Wait for DNS propagation' won't work because the ephemeral cluster itself doesn't have named endpoint, and it's pointless because we already know at this point that the cluster is fine, this check is after 2nd phase so it should check resources created on step before

Also I followed your instructions on APPLICATION_REPO_INTEGRATION.md and I created the ephemeral.yml workflow to test on cks-backend, I'm reviewing this workflow:

* step 'Wait for cluster ready' won't work because cluster does not have named endpoint to reach it, better to check cluster readiness like on this step .github/workflows/ephemeral-cluster.yml L58

