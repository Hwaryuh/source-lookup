# Source Lookup

A Claude Code plugin with one skill, `source-lookup`. When code calls an external library, SDK
or engine API, it makes Claude check that API against the locally resolved source of the exact
version the project uses, instead of answering from memory.

Supported ecosystems: Java and Kotlin, Rust, TypeScript and JavaScript, Python, C#, Roblox Luau,
C++ and Swift.

## Install

```
claude plugin install source-lookup --marketplace Hwaryuh/source-lookup
```

Or inside a session: `/plugin marketplace add Hwaryuh/source-lookup`, then
`/plugin install source-lookup@source-lookup`.

Requirements:

- PowerShell for the helper scripts: Windows PowerShell 5.1 (built into Windows) or PowerShell 7
  (`pwsh`) on macOS and Linux. The skill also works without the scripts: every language file
  lists the manual commands.
- `git` for `fetch-refs.ps1`.
- The toolchain of the ecosystem you work in (`cargo`, `node`, `python`, `dotnet`, `java`, `swift`).

## How it works

The skill (`skills/source-lookup/SKILL.md`) sets when Claude must look up an API, in which order it
reads sources (signature, then implementation, then decompiled code), and how it labels claims:
`verified` with a `path:line`, or `inferred`. The labels follow the language of the answer, or the
project's own labels when the project defines them.

Each ecosystem has a file in `skills/source-lookup/references/`. It covers how to pin the resolved
version, where the source is, how to read signatures, what to do when no source exists, and common
traps. Claude reads only the file for the ecosystem in front of it.

Scripts in `skills/source-lookup/scripts/`:

| Script | What it does |
| --- | --- |
| `locate.ps1` | Prints the resolved version and source folder of a dependency (Java, Rust, Node, Python, .NET). Read-only. Lists every candidate instead of guessing. |
| `fetch-refs.ps1` | Fetches reference data that package managers do not download, such as the Roblox API dump and Engine API reference, Luau docs, Rust release notes and Swift Foundation sources. |
| `decompiler.ps1` | Finds Vineflower or ilspycmd. It can download Vineflower into the cache. It never installs global tools. |
| `gradle-sources.init.gradle` | Downloads `-sources.jar` files into the Gradle cache without changing project files. |

Fetched data is stored in `$SOURCE_LOOKUP_HOME`. When the variable is not set, it is
`%LOCALAPPDATA%\source-lookup` on Windows and `~/.cache/source-lookup` elsewhere. Keep it outside
your projects. Each fetched
reference records its commit, fetch time and version in `.source-lookup.json`.

Project instructions that point to their own reference sources take precedence over the skill.

## Develop

```
claude plugin validate .
```

## License

MIT
