#!/bin/bash

CLIENT_ID=$1
CLIENT_SECRET=$2
BASE_API_URL="https://apis.vantagecompute.ai"
OIDC_DOMAIN="auth.vantagecompute.ai/realms/vantage"

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
  - |
  - systemctl restart slurmdbd
  - sleep 30
  - systemctl restart slurmctld
  - systemctl restart slurmd
  - scontrol update NodeName=\$(hostname) State=RESUME

  - snap set vantage-agent base-api-url=$BASE_API_URL
  - snap set vantage-agent oidc-client-id=$CLIENT_ID
  - snap set vantage-agent oidc-client-secret=$CLIENT_SECRET
  - snap set vantage-agent oidc-domain=$OIDC_DOMAIN
  - snap set vantage-agent task-jobs-interval-seconds=30
  - snap set jobbergate-agent base-api-url=$BASE_API_URL
  - snap set jobbergate-agent oidc-client-id=$CLIENT_ID
  - snap set jobbergate-agent oidc-client-secret=$CLIENT_SECRET
  - snap set jobbergate-agent oidc-domain=$OIDC_DOMAIN
  - snap set jobbergate-agent task-jobs-interval-seconds=30
  - snap set jobbergate-agent x-slurm-user-name=ubuntu
  - snap set jobbergate-agent influx-dsn=influxdb://slurm:rats@localhost:8086/slurm-job-metrics
  - snap start vantage-agent.start --enable
  - snap start jobbergate-agent.start --enable
EOF

mkdir -p $HOME/democluster

cat /tmp/cloud-init.yaml | multipass launch -c$(nproc) \
-m4GB \
--mount $HOME/democluster:/nfs/mnt \
-ndemocluster \
file://`pwd`/democluster.img \
--cloud-init -

rm -f /tmp/cloud-init.yaml
