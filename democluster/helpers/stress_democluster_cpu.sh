#!/bin/bash
#SBATCH --job-name=cpu_stress
#SBATCH --ntasks=1
#SBATCH --time=0:02:00

start_time=$(date +%s)
duration=60

while true; do
    for i in {1..1000}; do
        echo "scale=10; s($i)/c($i)" | bc -l >/dev/null 2>&1
    done
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    if [ $elapsed -ge $duration ]; then
        break
    fi
done

echo "CPU stress test completed after $elapsed seconds"


runcmd:
- |
  set -e
  addgroup --gid 64031 slurm
  adduser --system --group --gid 64031 --uid 64031 --no-create-home --home /nonexistent slurm

# - snap set vantage-agent base-api-url=$BASE_API_URL
# - snap set vantage-agent oidc-domain=$OIDC_DOMAIN
# - snap set vantage-agent oidc-client-id=$CLIENT_ID
# - snap set vantage-agent oidc-client-secret=$CLIENT_SECRET
# - snap set vantage-agent task-jobs-interval-seconds=10
# - snap set jobbergate-agent base-api-url=$BASE_API_URL
# - snap set jobbergate-agent oidc-domain=$OIDC_DOMAIN
# - snap set jobbergate-agent oidc-client-id=$CLIENT_ID
# - snap set jobbergate-agent oidc-client-secret=$CLIENT_SECRET
# - snap set jobbergate-agent task-jobs-interval-seconds=10
# - snap set jobbergate-agent x-slurm-user-name=ubuntu
# - snap set jobbergate-agent influx-dsn=influxdb://slurm:rats@localhost:8086/slurm-job-metrics
# - snap start vantage-agent.daemon --enable
# - snap start jobbergate-agent.daemon --enable