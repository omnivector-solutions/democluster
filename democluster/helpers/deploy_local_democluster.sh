#!/bin/bash

CLIENT_ID=$1
CLIENT_SECRET=$2
ENV=$3


# Check if CLIENT_ID and CLIENT_SECRET are provided.
if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
  echo "Please provide the CLIENT_ID and CLIENT_SECRET as command-line arguments."
  exit 1
fi

# Check if ENV is set to a valid value
if [ -n "$ENV" ]; then
  if [[ "$ENV" != "staging" && "$ENV" != "qa" && "$ENV" != "dev" ]]; then
    echo "Invalid ENV value. It must be one of 'staging', 'qa' or 'dev'."
    exit 1
  fi
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
  - systemctl start slurmrestd
  - systemctl restart slurmdbd
  - systemctl restart slurmd
  - sleep 30
  - systemctl restart slurmctld
  - scontrol update NodeName=\$(hostname) State=RESUME
  - snap set vantage-agent base-api-url=$BASE_API_URL
  - snap set vantage-agent oidc-domain=$OIDC_DOMAIN
  - snap set vantage-agent oidc-client-id=$CLIENT_ID
  - snap set vantage-agent oidc-client-secret=$CLIENT_SECRET
  - snap set vantage-agent task-jobs-interval-seconds=30
  - snap set jobbergate-agent base-api-url=$BASE_API_URL
  - snap set jobbergate-agent oidc-domain=$OIDC_DOMAIN
  - snap set jobbergate-agent oidc-client-id=$CLIENT_ID
  - snap set jobbergate-agent oidc-client-secret=$CLIENT_SECRET
  - snap set jobbergate-agent task-jobs-interval-seconds=30
  - snap set jobbergate-agent x-slurm-user-name=root
  - snap set jobbergate-agent influx-dsn=influxdb://slurm:rats@localhost:8086/slurm-job-metrics
  - snap start vantage-agent.start
  - snap start jobbergate-agent.start
EOF

mkdir -p $HOME/democluster || true

cat /tmp/cloud-init.yaml | multipass launch --verbose -c$(nproc) \
-m4GB \
--mount $HOME/democluster:/home/ubuntu/democluster \
-ndemocluster \
file://`pwd`/democluster/final/democluster.img \
--cloud-init -

rm -f /tmp/cloud-init.yaml
