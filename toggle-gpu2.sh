#!/bin/bash
# Usage: sudo ./toggle-gpu2.sh [load|unload]

set -e

# ── EDIT THESE ─────────────────────────────────────────────────────────
PCI_VGA="0000:01:00:0"        # your 01:00.0
PCI_AUDIO="0000:01:00.1"      # your 01:00.1
VFIO_DRIVER="vfio-pci"
NVIDIA_DRIVERS_UNLOAD="nvidia_uvm nvidia_peermem nvidia_drm nvidia_modset nvidia"
NVIDIA_DRIVERS_LOAD="nvidia nvidia_modest nvidia_drm nvidia_peermem nvidia_uvm"
AUDIO_DRIVER="snd_hda_intel"
# ──────────────────────────────────────────────────────────────────────

unbind_device() {
  local dev=$1
  echo "[INFO] Unbinding $dev from its current driver..."
  echo "$dev" > /sys/bus/pci/devices/$dev/driver/unbind || true
}

bind_device() {
  local dev=$1 driver=$2
  echo "[INFO] Binding $dev to $driver..."
  echo "$dev" > /sys/bus/pci/drivers/$driver/bind
}

case "$1" in
  load)
    # 1) Detach both from VFIO
    unbind_device $PCI_VGA
    unbind_device $PCI_AUDIO

    # 2) Remove VFIO module
    echo "[INFO] Removing $VFIO_DRIVER..."
    modprobe -r $VFIO_DRIVER || true

    # 3) Load NVIDIA modules
    echo "[INFO] Loading NVIDIA modules..."
    for m in "${NVIDIA_DRIVERS_LOAD[@]}"; do
      modprobe $m
    done

    # 4) Ensure audio driver is loaded
    echo "[INFO] Loading audio driver $AUDIO_DRIVER..."
    modprobe $AUDIO_DRIVER || true

    # 5) Bind VGA → nvidia & Audio → snd_hda_intel
    bind_device $PCI_VGA nvidia
    bind_device $PCI_AUDIO $AUDIO_DRIVER

    echo "[DONE] NVIDIA stack up; audio on HDMI ready."
    ;;
  
  unload)
    # 1) Detach both from their drivers
    unbind_device $PCI_VGA
    unbind_device $PCI_AUDIO

    # 2) Unload NVIDIA modules
    echo "[INFO] Unloading NVIDIA modules..."
    for m in "${NVIDIA_DRIVERS_UNLOAD[@]}"; do
      modprobe -r $m || true
    done

    # 3) Unload audio driver
    echo "[INFO] Unloading audio driver $AUDIO_DRIVER..."
    modprobe -r $AUDIO_DRIVER || true

    # 4) Load VFIO and bind both devices
    echo "[INFO] Loading $VFIO_DRIVER..."
    modprobe $VFIO_DRIVER

    bind_device $PCI_VGA $VFIO_DRIVER
    bind_device $PCI_AUDIO $VFIO_DRIVER

    echo "[DONE] Both VGA and audio now bound to VFIO for passthrough."
    ;;
  
  *)
    echo "Usage: $0 [load|unload]"
    exit 1
    ;;
esac
