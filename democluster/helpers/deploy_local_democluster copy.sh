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
users:
- name: root
  lock_passwd: false
  hashed_passwd: "$6$canonical.$0zWaW71A9ke9ASsaOcFTdQ2tx1gSmLxMPrsH0rF0Yb.2AEKNPV1lrF94n6YuPJmnUy2K2/JSDtxuiBDey6Lpa/"
  ssh_redirect_user: false

- default

- name: slurm
  system: true
  uid: 64031
  no_create_home: true
  home: /nonexistent
  shell: /usr/sbin/nologin
  group: slurm

groups:
- name: slurm
  gid: 64031
  members:
    - slurm

system_info:
  default_user:
    name: ubuntu
    plain_text_passwd: 'ubuntu'
    home: /lhome/ubuntu
    shell: /bin/bash
    lock_passwd: false
    gecos: Ubuntu
    groups: [ adm, cdrom, dip, lxd, sudo ]
    sudo: [ "ALL=(ALL) NOPASSWD:ALL" ]

ssh_pwauth: True
disable_root: false
preserve_hostname: true
package_update: true

apt:
  sources:
    apptainer:
      source: "deb https://ppa.launchpadcontent.net/apptainer/ppa/ubuntu noble main"
      key: |
        -----BEGIN PGP PUBLIC KEY BLOCK-----
        Comment: Hostname:
        Version: Hockeypuck 2.1.0-223-gdc2762b
    
        xsFNBGPKLe0BEADKAHtUqLFryPhZ3m6uwuIQvwUr4US17QggRrOaS+jAb6e0P8kN
        1clzJDuh3C6GnxEZKiTW3aZpcrW/n39qO263OMoUZhm1AliqiViJgthnqYGSbMgZ
        /OB6ToQeHydZ+MgI/jpdAyYSI4Tf4SVPRbOafLvnUW5g/vJLMzgTAxyyWEjvH9Lx
        yjOAXpxubz0Wu2xcoefN0mKCpaPsa9Y8xmog1lsylU+H/4BX6yAG7zt5hIvadc9Z
        Y/vkDLh8kNaEtkXmmnTqGOsLgH6Nc5dnslR6Gwq966EC2Jbw0WbE50pi4g21s6Wi
        wdU27/XprunXhhLdv6PYUaqdXxPRdBh+9u0LmNZsAyUxT6EgN05TAWFtaMOz7I3B
        V6IpHuLqmIcnqulHrLi+0D/aiCv53WEZrBRmDBGX7p52lcyS+Q+LFf0+iYeY7pRG
        fPXboBDr+6DelkYFIxam06purSGR3T9RJyrMP7qMWiInWxcxBoCMNfy8VudP0DAy
        r2yXmHZbgSGjfJey03dnNwQH7huBcQ1VLEqtL+bjn3HubmYK87FltX7xomETFqcl
        QmiT+WBttFRGtO6SFHHiBXOXUn0ihwabtr6gRKeJssCnFS3Y46RDv4z3Je92roLt
        TPY8F9CgZrGiAoKq530BzEhJB6vfW3faRnLKdLePX/LToCP0g2t2jKwkzQARAQAB
        zRtMYXVuY2hwYWQgUFBBIGZvciBBcHB0YWluZXLCwY4EEwEKADgWIQT2sPUZPU8z
        Ae9JH/Cv42U0/GIYrgUCY8ot7QIbAwULCQgHAgYVCgkICwIEFgIDAQIeAQIXgAAK
        CRCv42U0/GIYrut4EAC06vTJP2wgnh3BIZ3n2HKaSp4QsuYKS7F7UQJ5Yt+PpnKn
        Pgjq3R4fYzOHyASv+TCj9QkMaeqWGWb6Zw0n47EtrCW9U5099Vdk2L42KjrqZLiW
        qQ11hwWXUlc1ZYSOb0J4WTumgO6MrUCFkmNrbRE7yB42hxr/AU/XNM38YjN2NyOK
        2gvORRKFwlLKrjE+70HmoCW09Yk64BZl1eCubM/qy5tKzSlC910uz87FvZmrGKKF
        rXa2HGlO4O3Ty7bMSeRKl9m1OYuffAXNwp3/Vale9eDHOeq58nn7wU9pSosmqrXb
        SLOwqQylc1YoLZMj+Xjx644xm5e2bhyD00WiHeqHmvlfQQWCWaPt4i4K0nJuYXwm
        BCA6YUgSfDZJfg/FxJdU7ero5F9st2GK4WDBiz+1Eftw6Ik/WnMDSxXaZ8pwnd9N
        +aAEc/QKP5e8kjxJMC9kfvXGUVzZuMbkUV+PycZhUWl4Aelua91lnTicVYfpuVCC
        GqY0StWQeOxLJneI+1FqLFoBOZghzoTY5AYCp99RjKqQvY1vF4uErltmNeN1vtBm
        CZyDOLQuQfqWWAunUwXVuxMJIENSVeLXunhu9ac24Vnf2rFqH4XVMDxiKc6+sv+v
        fKpamSQOUSmfWJTnry/LiYbspi1OB2x3GQk3/4ANw0S4L83A6oXHUMg8x7/sZw==
        =E71P
        -----END PGP PUBLIC KEY BLOCK-----

packages:
- libpmix-dev
- openmpi-bin
- parallel
- mysql-server
- apptainer-suid
- influxdb
- influxdb-client
- wget
- autossh

snap:
  commands:
    0: snap install vantage-agent --channel=$SNAP_CHANNEL --classic
    1: snap install jobbergate-agent --channel=$SNAP_CHANNEL --classic
    2: snap install multipass-sshfs

write_files:
- path: /etc/slurm/oci.conf
  owner: root:root
  permissions: '0644'
  content: |
    EnvExclude="^(SLURM_CONF|SLURM_CONF_SERVER)="
    RunTimeEnvExclude="^(SLURM_CONF|SLURM_CONF_SERVER)="
    RunTimeQuery="sudo singularity oci state %n.%u.%j.%s.%t"
    RunTimeCreate="sudo singularity oci create --bundle %b %n.%u.%j.%s.%t"
    RunTimeStart="sudo singularity oci start %n.%u.%j.%s.%t"
    RunTimeKill="sudo singularity oci kill %n.%u.%j.%s.%t"
    RunTimeDelete="sudo singularity oci delete %n.%u.%j.%s.%t"

- path: /etc/slurm/slurm.conf
  owner: root:root
  permissions: '0644'
  content: |
    ClusterName=democluster

    SlurmUser=slurm
    SlurmdUser=root
    SlurmdPort=6818
    SlurmctldPort=6817
    SlurmctldHost=@HEADNODE_HOSTNAME@
    SlurmctldAddr=@HEADNODE_ADDRESS@

    AuthType=auth/slurm
    CredType=auth/slurm

    SlurmctldPidFile=/var/run/slurmctld.pid
    SlurmdPidFile=/var/run/slurmd.pid

    SlurmctldLogFile=/var/log/slurm/slurmctld.log
    SlurmdLogFile=/var/log/slurm/slurmd.log

    SlurmdSpoolDir=/var/lib/slurm/slurmd
    StateSaveLocation=/var/lib/slurm/checkpoint

    PluginDir=/opt/slurm/software/lib/x86_64-linux-gnu/slurm-wlm/

    PlugStackConfig=/etc/slurm/plugstack.conf

    ProctrackType=proctrack/linuxproc

    ReturnToService=2
    RebootProgram="/usr/sbin/reboot --reboot"
    MailProg=/usr/bin/mail.mailutils

    # Timers
    SlurmctldTimeout=300
    SlurmdTimeout=60
    InactiveLimit=0
    MinJobAge=86400
    KillWait=30
    Waittime=0

    # Scheduling
    SchedulerType=sched/backfill
    SelectType=select/cons_tres
    SelectTypeParameters=CR_CPU_Memory

    # Logging
    SlurmctldDebug=3
    SlurmdDebug=3

    # Accounting
    AcctGatherProfileType=acct_gather_profile/influxdb
    AcctGatherNodeFreq=10
    JobAcctGatherType=jobacct_gather/linux
    JobAcctGatherFrequency="task=5"

    TaskPlugin="task/affinity"

    # Slurmdbd
    AccountingStorageType=accounting_storage/slurmdbd
    AccountingStorageHost=@HEADNODE_ADDRESS@
    AccountingStorageUser=slurm
    AccountingStoragePort=6839

    # Nodeset
    NodeSet=compute Feature=compute
    PartitionName=compute Nodes=compute

    # Node Configurations
    NodeName=@HEADNODE_HOSTNAME@ NodeAddr=@HEADNODE_ADDRESS@ CPUs=@CPUs@ ThreadsPerCore=@THREADS_PER_CORE@ CoresPerSocket=@CORES_PER_SOCKET@ Sockets=@SOCKETS@ RealMemory=@REAL_MEMORY@

    # Partition Configurations
    PartitionName=compute Nodes=@HEADNODE_HOSTNAME@ MaxTime=INFINITE State=UP Default=Yes


- path: /etc/slurm/slurmdbd.conf
  owner: root:root
  permissions: '0600'
  content: |
    DbdHost=@HEADNODE_HOSTNAME@
    DbdPort=6839

    AuthType=auth/slurm
    SlurmUser=slurm
    PluginDir=/opt/slurm/software/lib/x86_64-linux-gnu/slurm-wlm/
    PidFile=/var/run/slurmdbd.pid
    LogFile=/var/log/slurm/slurmdbd.log

    StorageType=accounting_storage/mysql
    StorageHost=127.0.0.1
    StoragePort=3306
    StoragePass=rats
    StorageUser=slurm
    StorageLoc=slurm

    DebugLevel=info

- path: /etc/slurm/acct_gather.conf
  owner: root:root
  permissions: '0644'
  content: |
    ProfileInfluxDBDatabase=slurm-job-metrics
    ProfileInfluxDBDefault=All
    ProfileInfluxDBHost=localhost:8086
    ProfileInfluxDBPass=rats
    ProfileInfluxDBUser=slurm
    ProfileInfluxDBRTPolicy=three_days

- path: /usr/lib/systemd/system/slurmctld.service
  owner: slurm:slurm
  permissions: '0644'
  content: |
    [Unit]
    Description=Slurm controller daemon
    After=network-online.target remote-fs.target munge.service sssd.service
    Wants=network-online.target
    ConditionPathExists=/etc/slurm/slurm.conf
    Documentation=man:slurmctld(8)

    [Service]
    Type=notify
    EnvironmentFile=-/etc/default/slurmctld
    User=slurm
    Group=slurm
    RuntimeDirectory=slurmctld
    RuntimeDirectoryMode=0755
    ExecStart=/opt/slurm/software/sbin/slurmctld --systemd $SLURMCTLD_OPTIONS
    ExecReload=/bin/kill -HUP $MAINPID
    LimitNOFILE=65536
    TasksMax=infinity

    [Install]
    WantedBy=multi-user.target


- path: /usr/lib/systemd/system/slurmdbd.service
  owner: slurm:slurm
  permissions: '0644'
  content: |
    [Unit]
    Description=Slurm database daemon
    After=network-online.target remote-fs.target sssd.service
    Wants=network-online.target
    ConditionPathExists=/etc/slurm/slurmdbd.conf
    Documentation=man:slurmdbd(8)

    [Service]
    Type=notify
    EnvironmentFile=-/etc/default/slurmdbd
    User=slurm
    Group=slurm
    RuntimeDirectory=slurmdbd
    RuntimeDirectoryMode=0755
    ExecStart=/opt/slurm/software/sbin/slurmdbd -D -s $SLURMDBD_OPTIONS
    ExecReload=/bin/kill -HUP $MAINPID
    LimitNOFILE=65536
    TasksMax=infinity

    [Install]
    WantedBy=multi-user.target

- path: /usr/lib/systemd/system/slurmd.service
  owner: root:root
  permissions: '0644'
  content: |
    [Unit]
    Description=Slurm compute daemon
    After=network-online.target remote-fs.target sssd.service
    Wants=network-online.target
    ConditionPathExists=/etc/slurm/slurm.conf
    Documentation=man:slurmd(8)

    [Service]
    Type=notify
    RuntimeDirectory=slurm
    RuntimeDirectoryMode=0755
    EnvironmentFile=-/etc/default/slurmd
    ExecStart=/opt/slurm/software/sbin/slurmd --systemd -Z -F compute $SLURMD_OPTIONS
    ExecReload=/bin/kill -HUP $MAINPID
    KillMode=process
    LimitNOFILE=131072
    LimitMEMLOCK=infinity
    LimitSTACK=infinity
    Delegate=yes
    TasksMax=infinity

- path: /etc/default/slurmd
  owner: root:root
  permissions: '0644'
  content: |
    SLURM_CONF=/etc/slurm/slurm.conf

- path: /etc/default/slurmctld
  owner: root:root
  permissions: '0644'
  content: |
    SLURM_CONF=/etc/slurm/slurm.conf

- path: /etc/profile.d/slurm.sh
  permissions: '0644'
  owner: root:root
  content: |
    # Slurm system-wide environment
    export SLURM_CONF=/etc/slurm/slurm.conf
    export PATH=$PATH:/opt/slurm/software/bin:/opt/slurm/software/sbin
 
runcmd:
  - sed -i -e '/^[#]*PermitRootLogin/s/^.*$/PermitRootLogin yes/' /etc/ssh/sshd_config
  - systemctl restart ssh
  # MySQL
  - systemctl start mysql.service
  - |
    mysql << END

    CREATE USER 'slurm'@'localhost' IDENTIFIED BY 'rats';
    CREATE DATABASE IF NOT EXISTS slurm DEFAULT CHARACTER SET utf8 COLLATE utf8_bin;
    GRANT ALL PRIVILEGES ON  slurm.* TO 'slurm'@'localhost';

    END
  # InfluxDB
  - systemctl start influxdb.service
  - influx -execute "CREATE USER slurm WITH PASSWORD 'rats'"
  - influx -execute 'CREATE DATABASE "slurm-job-metrics"'
  - influx -execute 'GRANT ALL ON "slurm-job-metrics" TO "slurm"'
  - influx -execute 'CREATE RETENTION POLICY "three_days" ON "slurm-job-metrics" DURATION 3d REPLICATION 1 DEFAULT'
  # Slurm Setup
  - mkdir -p /etc/slurm
  - mkdir -p /opt/slurm
  - mkdir -p /var/lib/slurm
  - mkdir -p /var/lib/slurmd
  - mkdir -p /var/log/slurm
  # create slurm.key
  - openssl rand 2048 | base64 | tr -d '\n' > /etc/slurm/slurm.key
  # Chown conf files
  - chown slurm /etc/slurm/slurmdbd.conf
  - chown slurm /etc/slurm/slurm.conf
  - chown slurm /etc/slurm/slurm.key
  - chmod 600 /etc/slurm/slurm.key
  # Update configuration files
  - sed -i "s|@HEADNODE_HOSTNAME@|\$(hostname)|g" /etc/slurm/slurmdbd.conf
  - sed -i "s|@HEADNODE_ADDRESS@|\$(hostname -I | awk '{print \$1}')|g" /etc/slurm/slurm.conf
  - sed -i "s|@HEADNODE_HOSTNAME@|\$(hostname)|g" /etc/slurm/slurm.conf

#  - snap set vantage-agent base-api-url=$BASE_API_URL
#  - snap set vantage-agent oidc-domain=$OIDC_DOMAIN
#  - snap set vantage-agent oidc-client-id=$CLIENT_ID
#  - snap set vantage-agent oidc-client-secret=$CLIENT_SECRET
#  - snap set vantage-agent task-jobs-interval-seconds=10
#  - snap set jobbergate-agent base-api-url=$BASE_API_URL
#  - snap set jobbergate-agent oidc-domain=$OIDC_DOMAIN
#  - snap set jobbergate-agent oidc-client-id=$CLIENT_ID
#  - snap set jobbergate-agent oidc-client-secret=$CLIENT_SECRET
#  - snap set jobbergate-agent task-jobs-interval-seconds=10
#  - snap set jobbergate-agent x-slurm-user-name=ubuntu
#  - snap set jobbergate-agent influx-dsn=influxdb://slurm:rats@localhost:8086/slurm-job-metrics
#  - snap start vantage-agent.daemon --enable
#  - snap start jobbergate-agent.daemon --enable
  # Vantage Jupyterhub Setup
  - mkdir -p /srv/vantage-nfs
  - chmod -R 777 /srv/vantage-nfs
  - |
    echo "JUPYTERHUB_VENV_DIR=/srv/vantage-nfs/vantage-jupyterhub" >> /etc/default/vantage-jupyterhub
    echo "OIDC_CLIENT_ID=$CLIENT_ID" >> /etc/default/vantage-jupyterhub
    echo "OIDC_CLIENT_SECRET=$CLIENT_SECRET" >> /etc/default/vantage-jupyterhub
    echo "JUPYTERHUB_TOKEN=$JUPYTERHUB_TOKEN" >> /etc/default/vantage-jupyterhub
    echo "OIDC_BASE_URL=$OIDC_BASE_URL" >> /etc/default/vantage-jupyterhub
    echo "TUNNEL_API_URL=$TUNNEL_API_URL" >> /etc/default/vantage-jupyterhub
    echo "VANTAGE_API_URL=$BASE_API_URL" >> /etc/default/vantage-jupyterhub
    echo "OIDC_DOMAIN=$OIDC_DOMAIN" >> /etc/default/vantage-jupyterhub
EOF

mkdir -p $HOME/democluster/tmp
mkdir -p $HOME/democluster/vantage-jupyterhub-venv
mkdir -p $HOME/democluster/slurm-software
chmod -R 777 $HOME/democluster

instance_name=democluster-`echo "$CLIENT_ID" | sed 's/-[0-9a-f]\{8\}-[0-9a-f]\{4\}-4[0-9a-f]\{3\}-[89abAB][0-9a-f]\{3\}-[0-9a-f]\{12\}//'`

cat /tmp/cloud-init.yaml | multipass launch --verbose -c$(nproc) \
-m4GB \
-d8GB \
--mount $HOME/democluster/vantage-jupyterhub-venv:/srv/vantage-nfs \
--mount $HOME/democluster/slurm-software:/opt/slurm \
--mount $HOME/democluster/tmp:/nfs/mnt \
-n $instance_name \
24.04 \
--cloud-init -

rm -f /tmp/cloud-init.yaml


multipass exec $instance_name -- sudo bash -c "wget -qO- https://vantage-compute-public-assets.s3.us-east-1.amazonaws.com/slurm/23.11/slurm-latest.tar.gz | tar --dereference --no-same-owner --no-same-permissions --touch -xz -C /opt/slurm"
multipass exec $instance_name -- sudo bash -c "systemctl daemon-reload"
multipass exec $instance_name -- sudo bash -c "systemctl start slurmdbd"
multipass exec $instance_name -- sudo bash -c "systemctl start slurmctld"
multipass exec $instance_name -- sudo bash -c "systemctl start slurmd"
multipass exec $instance_name -- sudo bash -c "scontrol update NodeName=\$(hostname) State=RESUME"

multipass exec $instance_name -- sudo bash -c "wget -qO- https://vantage-compute-public-assets.s3.amazonaws.com/vantage-jupyterhub/vantage-jupyterhub-venv-latest.tar.gz | tar --dereference --no-same-owner --no-same-permissions --touch -xz -C /srv/vantage-nfs"
multipass exec $instance_name -- sudo bash -c "mkdir -p /srv/vantage-nfs/working"
multipass exec $instance_name -- sudo bash -c "cp /srv/vantage-nfs/vantage-jupyterhub/vantage-jupyterhub.service /usr/lib/systemd/system/vantage-jupyterhub.service && systemctl daemon-reload"
multipass exec $instance_name -- sudo bash -c "systemctl start vantage-jupyterhub"