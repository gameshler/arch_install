# Arch Linux Setup Guide

## Applications and Packages to Install

```bash
sudo pacman -S firefox libreoffice-fresh vlc curl flatpak fastfetch p7zip unrar tar rsync exfat-utils fuse-exfat flac jdk-openjdk gimp steam vulkan-radeon lib32-vulkan-radeon base-devel kate mangohud lib32-mangohud corectrl openssh dolphin telegram-desktop discord visual-studio-code-bin --needed --noconfirm
```

### yay installation:

> `mkdir opt` if you dont have it 
```
cd /opt 
git clone https://aur.archlinux.org/yay-bin.git
sudo chown -R "$USER": ./yay-bin
cd yay-bin
makepkg --noconfirm -si
```

```
yay -S postman-bin brave-bin
```

### configuring pacman:

```
sudo nano /etc/pacman.conf 
```

- remove # from:
  - Color 
  - ParallelDownloadds 
- Add the following line for visual pacman 
```
ILoveCandy 
```
Update the config:

```
sudo pacman -Sy 
```

#### enabling multilib:

uncomment the following lines:

```
[multilib]
Include = /etc/pacman.d/mirrorlist

```

Then update:

```
sudo pacman -Syyu
```

### corectrl (optional): 
More info: [corectrl Wiki](https://gitlab.com/corectrl/corectrl/-/wikis/Setup)

Enable corectrl at startup:

```
cp /usr/share/applications/org.corectrl.CoreCtrl.desktop ~/.config/autostart/org.corectrl.CoreCtrl.desktop
```

> note: if the command above isnt working you need to make a new file for auto starting: 

```
mkdir ~/.config/autostart # then run the above command 
```

### mangohud configuration:

```
cp /usr/share/doc/mangohud/MangoHud.conf.example ~/.config/MangoHud/MangoHud.conf

```
> Edit ~/.config/MangoHud/MangoHud.conf to suit your preferences.

### Nodejs 

I use nvm to manage the installed versions of Node.js on my machine. This allows me to easily switch between Node.js versions depending on the project I'm working in.

See installation instructions [here](https://github.com/nvm-sh/nvm#installing-and-updating).

OR run this command (make sure v0.40.3 is still the latest)

```
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
```

Now that nvm is installed, you can install a specific version of node.js and use it:

```
nvm install 22
nvm use 22
node --version
```
### Github SSH Setup

- Follow [this guide](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent) to setup an ssh key for github
- Follow [this guide](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account) to add the ssh key to your github account

### Global Modules 

There are a few global node modules I use a lot:
> install in your development directory 

- license
  - Auto generate open source license files
- gitignore
  - Auto generate `.gitignore` files base on the current project type

```
pnpm install -g license gitignore
```
