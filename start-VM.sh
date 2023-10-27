#!/bin/bash

qemu-system-x86_64 \
  -enable-kvm \
  -m 4G \
  -smp cores=2,threads=2 \
  -hda $1 \
  -nographic -vnc :0,share=ignore \
  -net user,hostfwd=tcp::1022-:22 -net nic
