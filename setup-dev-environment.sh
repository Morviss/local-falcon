#!/bin/bash

set -e

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Install kind
curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v0.17.0/kind-linux-amd64"
chmod +x kind
sudo mv kind /usr/local/bin/

# Install helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install istioctl
curl -L https://istio.io/downloadIstio | sh -
sudo mv istio-* /usr/local/bin/
export PATH=$PATH:/usr/local/bin/istio-*/

# Clean up
rm -rf istio-*

echo "All tools installed successfully!"
