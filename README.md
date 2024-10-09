# PicoShim
The smallest shim ever (that boots while still being signed)
<br>
# Overview
PicoShim is a shim made for complete minimalism. 

It is the smallest shim thats able to be made (as of 10/9/24) without modifying the kernel partition

# Build instructions
Run these commands in a **LINUX** terminal, WSL is not guaranteed to work and will not recieve support.
```
git clone https://github.com/kxtzownsu/PicoShim
cd PicoShim/builder
sudo bash builder.sh /path/to/raw-shim.bin
```
Now flash `/path/to/raw-shim.bin` to a USB and boot it in Developer Mode Recovery (dev=1 reco=1)

# Credits
kxtzownsu - writing picoshim builder

olyb - shim shrinking code

vk6 - initramfs extraction code
