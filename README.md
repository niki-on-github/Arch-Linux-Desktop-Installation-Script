# Arch-Linux-Desktop-Installation-Script

My Arch Linux Desktop Installation Script. This script autoinstalls and autoconfigures a fully-functioning and minimal Arch Linux environment.

## Installer Architecture

### try commands

Each command (install, pre-commands, post-commands) is checked to see if it was completed successfully. Additionally there is a `try` command to deactivate this mechanism. If a command fails, the program prints the trace and terminates. To use the try command feature add a try at the beginning of the command for each command that may fail.

Example:

```
pacman -Rdd i3-wm
```

with try command:

```
try pacman -Rdd i3-wm
```

### default/

This folder contains templates for various minimal installations.

### pkg.csv

Structure:

| GID      | TAG                                              | PROGRAM          | PRE-COMMAND                        | POST-COMMANDS                       | COMMENT      |
| -------- | ------------------------------------------------ | ---------------- | ---------------------------------- | ----------------------------------- | ------------ |
| Group ID | **R**epo, **G**it, **P**ip, **C**md Installation | repo-name or url | pre-run-commands <br>(; separated) | post-run-commands <br>(; separated) | pkg comments |

Example:

| GID  | TAG | PROGRAM        | PRE-COMMAND                       | POST-COMMANDS                           | COMMENT                                |
| ---- | --- | -------------- | --------------------------------- | --------------------------------------- | -------------------------------------- |
| base | R   | networkmanager |                                   | systemctl enable NetworkManager.service | "Network connection manager"           |
| wm   | R   | 3-gaps         | try pacman --noconfirm -Rdd i3-wm |                                         | "A fork of i3wm tiling window manager" |
