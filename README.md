Working on making a custom setup and teardown script that will detect when one of the following is running, docker container, podman pod, LXD VM or Virt-Manager VM. Then configure the appropirate GPU passthrough to said container/vm. Then restore the drivers when the container/vm is shut down. 

This is my first time stepping in to Linux so I expect this to be a lot of fun.

Working off of https://github.com/ilayna/Single-GPU-passthrough-amd-nvidia/tree/main, https://github.com/QaidVoid/Complete-Single-GPU-Passthrough, and https://docs.nvidia.com/vgpu/latest/grid-vgpu-user-guide/index.html#using-gpu-pass-through-red-hat-el-kvm.
