#!/bin/bash
read -r gpu temp mem_used mem_total <<< $(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits | tr ',' ' ')
echo "${gpu}%|${temp}°C|${mem_used}/${mem_total}MiB"
