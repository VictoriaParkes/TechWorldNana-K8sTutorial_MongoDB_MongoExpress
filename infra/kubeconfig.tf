########################################################
# Generate Kubernetes configuration files (kubeconfig) #
########################################################

locals {
  kubernetes_public_address = aws_lb.load_balancer.dns_name
}

# Admin kubeconfig
resource "local_file" "admin_kubeconfig" {
  filename        = "${path.module}/certs/admin.kubeconfig"
  file_permission = "0600"
  content = templatefile("${path.module}/templates/kubeconfig.tpl", {
    cluster_name   = "kubernetes-the-hard-way"
    server         = "https://${local.kubernetes_public_address}:443"
    ca_data        = base64encode(tls_self_signed_cert.ca_cert.cert_pem)
    client_cert    = base64encode(tls_locally_signed_cert.admin.cert_pem)
    client_key     = base64encode(tls_private_key.admin.private_key_pem)
    user_name      = "admin"
  })
}

# Kubelet kubeconfigs (one per worker)
resource "local_file" "kubelet_kubeconfig" {
  for_each        = toset([for i in range(length(var.private_subnet_cidrs)) : tostring(i)])
  filename        = "${path.module}/certs/worker-${each.key}.kubeconfig"
  file_permission = "0600"
  content = templatefile("${path.module}/templates/kubeconfig.tpl", {
    cluster_name   = "kubernetes-the-hard-way"
    server         = "https://${local.kubernetes_public_address}:443"
    ca_data        = base64encode(tls_self_signed_cert.ca_cert.cert_pem)
    client_cert    = base64encode(tls_locally_signed_cert.nodes[each.key].cert_pem)
    client_key     = base64encode(tls_private_key.nodes[each.key].private_key_pem)
    user_name      = "system:node:worker-${each.key}"
  })
}

# Kube-proxy kubeconfig
resource "local_file" "kube_proxy_kubeconfig" {
  filename        = "${path.module}/certs/kube-proxy.kubeconfig"
  file_permission = "0600"
  content = templatefile("${path.module}/templates/kubeconfig.tpl", {
    cluster_name   = "kubernetes-the-hard-way"
    server         = "https://${local.kubernetes_public_address}:443"
    ca_data        = base64encode(tls_self_signed_cert.ca_cert.cert_pem)
    client_cert    = base64encode(tls_locally_signed_cert.kube_proxy.cert_pem)
    client_key     = base64encode(tls_private_key.kube_proxy.private_key_pem)
    user_name      = "system:kube-proxy"
  })
}

# Controller Manager kubeconfig
resource "local_file" "controller_manager_kubeconfig" {
  filename        = "${path.module}/certs/kube-controller-manager.kubeconfig"
  file_permission = "0600"
  content = templatefile("${path.module}/templates/kubeconfig.tpl", {
    cluster_name   = "kubernetes-the-hard-way"
    server         = "https://127.0.0.1:6443"
    ca_data        = base64encode(tls_self_signed_cert.ca_cert.cert_pem)
    client_cert    = base64encode(tls_locally_signed_cert.kube_controller_manager.cert_pem)
    client_key     = base64encode(tls_private_key.kube_controller_manager.private_key_pem)
    user_name      = "system:kube-controller-manager"
  })
}

# Scheduler kubeconfig
resource "local_file" "scheduler_kubeconfig" {
  filename        = "${path.module}/certs/kube-scheduler.kubeconfig"
  file_permission = "0600"
  content = templatefile("${path.module}/templates/kubeconfig.tpl", {
    cluster_name   = "kubernetes-the-hard-way"
    server         = "https://127.0.0.1:6443"
    ca_data        = base64encode(tls_self_signed_cert.ca_cert.cert_pem)
    client_cert    = base64encode(tls_locally_signed_cert.kube_scheduler.cert_pem)
    client_key     = base64encode(tls_private_key.kube_scheduler.private_key_pem)
    user_name      = "system:kube-scheduler"
  })
}

/*
This code generates 5 kubeconfig files that tell different Kubernetes 
components how to authenticate to the API server.

Key Concept
locals block (lines 5-7):
 - Stores the load balancer DNS name for reuse
 - External components connect through this address

The 5 Kubeconfig Files
1. Admin (lines 10-21)
 - Who: Human administrators using kubectl
 - Server: Load balancer (external access)
 - Purpose: Full cluster admin access from your laptop

2. Kubelet (lines 24-35)
 - Who: Worker nodes (one config per worker)
 - Server: Load balancer
 - Purpose: Each worker authenticates to register itself and report status
 - Key line 25: for_each creates worker-0.kubeconfig, worker-1.kubeconfig, etc.

3. Kube-proxy (lines 38-48)
 - Who: Network proxy on each worker
 - Server: Load balancer
 - Purpose: Watches Services/Endpoints to configure network rules
 - Note: Same config shared across all workers

4. Controller Manager (lines 51-61)
 - Who: Control plane component managing cluster state
 - Server: 127.0.0.1:6443 (localhost)
 - Purpose: Manages ReplicaSets, nodes, service accounts
 - Why localhost: Runs on same node as API server

5. Scheduler (lines 64-75)
 - Who: Control plane component assigning pods to nodes
 - Server: 127.0.0.1:6443 (localhost)
 - Purpose: Decides which worker runs each pod
 - Why localhost: Runs on same node as API server

Key Differences
External access (admin, kubelet, kube-proxy):
 - Use load balancer DNS
 - Connect from outside the controller node

Internal access (controller-manager, scheduler):
 - Use 127.0.0.1:6443
 - Run on the same machine as the API server

base64encode: Kubernetes requires certificates embedded as base64 strings in kubeconfig files.
*/