#!/usr/bin/env bash
# name:     NVIDIA
# summary:  Installs the newest NVIDIA driver with 32-bit Vulkan for games, loads nvidia-uvm at boot and keeps web views in apps from crashing.
# default:  on
#
# openSUSE-repos-Tumbleweed-NVIDIA adds the NVIDIA repository the way the installer does and follows its URL changes
# The signed kmp-meta package is the documented install for Turing and newer, with or without Secure Boot
#
# Source https://sndirsch.github.io/nvidia/2025/07/16/nvidia-drivers.html
# The G<N> generation is found when the task runs, so a new driver branch needs no edit here
#
# nvidia-gl-G<N>-32bit and libvulkan1-32bit give 32 bit Windows apps under Wine an NVIDIA Vulkan driver
# Without them the 32 bit Battle.net agent failed with BLZBNTBTS0000005C on 2026-05-26
#
# openSUSE's udev rule runs nvidia-modprobe without -u, so /dev/nvidia-uvm only appears once nvidia-smi or similar runs
# Until then DXVK and VKD3D-Proton fail, seen as "no DX12 support" in Dune Awakening on 2026-05-26
#
# The unit is the one openSUSE documents for this, without its docker.service line
# Source https://en.opensuse.org/SDB:NVIDIA_drivers#NVIDIA_UVM_driver_not_loaded_at_boot
#
# It is enabled without --now, because what matters is the next boot
#
# WebKitGTK's accelerated compositing hands KWin a GPU dmabuf it rejects with "Error 71 (Protocol error)"
# Its web process also segfaults in libnvidia-eglcore on exit
#
# FORCE_SHM keeps the compositing buffers in shared memory, while plain WEBKIT_DISABLE_DMABUF_RENDERER still crashes
# Skia CPU rendering keeps NVIDIA EGL out of the web process, both reproduced and checked here on 2026-07-01
#
# They are set for the whole session because apps such as Telegram write their own launchers and bypass any wrapper
# When web views say "Webview crashed" again, check systemctl --user show-environment for the WEBKIT values

ENVIRONMENT_FILE="${HOME}/.config/environment.d/95-webkitgtk-nvidia-dmabuf.conf"

uvm_unit() {
	cat <<'UNIT'
# From openSUSE SDB:NVIDIA_drivers, "NVIDIA UVM driver not loaded at boot"
# https://en.opensuse.org/SDB:NVIDIA_drivers#NVIDIA_UVM_driver_not_loaded_at_boot
[Unit]
Description=Create the NVIDIA UVM device node by calling nvidia-smi
After=nvidia-persistenced.service
Wants=nvidia-persistenced.service
ConditionPathExists=/usr/bin/nvidia-smi
ConditionPathExists=/dev/nvidia-modeset

[Service]
Type=oneshot
ExecStart=/usr/bin/nvidia-smi -L
ExecStartPost=/bin/bash -c 'test -c /dev/nvidia-uvm'
RemainAfterExit=yes
User=root
TimeoutStartSec=30
Restart=no

[Install]
WantedBy=multi-user.target
UNIT
}

task() {
	when::pci_vendor 10de "Only on machines with an NVIDIA graphics card"
	say "Add the NVIDIA driver repository"
	want::packages --no-recommends openSUSE-repos-Tumbleweed-NVIDIA
	say "Install the newest NVIDIA open driver with its 32-bit Vulkan support"
	want::newest_numbered_package nvidia-open-driver-G -signed-kmp-meta 'nvidia-gl-G{N}-32bit' libvulkan1-32bit
	want::file /etc/systemd/system/nvidia-uvm.service uvm_unit --root
	want::system_unit nvidia-uvm.service
	want::session_variable WEBKIT_DMABUF_RENDERER_FORCE_SHM 1 "${ENVIRONMENT_FILE}"
	want::session_variable WEBKIT_SKIA_ENABLE_CPU_RENDERING 1 "${ENVIRONMENT_FILE}"
	restart::if_changed "The driver and nvidia-uvm take over on the next boot, and apps with web views when started again"
}
