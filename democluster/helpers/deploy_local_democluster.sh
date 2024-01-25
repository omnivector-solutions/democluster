#!/bin/bash

CLIENT_ID=$1
CLIENT_SECRET=$2

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
  - systemctl start slurmrestd
  - systemctl restart slurmdbd
  - systemctl restart slurmd
  - sleep 30
  - systemctl restart slurmctld
  - scontrol update NodeName=\$(hostname) State=RESUME
  - systemctl start jobbergate-agent
EOF

mkdir -p $HOME/democluster

cat /tmp/cloud-init.yaml | multipass launch -c$(nproc) \
-m4GB \
--mount $HOME/democluster:/home/ubuntu/democluster \
-ndemocluster \
file://`pwd`/democluster.img \
--cloud-init -

rm -f /tmp/cloud-init.yaml
