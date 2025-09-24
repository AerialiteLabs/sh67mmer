# sh67mmer
## The smallest unenrollment exploit ever

## How to build a shim
**1.** Clone the repository with `git`, `git clone https://github.com/AerialiteLabs/sh67mmer`<br />
**2.** cd into the newly-cloned repo with `cd sh67mmer`<br />
**3.** cd into the `builder` folder<br />
**4.** Move your shim into the `builder` folder <br />
**5.** Run `sudo bash sh67mmer.sh /path/to/shim.bin`<br />
**6.** Your shim should now be less than 67MiB when done.<br />

## Credits
Aerialite Labs - Implementing KV6 Unenrollment
kxtzownsu - writing picoshim & the builder
ading2210 (vk6) - the extract_initramfs code
BinBashBanana (OlyB) - the shim shrinking code

> [!NOTE]
> ONLY WORKS ON DEVICES WITH CR67 SECURITY CHIPS!
