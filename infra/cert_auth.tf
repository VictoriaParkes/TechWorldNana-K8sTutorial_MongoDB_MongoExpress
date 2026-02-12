# Private Certificate Authority (CA) and uses it to generate TLS certificates for Kubernetes components



###############################
# Certificate Authority Setup #
###############################

# Generate a 2048-bit RSA private key for the CA
resource "tls_private_key" "ca_private_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create a self-signed root certificate
resource "tls_self_signed_cert" "ca_cert" {
  private_key_pem = tls_private_key.ca_private_key.private_key_pem

  subject {
    common_name  = "kubernetes"
    organization = "CA"
  }

  validity_period_hours = 43800 # ~5 years in hours
  is_ca_certificate     = true  # Marks it as a CA that can sign other certificates

  allowed_uses = [
    "cert_signing", # enabling it to sign other certificates
    "key_encipherment",
    "server_auth",
    "client_auth",
    "digital_signature",
  ]
}

# Save to local files

resource "local_file" "ca_key" {
  content         = tls_private_key.ca_private_key.private_key_pem
  filename        = "${path.module}/certs/ca-key.pem"
  file_permission = "0600"
}

resource "local_file" "ca_cert" {
  content         = tls_self_signed_cert.ca_cert.cert_pem
  filename        = "${path.module}/certs/ca.pem"
  file_permission = "0644"
}


################################
# Admin Certificate Generation #
################################

# client and server certificates for each Kubernetes component and a client certificate for the Kubernetes admin user

# Generate a separate private key for the Kubernetes admin user
resource "tls_private_key" "admin" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create a Certificate Signing Request (CSR)
resource "tls_cert_request" "admin" {
  private_key_pem = tls_private_key.admin.private_key_pem

  subject {
    common_name  = "admin"
    organization = "system:masters" # Kubernetes built-in superuser group
  }
}

# Sign admin CSR using the CA created above, producing a valid certificate chain
resource "tls_locally_signed_cert" "admin" {
  cert_request_pem   = tls_cert_request.admin.cert_request_pem
  ca_private_key_pem = tls_private_key.ca_private_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca_cert.cert_pem

  validity_period_hours = 43800

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth"
  ]
}

resource "local_file" "admin_key" {
  content         = tls_private_key.admin.private_key_pem
  filename        = "${path.module}/certs/admin-key.pem"
  file_permission = "0600"
}

resource "local_file" "admin_cert" {
  content         = tls_locally_signed_cert.admin.cert_pem
  filename        = "${path.module}/certs/admin.pem"
  file_permission = "0644"
}


###############################
# kubelet client certificates #
###############################
# one unique certificate per worker node for authenticating to the Kubernetes API server

# Create a separate 2048-bit RSA private key for each worker node
resource "tls_private_key" "nodes" {
  for_each = {
    for idx, instance in aws_instance.K8s_workers :
    idx => instance
  }

  algorithm = "RSA"
  rsa_bits  = 2048
}

# Creates a Certificate Signing Request (CSR) for each worker node
resource "tls_cert_request" "nodes" {
  for_each = tls_private_key.nodes

  private_key_pem = each.value.private_key_pem

  subject {
    common_name  = "system:node:worker-${each.key}"
    organization = "system:nodes" # Kubernetes RBAC group that grants node permissions
  }
}

resource "tls_locally_signed_cert" "nodes" {
  for_each = tls_cert_request.nodes

  cert_request_pem   = each.value.cert_request_pem
  ca_private_key_pem = tls_private_key.ca_private_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca_cert.cert_pem

  validity_period_hours = 43800

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth"
  ]
}

resource "local_file" "node_keys" {
  for_each = {
    for k, v in tls_private_key.nodes :
    k => v
  }
  content         = tls_private_key.nodes[each.key].private_key_pem
  filename        = "${path.module}/certs/worker-${each.key}-key.pem"
  file_permission = "0600"
}

resource "local_file" "node_certs" {
  for_each = tls_locally_signed_cert.nodes

  content         = each.value.cert_pem
  filename        = "${path.module}/certs/worker-${each.key}.pem"
  file_permission = "0644"
}

/* These CSRs will be signed by your CA to create certificates that allow each kubelet
(running on worker nodes) to authenticate to the Kubernetes API server with proper node permissions.
*/


#########################################
# Controller Manager Client Certificate #
#########################################

resource "tls_private_key" "kube_controller_manager" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "kube_controller_manager" {
  private_key_pem = tls_private_key.kube_controller_manager.private_key_pem

  subject {
    common_name  = "system:kube-controller-manager"
    organization = "system:kube-controller-manager"
  }
}

resource "tls_locally_signed_cert" "kube_controller_manager" {
  cert_request_pem   = tls_cert_request.kube_controller_manager.cert_request_pem
  ca_private_key_pem = tls_private_key.ca_private_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca_cert.cert_pem

  validity_period_hours = 43800

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth"
  ]
}

resource "local_file" "kube_controller_manager_key" {
  content         = tls_private_key.kube_controller_manager.private_key_pem
  filename        = "${path.module}/certs/kube-controller-manager-key.pem"
  file_permission = "0600"
}

resource "local_file" "kube_controller_manager_cert" {
  content         = tls_locally_signed_cert.kube_controller_manager.cert_pem
  filename        = "${path.module}/certs/kube-controller-manager.pem"
  file_permission = "0644"
}


#####################################
# The Kube Proxy Client Certificate #
#####################################

resource "tls_private_key" "kube_proxy" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "kube_proxy" {
  private_key_pem = tls_private_key.kube_proxy.private_key_pem

  subject {
    common_name  = "system:kube-proxy"
    organization = "system:node-proxier"
  }
}

resource "tls_locally_signed_cert" "kube_proxy" {
  cert_request_pem   = tls_cert_request.kube_proxy.cert_request_pem
  ca_private_key_pem = tls_private_key.ca_private_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca_cert.cert_pem

  validity_period_hours = 43800

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth"
  ]
}

resource "local_file" "kube_proxy_key" {
  content         = tls_private_key.kube_proxy.private_key_pem
  filename        = "${path.module}/certs/kube-proxy-key.pem"
  file_permission = "0600"
}

resource "local_file" "kube_proxy_cert" {
  content         = tls_locally_signed_cert.kube_proxy.cert_pem
  filename        = "${path.module}/certs/kube-proxy.pem"
  file_permission = "0644"
}


####################################
# The Scheduler Client Certificate #
####################################

resource "tls_private_key" "kube_scheduler" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "kube_scheduler" {
  private_key_pem = tls_private_key.kube_scheduler.private_key_pem

  subject {
    common_name  = "system:kube-scheduler"
    organization = "system:kube-scheduler"
  }
}

resource "tls_locally_signed_cert" "kube_scheduler" {
  cert_request_pem   = tls_cert_request.kube_scheduler.cert_request_pem
  ca_private_key_pem = tls_private_key.ca_private_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca_cert.cert_pem

  validity_period_hours = 43800

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth"
  ]
}

resource "local_file" "kube_scheduler_key" {
  content         = tls_private_key.kube_scheduler.private_key_pem
  filename        = "${path.module}/certs/kube-scheduler-key.pem"
  file_permission = "0600"
}

resource "local_file" "kube_scheduler_cert" {
  content         = tls_locally_signed_cert.kube_scheduler.cert_pem
  filename        = "${path.module}/certs/kube-scheduler.pem"
  file_permission = "0644"
}


#########################################
# The Kubernetes API Server Certificate #
#########################################

resource "tls_private_key" "kubernetes_api" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "kubernetes_api" {
  private_key_pem = tls_private_key.kubernetes_api.private_key_pem

  subject {
    common_name  = "kubernetes"
    organization = "Kubernetes"
  }

  dns_names = [
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster.local",
  ]

  ip_addresses = [
    "10.96.0.1",                                # Service cluster IP range
    "127.0.0.1",                                # localhost
    aws_instance.K8s_controllers[0].private_ip, # Master node's private IP
  ]
}

resource "tls_locally_signed_cert" "kubernetes_api" {
  cert_request_pem   = tls_cert_request.kubernetes_api.cert_request_pem
  ca_private_key_pem = tls_private_key.ca_private_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca_cert.cert_pem

  validity_period_hours = 43800

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth"
  ]
}

resource "local_file" "kubernetes_api_key" {
  content         = tls_private_key.kubernetes_api.private_key_pem
  filename        = "${path.module}/certs/kubernetes-key.pem"
  file_permission = "0600"
}

resource "local_file" "kubernetes_api_cert" {
  content         = tls_locally_signed_cert.kubernetes_api.cert_pem
  filename        = "${path.module}/certs/kubernetes.pem"
  file_permission = "0644"
}




################################
# The Service Account Key Pair #
################################

resource "tls_private_key" "service_account" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "service_account" {
  private_key_pem = tls_private_key.service_account.private_key_pem

  subject {
    common_name  = "service_account"
    organization = "kubernetes"
  }
}

resource "tls_locally_signed_cert" "service_account" {
  cert_request_pem   = tls_cert_request.service_account.cert_request_pem
  ca_private_key_pem = tls_private_key.ca_private_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca_cert.cert_pem

  validity_period_hours = 43800

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth"
  ]
}

resource "local_file" "service_account_key" {
  content         = tls_private_key.service_account.private_key_pem
  filename        = "${path.module}/certs/service-account-key.pem"
  file_permission = "0600"
}

resource "local_file" "service_account_cert" {
  content         = tls_locally_signed_cert.service_account.cert_pem
  filename        = "${path.module}/certs/service-account.pem"
  file_permission = "0644"
}



#################################################
# Distribute the Client and Server Certificates #
#################################################

# Copy the appropriate certificates and private keys to each worker instance




# Copy the appropriate certificates and private keys to each controller instance
