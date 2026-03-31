#!/bin/bash
set -xe
#exec > /var/log/startup-script.log 2>&1
apt-get update && apt-get install -y ca-certificates curl gnupg lsb-release jq
# Install Google Cloud SDK and GKE auth plugin
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg --yes
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee /etc/apt/sources.list.d/google-cloud-sdk.list
    
# Install Helm
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg # > /dev/null
#curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/helm.gpg --yes
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

apt-get update && apt-get install -y google-cloud-cli  google-cloud-sdk-gke-gcloud-auth-plugin  kubectl helm unzip nodejs npm

# Install Runner
RUNNER_USER=github
RUNNER_HOME=/home/$RUNNER_USER
RUNNER_DIR=$RUNNER_HOME/actions-runner
REPO_URL=${repo_url}    #"https://github.com/goland10/multi-cloud-k8s"
GH_API=${gh_api}        #"https://api.github.com/repos/goland10/multi-cloud-k8s/actions/runners/registration-token"
# Create runner user if needed
id $RUNNER_USER &>/dev/null || useradd -m $RUNNER_USER
# Download the latest runner package and Extract the installer
mkdir -p $RUNNER_DIR
cd $RUNNER_DIR

if [ ! -f "$RUNNER_DIR/config.sh" ]; then
  curl -o actions-runner-linux-x64.tar.gz -L https://github.com/actions/runner/releases/download/v2.331.0/actions-runner-linux-x64-2.331.0.tar.gz
  tar xzf ./actions-runner-linux-x64.tar.gz
  chown -R $RUNNER_USER:$RUNNER_USER $RUNNER_HOME
fi
# Register runner only once
if [ ! -f "$RUNNER_DIR/.runner" ]; then
  GH_PAT=$(gcloud secrets versions access latest --secret=${secret_name})
  RUNNER_TOKEN=$(curl -s -X POST \
    -H "Authorization: Bearer $GH_PAT" \
    -H "Accept: application/vnd.github+json" \
    $GH_API | jq -r .token)
  # Configure and start the runner
  sudo -u $RUNNER_USER bash -c "
  ./config.sh \
    --url $REPO_URL \
    --token $RUNNER_TOKEN \
    --unattended \
    --replace
  "
  ./svc.sh install $RUNNER_USER
fi

./svc.sh start
