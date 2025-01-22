infra
=====

This repository contains the infrastructure-as-code and cluster configurations for the **fullstack.pw** homelab environment. The environment runs multiple Kubernetes clusters (sandbox, dev, stg, prod, runners) and supporting services like DNS, ingress controllers, certificate management, etc.

Overview
--------

The main goals of this repository are:

-   **Centralized Configuration**: Keep all infrastructure code in one place for consistent management and version control.
-   **Homelab Kubernetes**: Manage multiple K3s and vanilla Kubernetes clusters on Proxmox VMs.
-   **CI/CD Integration**: Provide GitHub and GitLab pipelines (via self-hosted runners) to automate builds and deployments.
-   **Support Services**: Set up DNS, ingress, certificates, vault-based secret management, and more.

High-Level Architecture
-----------------------

1.  **Cloudflare**

    -   Manages DNS for `fullstack.pw` and provides a CDN and WAF.
    -   `cert-manager` in each cluster handles ACME certificate issuance via DNS challenges to Cloudflare.
2.  **Homelab / Proxmox**

    -   Two physical nodes:
        -   **NODE01 (Acer Nitro, i7-4710HQ, 16GB)**
        -   **NODE02 (HP ED800 G3 Mini, i7-7700T, 32GB)**
    -   Proxmox hosts multiple VMs:
        -   **Internal DNS** (authoritative for `fullstack.pw` inside homelab)
        -   **HAProxy** VM at `k8s.fullstack.pw` (load balancer for the Kubernetes clusters)
        -   **K8s Clusters**:
            -   **Sandbox** (vanilla K8s) on VMs `k01`, `k02`, `k03`
            -   **Dev** (K3s) on VM `k8s-dev`
            -   **Stg** (K3s) on VM `k8s-stg`
            -   **Prod** (K3s) on VM `k8s-prod`
3.  **Lenovo Legion (Personal Laptop)**

    -   **Rancher Desktop** installed, running a **runners** cluster (K3s) for pipelines.
    -   Not running Proxmox, but considered part of the homelab environment because it can spin up ephemeral runners to execute CI jobs.
4.  **Kubernetes (K3s / Vanilla) Clusters**

    -   Common add-ons across clusters:
        -   **cert-manager**, **external-dns**, **external-secrets**, **nginx-ingress**, **metalLB**, **local-path-provisioner**.
    -   Storage and services: **MinIO** (`s3.fullstack.pw`), **private registry** (`registry.fullstack.pw`), **Vault** (`vault.fullstack.pw`).
    -   Example application: **API User Management** (`dev.api-usermgmt.fullstack.pw`, `stg.api-usermgmt.fullstack.pw`, `api-usermgmt.fullstack.pw`).
5.  **CI/CD Integrations**

    -   **GitHub**: `actions-runner-controller` runs on the Rancher Desktop cluster to register self-hosted GitHub Actions runners.
    -   **GitLab**: A separate `gitlab-runner` is deployed on K3s to run GitLab CI jobs.


Diagram
-------

Below is the current homelab architecture diagram:

![image](fullstack.drawio.svg)