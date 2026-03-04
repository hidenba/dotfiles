#!/bin/bash
# Fix NVIDIA display glitch after suspend resume on Niri.
# Wait for GPU readiness, then cycle all outputs off→on to force re-initialization.

LOG_TAG="niri-resume-fix"

log() {
    logger -t "$LOG_TAG" "$1"
}

# Wait for NVIDIA GPU to become responsive
wait_for_gpu() {
    local max_attempts=15
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if nvidia-smi -q > /dev/null 2>&1; then
            log "GPU responsive after $attempt attempts"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
    log "GPU not responsive after $max_attempts attempts"
    return 1
}

cycle_outputs() {
    local outputs
    outputs=$(niri msg -j outputs 2>/dev/null | python3 -c "import json,sys; [print(k) for k in json.load(sys.stdin)]" 2>/dev/null)

    if [ -z "$outputs" ]; then
        log "No outputs detected"
        return 1
    fi

    log "Cycling outputs: $outputs"

    for out in $outputs; do
        niri msg output "$out" off 2>/dev/null
    done

    sleep 0.5

    for out in $outputs; do
        niri msg output "$out" on 2>/dev/null
    done
}

log "Starting resume fix"

# Wait for GPU to be fully ready
wait_for_gpu || exit 1

# Retry output cycling up to 3 times
max_retries=3
for i in $(seq 1 $max_retries); do
    log "Attempt $i/$max_retries"
    cycle_outputs && break
    sleep 2
done

log "Resume fix completed"
