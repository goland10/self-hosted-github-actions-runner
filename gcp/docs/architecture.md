## Architecture Overview

Below is a high-level overview of how the GitHub Actions Runner interacts with GCP and GitHub:
```
                 ┌─────────────────────┐
                 │     GitHub Repo     │
                 │ goland10/multi-    │
                 │ cloud-k8s          │
                 └─────────┬──────────┘
                           │
                           │ 
                           ▼
                 ┌─────────────────────┐
                 │  GCP Secret Manager │
                 │                    │
                 │                    │          
                 └─────────┬──────────┘
                           │ PAT (from Secret Manager)
                           ▼
                 ┌─────────────────────┐
                 │   Runner VM (GCE)  │
                 │ - Ubuntu 24.04 LTS │
                 │ - gcloud & kubectl │
                 │ - Helm             │
                 │ - GitHub Actions   │
                 │   Runner           │
                 └─────────┬──────────┘
                           │
           ┌───────────────┴───────────────┐
           │                               │
           ▼                               ▼
 ┌─────────────────────┐         ┌─────────────────────┐
 │ Private GKE Cluster │         │ Internet Access via │
 │ (no public IP)      │         │ Cloud NAT           │
 └─────────────────────┘         └─────────────────────┘

```
**Flow explanation:**  
1. The user generates GitHub Personal Access Token (PAT) **manually** and store it in **GCP Secret Manager**.
1. The runner VM fetches the **GitHub PAT** from **GCP Secret Manager**.  
2. It registers itself to the selected repository (`goland10/multi-cloud-k8s`) using that token.  
3. The runner executes workflows on **private GKE clusters**.  
4. Runner outbound connections (e.g., to fetch packages or updates) go through **Cloud NAT**.  
5. SSH access to the runner VM is allowed **only through IAP**.  