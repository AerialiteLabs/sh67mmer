# PicoShim
## The smallest shim to ever come out (so far)

### THIS REQUIRES A USB AND BASIC INSTRUCTION FOLLOWING SKILLS

## How to use this
**1.** Find your board, this can be done by going to `chrome://version` and then looking for the "Platform" entry. <br />
    **1a.** Once found, look at the **last** word in the line, that is your board.<br />
**2.** Download a shim at https://dl.kxtz.dev/ChromeOS/shims/PicoShim<br />
     **2a.** Shims are in the `<boardname>.zip` format<br />
**3.** Open the Chrome Recovery Utility (or flasher of your choice) and open the file, and then select your USB.<br />
**4.** Once the image is done flashing, remove all external media (CD, USB, SD) and press ESC+REFRESH+PWR<br />
**5.** Insert your newly-flashed USB <br />
**6.** enjoy the smallest shim thats bootable with MP keys as of 9/11/24<br />


## How to compile a shim
**1.** Clone the repository with `git`, `git clone https://git.kxtz.dev/PicoShim`<br />
    **1a.** If git.kxtz.dev is down, you can use <https://github.com/kxtzownsu/PicoShim><br />
**2.** cd into the newly-cloned repo with `cd PicoShim`<br />
**3.** cd into the `builder` folder<br />
**4.** Move your shim into the `builder` folder <br />
**5.** Run `sudo bash picobuilder.sh /path/to/shim.bin`<br />
**6.** Your shim should now be less than 50MiB when done.<br />

## GitHub
https://github.com/kxtzownsu/PicoShim

## Credits
kxtzownsu - writing picoshim & the builder

ading2210 (vk6) - the extract_initramfs code

BinBashBanana (Olyb) - the shim shrinking code
