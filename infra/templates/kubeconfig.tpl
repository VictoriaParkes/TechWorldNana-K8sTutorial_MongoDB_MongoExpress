apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: ${ca_data}
    server: ${server}
  name: ${cluster_name}
contexts:
- context:
    cluster: ${cluster_name}
    user: ${user_name}
  name: default
current-context: default
users:
- name: ${user_name}
  user:
    client-certificate-data: ${client_cert}
    client-key-data: ${client_key}

# This kubeconfig file tells kubectl (or Kubernetes components) how to connect
# and authenticate to a Kubernetes cluster. It has three main sections:

# clusters - Defines WHERE to connect (the Kubernetes API server):
#   - `server`: API server address (e.g. https://load-balancer:443)
#   - `certificate-authority-data`: CA cert to verify the API server's identity
#   - `name`: Cluster identifier

# users - Defines WHO youo are (authentication):
#   - `client-certificate-data`: Your identity certificate
#   - `client-key-data`: Your private key to prove you own that certificate

# contexts - Links a cluster + user together:
#   - `cluster`: Which cluster to use
#   - `user`: Which credentials to use / Your authentication credentials
#   - `current-context`: Which context is active (default here)

# When kubectl runs a command:
#   1. Reads `current-context` → uses "default"
#   2. "default" context says: use cluster "kubernetes-the-hard-way" with user "admin"
#   3. Connects to server address
#   4. Verifies API server cert using `certificate-authority-data`
#   5. Authenticates using `client-certificate-data` + `client-key-data`

# The structure is:
# each list item (-) has a name at the same indentation level, with details nested underneath.