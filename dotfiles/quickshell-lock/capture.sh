#!/usr/bin/env bash
# Capture each output before Quickshell acquires the lock. systemd owns and
# removes the private runtime directory, including on crashes/startup failures.
umask 077
directory="$XDG_RUNTIME_DIR/workstation-lock"
backgrounds='{}'
outputs=()
pids=()

# Failed enumeration leaves no backgrounds; the locker then uses opaque black.
mapfile -d '' -t outputs < <(
    timeout -k 0.2s 0.5s niri msg --json outputs 2>/dev/null |
        jq -j 'to_entries[] | select(.value.current_mode != null) | .key + "\u0000"' 2>/dev/null
)

for index in "${!outputs[@]}"; do
    timeout -k 0.2s 1s grim -o "${outputs[$index]}" -s 0.5 \
        "$directory/$index.png" >/dev/null 2>&1 &
    pids+=("$!")
done

for index in "${!outputs[@]}"; do
    path="$directory/$index.png"
    if wait "${pids[$index]}" && [[ -s "$path" ]]; then
        backgrounds=$(jq -c --arg name "${outputs[$index]}" --arg path "$path" \
            '. + {($name): ("file://" + ($path | split("/") | map(@uri) | join("/")))}' \
            <<< "$backgrounds")
    else
        rm -f "$path"
    fi
done

export WORKSTATION_LOCK_BACKGROUNDS="$backgrounds"
