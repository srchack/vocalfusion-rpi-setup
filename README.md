# xCORE VocalFusion Raspberry Pi Setup for codama

This repository is fork from https://github.com/xmos/vocalfusion-rpi-setup
Add Custom for codama board. codama is http://codama.ux-xu.com

This repository provides a simple-to-use automated script to configure the Raspberry Pi to use **xCORE VocalFusion** for audio.

**Note:** This repository is designed for use within the following **xCORE VocalFusion** repositories:
- xCORE VocalFusion Stereo 4-Mic Kit for AVS: https://github.com/xmos/vocalfusion-stereo-avs-setup
- xCORE VocalFusion 4-Mic Kit for AVS: https://github.com/xmos/vocalfusion-avs-setup


## Setup

1. Install **Raspbian Stretch** or **Raspbian Buster** on the Raspberry Pi.

2. Update kernel package version.

   ```
   sudo apt-get update
   sudo apt-get upgrade
   ```

   followed by a reboot.

3. Clone the Github repository https://github.com/srchack/vocalfusion-rpi-setup:

   ```git clone https://github.com/srchack/vocalfusion-rpi-setup```

4. For codama device, run the installation script as follows:

   ```./setup.sh codama```

   For VocalFusion devices, run the installation script as follows:

   ```./setup.sh vocalfusion```

   For VocalFusion Stereo devices, run the installation script as follows:

   ```./setup.sh```

   For XVF3510 devices, run the installation script as follows:

   ```./setup.sh xvf3510```

   Wait for the script to complete the installation. This can take several minutes.

5. Reboot the Raspberry Pi.
