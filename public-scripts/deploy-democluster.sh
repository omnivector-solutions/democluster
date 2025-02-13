#!/bin/bash

################################################################################
# Script: deploy-democluster.sh
# Author: Omnivctor Solutions <support@omnivector.solutions>
# Description:
#   This Bash script automates the creation of a cluster to be used for
#   demonstration purposes on Vantage. It configures the cluster based on the
#   host's operating system (Linux or macOS), installs necessary dependencies,
#   and sets up a customized environment for demonstrations.
#
# Usage:
#   1. Provide your CLIENT_ID and CLIENT_SECRET as command-line arguments:
#      ```
#      ./deploy-democluster.sh <CLIENT_ID> <CLIENT_SECRET> [<ENV>]
#      ```
#   2. The script will identify the host's operating system and install
#      necessary dependencies (Multipass, Homebrew, etc.) accordingly.
#   3. A cloud-init script is generated to customize the Multipass instance.
#   4. The Multipass instance is launched with the specified configuration.
#
# Prerequisites:
#   - Bash shell
#   - Internet connectivity for downloading dependencies (Multipass, Homebrew)
#   - CLIENT_ID and CLIENT_SECRET obtained from Vantage
#
# Configuration:
#   - Modify the script's constants (e.g., NUM_CPUS, MEMORY, IMAGE_URL) to
#     match your desired configuration.
#
# Notes:
#   - This script has been tested on both Ubuntu 22.04.
#   - Ensure you have appropriate permissions to execute system-level commands.
#   - Logging is recommended for monitoring the script's progress.
#   - The `ENV` parameter is optional and defaults to the production environment.
#
################################################################################

CLIENT_ID=$1
CLIENT_SECRET=$2
ENV=$3
CLOUD_IMAGE_URL=https://vantage-public-assets.s3.us-west-2.amazonaws.com/cloud-images/democluster/latest/democluster.img
CLOUD_IMAGE_DEST=/tmp/democluster.img

perform_variable_checks () {
  # Check if CLIENT_ID and CLIENT_SECRET are provided.
  if [ -z $CLIENT_ID ] || [ -z $CLIENT_SECRET ]; then
    echo "Please provide your CLIENT_ID and CLIENT_SECRET as command-line arguments."
    exit 1
  fi

  # Check if ENV is set to a valid value
  if [ -n "$ENV" ]; then
    if [[ "$ENV" != "staging" && "$ENV" != "qa" && "$ENV" != "dev" ]]; then
      echo "Invalid ENV value. It must be one of 'staging', 'qa' or 'dev'."
      exit 1
    fi
  fi
}

download_cloud_image () {
  # Download the demo cluster cloud image and outputs to $1.
  if [ -a $1 ]
  then
    echo "The demo cluster cloud image already exists. Proceeding..."
  else
    echo "Downloading the demo cluster cloud image, hang tight..."
    curl -s --output $1 $CLOUD_IMAGE_URL
    echo "Download finished. Proceeding..."
  fi
}

launch_instance () {
  # Check whether to install from remote URL or local file. If $1, then installs from file.
  if [ -z $1 ]; then
    IMAGE_ORIGIN=$CLOUD_IMAGE_URL
  else
    IMAGE_ORIGIN=file://$1
  fi

  # Set the environment to the empty string if not supplied
  if [ -z $ENV ]; then
      BASE_API_URL="https://apis.vantagecompute.ai"
      OIDC_DOMAIN="auth.vantagecompute.ai/realms/vantage"
      SNAP_CHANNEL="stable"
  else
      BASE_API_URL="https://apis.${ENV}.vantagecompute.ai"
      OIDC_DOMAIN="auth.${ENV}.vantagecompute.ai/realms/vantage"
      if [ "$ENV" == "dev" ]; then
          SNAP_CHANNEL="edge"
      elif [ "$ENV" == "qa" ]; then
          SNAP_CHANNEL="beta"
      else
          SNAP_CHANNEL="candidate"
      fi
  fi

  # Create the cloud-init file and launch the demo cluster instance.
  cat <<EOF > /tmp/cloud-init.yaml
#cloud-config
snap:
  commands:
    0: snap install vantage-agent --channel=$SNAP_CHANNEL --classic
    1: snap install jobbergate-agent --channel=$SNAP_CHANNEL --classic

runcmd:
  - sed -i "s|@HEADNODE_HOSTNAME@|\$(hostname)|g" /etc/slurm/slurmdbd.conf
  - sed -i "s|@HEADNODE_ADDRESS@|\$(hostname -I | awk '{print \$1}')|g" /etc/slurm/slurm.conf
  - sed -i "s|@HEADNODE_HOSTNAME@|\$(hostname)|g" /etc/slurm/slurm.conf
  - |
    cpu_info=\$(lscpu -J | jq)

    CPUs=\$(echo \$cpu_info | jq -r '.lscpu | .[] | select(.field == "CPU(s):") | .data')
    sed -i "s|@CPUs@|\$CPUs|g" /etc/slurm/slurm.conf

    THREADS_PER_CORE=\$(echo \$cpu_info | jq -r '.lscpu | .[] | select(.field == "Thread(s) per core:") | .data')
    sed -i "s|@THREADS_PER_CORE@|\$THREADS_PER_CORE|g" /etc/slurm/slurm.conf

    CORES_PER_SOCKET=\$(echo \$cpu_info | jq -r '.lscpu | .[] | select(.field == "Core(s) per socket:") | .data')
    sed -i "s|@CORES_PER_SOCKET@|\$CORES_PER_SOCKET|g" /etc/slurm/slurm.conf

    SOCKETS=\$(echo \$cpu_info | jq -r '.lscpu | .[] | select(.field == "Socket(s):") | .data')
    sed -i "s|@SOCKETS@|\$SOCKETS|g" /etc/slurm/slurm.conf

    REAL_MEMORY=\$(free -m | grep -oP '\\d+' | head -n 1)
    sed -i "s|@REAL_MEMORY@|\$REAL_MEMORY|g" /etc/slurm/slurm.conf
  - systemctl restart slurmdbd
  - sleep 30
  - systemctl restart slurmctld
  - systemctl restart slurmd
  - scontrol update NodeName=\$(hostname) State=RESUME
  - snap set vantage-agent base-api-url=$BASE_API_URL
  - snap set vantage-agent oidc-domain=$OIDC_DOMAIN
  - snap set vantage-agent oidc-client-id=$CLIENT_ID
  - snap set vantage-agent oidc-client-secret=$CLIENT_SECRET
  - snap set vantage-agent oidc-domain=$OIDC_DOMAIN
  - snap set vantage-agent task-jobs-interval-seconds=30
  - snap set jobbergate-agent base-api-url=$BASE_API_URL
  - snap set jobbergate-agent oidc-domain=$OIDC_DOMAIN
  - snap set jobbergate-agent oidc-client-id=$CLIENT_ID
  - snap set jobbergate-agent oidc-client-secret=$CLIENT_SECRET
  - snap set jobbergate-agent oidc-domain=$OIDC_DOMAIN
  - snap set jobbergate-agent task-jobs-interval-seconds=30
  - snap set jobbergate-agent x-slurm-user-name=root
  - snap set jobbergate-agent influx-dsn=influxdb://slurm:rats@localhost:8086/slurm-job-metrics
  - snap start vantage-agent.start --enable
  - snap start jobbergate-agent.start --enable
EOF

  mkdir -p $HOME/democluster/tmp

  cat /tmp/cloud-init.yaml | multipass launch -c$(nproc) \
  -m4G \
  --mount=$HOME/democluster:/nfs/mnt \
  -n democluster-`echo "$CLIENT_ID" | sed 's/-[0-9a-f]\{8\}-[0-9a-f]\{4\}-4[0-9a-f]\{3\}-[89abAB][0-9a-f]\{3\}-[0-9a-f]\{12\}//'` \
  $IMAGE_ORIGIN \
  --cloud-init -

  rm -f /tmp/cloud-init.yaml
}

# Check if multipass is installed
if [ -z $(snap list | grep multipass | awk '{ print $1 }') ]; then
  echo "Multipass is required but not installed. Please install multipass on the system."
  exit 1
else
  echo "Multipass is installed. Proceeding..."
fi

# deletes the temp directory
cleanup () {
  rm -f /tmp/cloud-init.yaml
}

# Perform variable checks.
perform_variable_checks

# Launch democluster.
launch_instance

# register the cleanup function to be called on the EXIT signal
trap cleanup EXIT
