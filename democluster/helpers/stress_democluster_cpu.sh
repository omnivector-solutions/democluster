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