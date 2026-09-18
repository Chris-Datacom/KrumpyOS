# KrumpyOS Userland and Packages

KrumpyOS is intended to become a self-hosting K development system. The base
system remains small; optional applications and services are distributed by
`kpkg` from configured repositories.

## Bundled userland

The development/full system is expected to include:

- K runtime and standard library
- K compiler and build tools
- shell and terminal interface
- Vim-inspired modal editor
- `man`-style documentation viewer
- small GNU-inspired utilities such as `ls`, `cat`, `cp`, `mv`, `rm`,
  `mkdir`, `head`, `tail`, and text search
- `kpkg`

“GNU-inspired” means familiar, composable command-line behavior, not automatic
GNU, Unix, or POSIX compatibility. KrumpyOS interfaces and compatibility
promises must be documented explicitly.

## Package profiles

Profiles are versioned package groups:

- `minimal`: boot, init, recovery shell, filesystem tools, and `kpkg`
- `server`: minimal plus networking, service management, remote
  administration, and logging
- `developer`: minimal/server foundation plus K compiler, standard library,
  editor, manuals, debugger, and build tools
- `full` or `desktop`: developer tools plus graphics, terminal emulator,
  desktop environment, and selected applications

The exact inclusion of the compiler in minimal/server installations remains a
policy decision. It must always be installable through `kpkg` when compatible.

## `kpkg` responsibilities

`kpkg` owns:

- repository configuration and trust keys
- package search and metadata
- version and dependency resolution
- target and ABI compatibility checks
- lockfiles with exact source revisions and dependency artifacts
- signed/checksummed artifact verification
- explicit source fetching and builds
- transactional installation, removal, upgrade, and rollback
- the installed-package database

The K compiler only compiles local inputs. It does not fetch packages or write
directly into protected system locations.

## Binary and source installation

Default installation chooses a trusted compatible artifact:

```text
kpkg install editor
```

An explicit source build fetches the locked Git revision and compiles it in a
restricted staging environment:

```text
kpkg install editor --source
```

If no trusted binary exists, `kpkg` reports that fact and requires explicit
approval for a source build. It must not silently execute remote build logic.

## Repository layout

The project Git server may host:

- an official package-index repository
- independent source repositories
- signed release artifacts
- source tags and immutable commit IDs
- package and API documentation

The index maps package/version/target tuples to metadata, artifacts, source
commits, checksums, signatures, dependencies, and required KrumpyOS ABI
versions. Cloning from the server is transport; configured keys and hashes
establish trust.

Core, official optional, and community repositories are distinct trust
classes. Adding a community repository requires visible user approval.

## Permissions and build isolation

- System-wide installation requires root or a package-management capability.
- User-scoped packages may install only below user-owned locations.
- Package builds run as an unprivileged build identity in a staging directory.
- Network access during builds is denied by default; inputs are fetched and
  locked before compilation.
- Installation occurs only after verification and successful build completion.
- Package scripts receive declared filesystem, device, IPC, and network
  permissions rather than unrestricted root access.

## Dependency order

`kpkg` network repositories depend on stable processes, filesystems,
permissions, executable loading, networking, TLS, and time validation. A local
package format and offline installer can be developed earlier, but remote
installation is not complete until its trust and transport requirements are
met.

