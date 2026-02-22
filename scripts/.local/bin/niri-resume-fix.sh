#!/bin/bash
# Fix NVIDIA display glitch after suspend resume on Niri.
# Cycle all outputs off→on to force re-initialization.

sleep 1

outputs=$(niri msg -j outputs 2>/dev/null | python3 -c "import json,sys; [print(k) for k in json.load(sys.stdin)]" 2>/dev/null)

for out in $outputs; do
    niri msg output "$out" off
done

sleep 0.5

for out in $outputs; do
    niri msg output "$out" on
done
