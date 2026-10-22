# Experimental Arch updater

Source preserved from the Caelestia ES implementation. This directory is not loaded by the upstream shell.

The implementation previews repository/AUR upgrades, identifies installed application icons, streams package-manager output, and accepts interactive replies. Privileged operations invoke `pkexec`; passwords are entered through the existing desktop polkit agent, never through the log input.

Requirements: Arch Linux, Python 3, pacman, pacman-contrib/checkupdates, paru, pkexec, and an active polkit agent. No new polkit policy is installed. The backend preserves package-manager confirmations and AUR review. The UI labels in this prototype are Spanish.

Known limits:

- The update process is owned by Quickshell. Closing the settings page is supported; restarting Quickshell during an update is not.
- A displayed percentage belongs to the current package-manager operation, not the whole upgrade.
- Only the most recent 60,000 log characters stay in memory.
- Configuration-file conflicts and unusual AUR build prompts need further testing.
- Self-updates can change the shell/plugin ABI. Do not restart the shell automatically after an upgrade.

Before integration, port the page to native translations, check behavior under network/authentication/build failures, and test process recovery independently from the shell lifetime.
