# KrumpyOS Installer Architecture

The long-term release medium is a bootable ISO containing a live/recovery
environment and a TUI installer. This is intentionally later than the
filesystem, permissions, `kinit`, and `kpkg` milestones it depends on.

## Installer goals

- install a verified base system
- support guided and manual disk layouts
- create normal users and configure root policy
- select package-based system profiles
- configure the default `kinit` target
- install and verify a bootloader
- recover cleanly from interrupted installation

## Installation profiles

The installer selects package groups, not separate OS forks:

| Profile | Purpose | Default target |
| --- | --- | --- |
| `minimal` | recovery, embedded, or custom systems | `minimal.target` |
| `server` | headless services | `server.target` |
| `developer` | K development and source builds | `multi-user.target` |
| `full` / `desktop` | graphical workstation | `graphical.target` |

A user may add or remove profiles later with `kpkg`.

## TUI flow

1. Select locale and keyboard layout.
2. Select installation profile.
3. Select target disk.
4. Choose guided or manual partitioning.
5. Select filesystem and optional encryption.
6. Configure hostname and networking.
7. Choose whether direct root login is disabled or explicitly enabled.
8. Create at least one normal administrative user.
9. Review package groups and repository trust keys.
10. Stage and verify the base system.
11. Install packages and write configuration atomically.
12. Install and verify the bootloader.
13. Validate the installed system and offer reboot.

Destructive disk operations require a clear final confirmation showing the
resolved device and layout.

## Accounts and permissions

The secure default is:

- root exists as UID 0
- direct root login is locked unless deliberately enabled
- the user creates a normal account
- administrative elevation uses a documented capability or elevation tool
- service accounts are created only by trusted packages that declare them

Passwords are stored only through a reviewed password-hashing scheme with
per-user salts and upgradeable parameters. Installation logs must not contain
passwords, recovery secrets, private keys, or package credentials.

## Package and trust model

The ISO contains a signed base package set and trusted release keys. Optional
network repositories are configured only after explicit confirmation. The
installer records exact package versions and hashes so the installed system
can be audited or reproduced.

The base install is staged before switching the target filesystem into its
bootable state. Failure must leave either the prior installation or a
diagnosable incomplete staging area, never a false success state.

## Release progression

1. raw developer disk image for QEMU
2. bootable developer ISO with recovery console
3. read-only live environment
4. offline TUI installer using bundled packages
5. network-aware installer using trusted `kpkg` repositories
6. graphical/full profile after the graphics and desktop stack is stable

