# 🖥️ KDE Plasma Installation on Arch Linux

Follow these steps to install and run **KDE Plasma** with a **Wayland session** on Arch Linux. This guide assumes `sudo` privileges and a clean system.

---

## Full System Update

```
sudo pacman -Syu

```

## installing desktop env

```
sudo pacman -S plasma

note: put everything to default

```

```bash
# you need a login manager:

nano /kde_plasma.sh

#!/bin/bash
/usr/lib/plasma-dbus-run-session-if-needed /usr/bin/startplasma-wayland

# make it executable
chmod +x kde_plasma.sh
```
