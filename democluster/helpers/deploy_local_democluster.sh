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
    TUNNEL_API_URL="https://tunnel.vantagecompute.ai"
    OIDC_DOMAIN="auth.vantagecompute.ai/realms/vantage"
    OIDC_BASE_URL="https://$(echo $OIDC_DOMAIN | cut -d'/' -f1)"
    SNAP_CHANNEL="stable"
else
    BASE_API_URL="https://apis.${ENV}.vantagecompute.ai"
    TUNNEL_API_URL="https://tunnel.${ENV}.vantagecompute.ai"
    OIDC_DOMAIN="auth.${ENV}.vantagecompute.ai/realms/vantage"
    OIDC_BASE_URL="https://$(echo $OIDC_DOMAIN | cut -d'/' -f1)"

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
runcmd:
# Update slurm configuration files
- sed -i "s|@HEADNODE_HOSTNAME@|\$(hostname)|g" /etc/slurm/slurmdbd.conf
- sed -i "s|@HEADNODE_ADDRESS@|\$(hostname -I | awk '{print \$1}')|g" /etc/slurm/slurm.conf
- sed -i "s|@HEADNODE_HOSTNAME@|\$(hostname)|g" /etc/slurm/slurm.conf
- |
  echo "JUPYTERHUB_VENV_DIR=/srv/vantage-nfs/vantage-jupyterhub" >> /etc/default/vantage-jupyterhub
  echo "OIDC_CLIENT_ID=$CLIENT_ID" >> /etc/default/vantage-jupyterhub
  echo "OIDC_CLIENT_SECRET=$CLIENT_SECRET" >> /etc/default/vantage-jupyterhub
  echo "JUPYTERHUB_TOKEN=$JUPYTERHUB_TOKEN" >> /etc/default/vantage-jupyterhub
  echo "OIDC_BASE_URL=$OIDC_BASE_URL" >> /etc/default/vantage-jupyterhub
  echo "TUNNEL_API_URL=$TUNNEL_API_URL" >> /etc/default/vantage-jupyterhub
  echo "VANTAGE_API_URL=$BASE_API_URL" >> /etc/default/vantage-jupyterhub
  echo "OIDC_DOMAIN=$OIDC_DOMAIN" >> /etc/default/vantage-jupyterhub
- systemctl start vantage-jupyterhub

EOF

mkdir -p $HOME/democluster/tmp
mkdir -p $HOME/democluster/vantage-jupyterhub-venv
mkdir -p $HOME/democluster/slurm-software
chmod -R 777 $HOME/democluster

instance_name=democluster-`echo "$CLIENT_ID" | sed 's/-[0-9a-f]\{8\}-[0-9a-f]\{4\}-4[0-9a-f]\{3\}-[89abAB][0-9a-f]\{3\}-[0-9a-f]\{12\}//'`

cat /tmp/cloud-init.yaml | multipass launch --verbose -c$(nproc) \
-m4GB \
-d8GB \
--mount $HOME/democluster/tmp:/nfs/mnt \
-n $instance_name \
file://`pwd`/democluster/final/democluster.img \
--cloud-init -

rm -f /tmp/cloud-init.yaml


#multipass exec $instance_name -- sudo bash -c "wget -qO- https://vantage-compute-public-assets.s3.us-east-1.amazonaws.com/slurm/23.11/slurm-latest.tar.gz | tar --no-same-owner --no-same-permissions --touch -xz -C /opt/slurm"
#multipass exec $instance_name -- sudo bash -c "systemctl daemon-reload"
#multipass exec $instance_name -- sudo bash -c "systemctl start slurmdbd"
#multipass exec $instance_name -- sudo bash -c "systemctl start slurmctld"
#multipass exec $instance_name -- sudo bash -c "systemctl start slurmd"
#multipass exec $instance_name -- sudo bash -c "scontrol update NodeName=\$(hostname) State=RESUME"

#multipass exec $instance_name -- sudo bash -c "wget -qO- https://vantage-compute-public-assets.s3.amazonaws.com/vantage-jupyterhub/vantage-jupyterhub-venv-latest.tar.gz | tar --dereference --no-same-owner --no-same-permissions --touch -xz -C /srv/vantage-nfs"
#multipass exec $instance_name -- sudo bash -c "mkdir -p /srv/vantage-nfs/working"
#multipass exec $instance_name -- sudo bash -c "cp /srv/vantage-nfs/vantage-jupyterhub/vantage-jupyterhub.service /usr/lib/systemd/system/vantage-jupyterhub.service && systemctl daemon-reload"
#ultipass exec $instance_name -- sudo bash -c "systemctl start vantage-jupyterhub"