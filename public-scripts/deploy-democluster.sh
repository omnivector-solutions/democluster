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
#   1. Provide your CLIENT_ID and CLIENT_SECRET as environment variables:
#      ```
#      CLIENT_ID=<CLIENT_ID> CLIENT_SECRET=<CLIENT_SECRET> ./deploy-democluster.sh
#      ```
#   2. The script will identify the host's operating system and install
#      necessary dependencies (Multipass, Homebrew, etc.) accordingly.
#   3. A cloud-init script is generated to customize the Multipass instance.
#   4. The Multipass instance is launched with the specified configuration.
#
# Prerequisites:
#   - Bash shell
#   - Internet connectivity for downloading dependencies (Multipass, Homebrew)
#   - Non-optional environment variables set:
#     - CLIENT_ID
#     - CLIENT_SECRET
#
# Optional Environment Variables:
#
#   - ENV: The non-production environment to include in API URLs. (e.g. "staging", "dev", etc)
#   - DOMAIN: The non-standard domain for API URLs. (e.g. "private-vantage.io")
#   - JG_VERSION: The specific version of the jobbergate-agent to install (e.g. 4.4.0)
#
# Configuration:
#   - Modify the script's constants (e.g., NUM_CPUS, MEMORY, IMAGE_URL) to
#     match your desired configuration.
#
# Notes:
#   - This script has been tested on both Ubuntu 20.04 and 22.04.
#   - Ensure you have appropriate permissions to execute system-level commands.
#   - Logging is recommended for monitoring the script's progress.
#
################################################################################

# Check for the required environment variables
if [ -z $CLIENT_ID ]; then
  echo "You must set the CLIENT_ID variable."
  exit 1
fi
if [ -z $CLIENT_SECRET ]; then
  echo "You must set the CLIENT_SECRET variable."
  exit 1
fi

# Set the environment to the empty string if not supplied in the optional ENV variable
if [ -z $ENV ]; then
  ENVIRONMENT=""
else
  echo "Using optional setting ENV=$ENV for vantage URLs."
  ENVIRONMENT="${ENV}."
fi

# Set the environment to the empty string if not supplied in the optional ENV variable
if [ -z $DOMAIN ]; then
  DOMAIN="vantagehpc.io"
fi
echo "Using setting DOMAIN=$DOMAIN for vantage URLs."


IMAGE_CACHE=$HOME/democluster/image_cache
MOUNTED_DIR=$HOME/democluster/mount

mkdir -p $IMAGE_CACHE $MOUNTED_DIR/tmp

CLOUD_IMAGE_URL=https://omnivector-public-assets.s3.us-west-2.amazonaws.com/cloud-images/democluster/latest/democluster.img
LOCAL_DEMOCLUSTER_IMG=$IMAGE_CACHE/democluster.img

if ! [ -f $LOCAL_DEMOCLUSTER_IMG ]; then
    echo "Downloading the demo cluster cloud image, hang tight..."
    curl --progress-bar --output $LOCAL_DEMOCLUSTER_IMG $CLOUD_IMAGE_URL
    echo "Download finished. Proceeding..."
fi


launch_instance () {
  # Create the cloud-init file and launch the demo cluster instance.
  cat <<EOF > /tmp/cloud-init.yaml
#cloud-config
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
  - |
    sed -i "s|@CLIENT_ID@|$CLIENT_ID|g" /srv/jobbergate-agent-venv/.env
    sed -i "s|@CLIENT_SECRET@|$CLIENT_SECRET|g" /srv/jobbergate-agent-venv/.env
    sed -i "s|@DOMAIN@|$DOMAIN|g" /srv/jobbergate-agent-venv/.env
    sed -i "s|@ENVIRONMENT@|$ENVIRONMENT|g" /srv/jobbergate-agent-venv/.env
  - systemctl start slurmrestd
  - systemctl restart slurmdbd
  - systemctl restart slurmd
  - sleep 30
  - systemctl restart slurmctld
  - scontrol update NodeName=\$(hostname) State=RESUME
  - systemctl start jobbergate-agent
EOF

  if [ -n $JG_VERSION ]; then
      echo "  - systemctl stop jobbergate-agent" >> /tmp/cloud-init.yaml
      echo "  - /srv/jobbergate-agent-venv/bin/pip install -U jobbergate-agent==$JG_VERSION" >> /tmp/cloud-init.yaml
      echo "  - systemctl start jobbergate-agent" >> /tmp/cloud-init.yaml
  fi

  cat /tmp/cloud-init.yaml | multipass launch -c$(nproc) \
  -m4GB \
  --mount=$MOUNTED_DIR:/home/ubuntu/democluster \
  -n democluster-`echo "$CLIENT_ID" | sed 's/-[0-9a-f]\{8\}-[0-9a-f]\{4\}-4[0-9a-f]\{3\}-[89abAB][0-9a-f]\{3\}-[0-9a-f]\{12\}//'` \
  file://$LOCAL_DEMOCLUSTER_IMG \
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

# Launch democluster.
launch_instance

# register the cleanup function to be called on the EXIT signal
trap cleanup EXIT
