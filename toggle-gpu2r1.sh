#!/usr/bin/env bash
set -euo pipefail

### ─── HARD-CODED PCI ADDRESSES ───────────────────────────────────────────────
PCI_VGA="0000:01:00.0"
PCI_AUDIO="0000:01:00.1"

### ─── DRIVER LISTS (Bash arrays!) ────────────────────────────────────────────
# VFIO side
readonly VFIO_DRIVERS_LOAD=(vfio vfio-pci vfio_iommu_type1)
readonly VFIO_DRIVERS_UNLOAD=(vfio-pci vfio_iommu_type1 vfio)

# NVIDIA side (modules to unload before VFIO bind)
readonly NVIDIA_DRIVERS_UNLOAD=(nvidia_uvm nvidia_drm nvidia_modeset nvidia i2c_nvidia_gpu drm_kms_helper drm)
# NVIDIA side (modules to load after VFIO unbind)
readonly NVIDIA_DRIVERS_LOAD=(drm drm_kms_helper i2c_nvidia_gpu nvidia nvidia_modeset nvidia_drm nvidia_uvm)

# Host audio driver for GPU’s second function
readonly AUDIO_DRIVER="snd_hda_intel"

### ─── LOGGING FUNCTION ─────────────────────────────────────────────────────
log() { echo "[$(date +'%T')] $*"; }

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 {unload|load}" >&2
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  log "ERROR:This script must be run as root or via sudo." >&2
  exit 1
fi

function stop_dm {
    ## Get display manager on systemd based distros ##
    if [[ -x /run/systemd/system ]] && log "Distro is using Systemd"; then
        DISPMGR="$(grep 'ExecStart=' /etc/systemd/system/display-manager.service | awk -F'/' '{print $(NF-0)}')"
        log "Display Manager = $DISPMGR"

        ## Stop display manager using systemd ##
        if systemctl is-active --quiet "$DISPMGR.service"; then
            grep -qsF "$DISPMGR" "/tmp/toggle-gpu.dm" || echo "$DISPMGR" >/tmp/toggle-gpu.dm
            systemctl stop "$DISPMGR.service"
            systemctl isolate multi-user.target
        fi

        while systemctl is-active --quiet "$DISPMGR.service"; do
            sleep "1"
        done

        return

    fi

}

function kde-clause {

    log "INFO:$DISPMGR = display-manager"

    ## Stop display manager using systemd ##
    if systemctl is-active --quiet "display-manager.service"; then
    
        grep -qsF "display-manager" "/tmp/toggle-gpu.dm"  || echo "display-manager" >/tmp/toggle-gpu.dm
        systemctl stop "display-manager.service"
    fi

        while systemctl is-active --quiet "display-manager.service"; do
                sleep 2
        done

    return

}

####################################################################################################################
## Checks to see if your running KDE. If not it will run the function to collect your display manager.            ##
## Have to specify the display manager because kde is weird and uses display-manager even though it returns sddm. ##
####################################################################################################################

if pgrep -l "plasma" | grep "plasmashell"; then
    log "INFO: Display Manager is KDE, running KDE clause!"
    kde-clause
    else
        log "INFO: Display Manager is not KDE!"
        stop_dm
fi

## Unbind EFI-Framebuffer ##
if test -e "/tmp/vfio-is-nvidia"; then
    rm -f /tmp/vfio-is-nvidia
    else
        test -e "/tmp/vfio-is-amd"
        rm -f /tmp/vfio-is-amd
fi

sleep "1"

##############################################################################################################################
## Unbind VTconsoles if currently bound (adapted and modernised from https://www.kernel.org/doc/Documentation/fb/fbcon.txt) ##
##############################################################################################################################
if test -e "/tmp/vfio-bound-consoles"; then
    rm -f /tmp/vfio-bound-consoles
fi
for (( i = 0; i < 16; i++))
do
  if test -x /sys/class/vtconsole/vtcon"${i}"; then
      if [ "$(grep -c "frame buffer" /sys/class/vtconsole/vtcon"${i}"/name)" = 1 ]; then
	       echo 0 > /sys/class/vtconsole/vtcon"${i}"/bind
           log "INFO: Unbinding Console ${i}"
           echo "$i" >> /tmp/vfio-bound-consoles
      fi
  fi
done

### ─── DEVICE BIND/UNBIND HELPERS ────────────────────────────────────────────
unbind_device() {
  local dev=$1 driver=$2
  if [[ -d "/sys/bus/pci/drivers/$driver" ]]; then
    log "INFO: Unbinding $dev from $driver"
    echo -n "$dev" | tee "/sys/bus/pci/drivers/$driver/unbind" > /dev/null
  else
    log "WARNING: No driver $driver founds at /sys/bus/pci/drivers/$driver"
  fi
}

bind_device() {
  local dev=$1 driver=$2
  if [[ -d "/sys/bus/pci/drivers/$driver" ]]; then
    log "INFO: Binding $dev to $driver"
    echo -n "$dev" | tee "/sys/bus/pci/drivers/$driver/bind" > /dev/null
  else
    log "WARNING: No driver $driver founds at /sys/bus/pci/drivers/$driver"
  fi
}

### ─── MAIN TOGGLE LOGIC ─────────────────────────────────────────────────────
case "$1" in
  unload)
    log "► Switching NVIDIA → VFIO (preparing VM passthrough)"
    # 1) Unload NVIDIA modules
    for m in "${NVIDIA_DRIVERS_UNLOAD[@]}"; do
      log "Removing module $m"; modprobe -r "$m" || true
    done

    # 2) Unbind GPU devices from their host drivers
    unbind_device "$PCI_VGA"   nvidia
    unbind_device "$PCI_AUDIO" "$AUDIO_DRIVER"

    # 3) Load VFIO modules
    for m in "${VFIO_DRIVERS_LOAD[@]}"; do
      log "Loading module $m"; modprobe "$m"
    done

    # 4) Bind GPU devices into vfio-pci
    bind_device "$PCI_VGA"   vfio-pci
    bind_device "$PCI_AUDIO" vfio-pci
    log "GPU is now owned by VFIO!"
    ;;

  load)
    log "► Reverting VFIO → NVIDIA (for host/container use)"
    # 1) Unbind from VFIO
    unbind_device "$PCI_VGA"   vfio-pci
    unbind_device "$PCI_AUDIO" vfio-pci

    # 2) Remove any VFIO ID associations (optional but clean)
    echo "10de 2b85" | tee /sys/bus/pci/drivers/vfio-pci/remove_id > /dev/null || true
    echo "10de 22e8" | tee /sys/bus/pci/drivers/vfio-pci/remove_id > /dev/null || true

    # 3) Load NVIDIA modules
    for m in "${NVIDIA_DRIVERS_LOAD[@]}"; do
      log "Loading module $m"; modprobe "$m"
    done

    # 4) Bind back into NVIDIA / audio driver
    bind_device "$PCI_VGA"   nvidia
    bind_device "$PCI_AUDIO" "$AUDIO_DRIVER"
    log "GPU is now back to NVIDIA!"
    ;;

  *)
    cat <<EOF
Usage: $0 {unload|load}

  unload   → unload NVIDIA, bind GPU to vfio-pci (for VM passthrough)
  load     → unload vfio-pci, load NVIDIA modules (for host/containers)
EOF
    exit 1
    ;;
esac

cleanup() {
## Restart Display Manager ##
input="/tmp/toggle-gpu.dm"
while read -r DISPMGR; do
  if command -v systemctl; then

    ## Make sure the variable got collected ##
    echo "$DATE Var has been collected from file: $DISPMGR"

    systemctl start "$DISPMGR.service"

  else
    if command -v sv; then
      sv start "$DISPMGR"
    fi
  fi
done < "$input"

############################################################################################################
## Rebind VT consoles (adapted and modernised from https://www.kernel.org/doc/Documentation/fb/fbcon.txt) ##
############################################################################################################

input="/tmp/vfio-bound-consoles"
while read -r consoleNumber; do
  if test -x /sys/class/vtconsole/vtcon"${consoleNumber}"; then
      if [ "$(grep -c "frame buffer" "/sys/class/vtconsole/vtcon${consoleNumber}/name")" \
           = 1 ]; then
    echo "$DATE Rebinding console ${consoleNumber}"
	  echo 1 > /sys/class/vtconsole/vtcon"${consoleNumber}"/bind
      fi
  fi
done < "$input"
}

