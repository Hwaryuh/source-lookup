---
name: source-lookup
description: Use when code calls an external dependency's API, or when an error or feature depends on a dependency's version.
---

# Source lookup

Check external APIs against the source of the version the project actually resolves, not against
memory. Memory of a library blends every version it has seen. The local source is the one that
compiles.

## When to look

Look up **before** writing or changing the call when any of these is true:

- This repository has not used the API yet (type, function, member, config key, attribute).
- The repository uses it, but the dependency version changed, or the call shape or the receiver
  type is different.
- A compile or runtime error names an external type or member.
- The task depends on a specific version, a deprecation or a recently added feature.

Skip the lookup only for core language syntax, long-stable standard library APIs, and an API this
repository already uses the same way at the same version.

Feeling sure is not one of the skip conditions. Confident recall is how wrong APIs get written.

## Procedure

1. **Pin the version** with the ecosystem's own resolver. The language file says how. If the lock
   file and the manifest disagree, report it.
2. **Find the source** for that exact version. `scripts/locate.ps1` helps. The resolver commands
   in the language file are the final word. If more than one candidate matches, pick by the
   resolved dependency graph or ask. Do not guess.
3. **Read the cheapest thing first**: a signature (javap, `.d.ts`, `.pyi`, header, XML doc,
   API dump), then the implementation. Decompile only when no source exists.
4. A declaration proves the signature, not the behaviour. For behaviour, read the body or run it.

| Ecosystem | Language file |
| --- | --- |
| Java, Kotlin (Gradle, Maven) | `references/java-kotlin.md` |
| Rust (Cargo) | `references/rust.md` |
| TypeScript, JavaScript (npm, pnpm, Yarn) | `references/ts-js.md` |
| Python | `references/python.md` |
| C# (.NET, NuGet) | `references/csharp.md` |
| Roblox Luau | `references/luau.md` |
| C++ (CMake, vcpkg, FetchContent) | `references/cpp.md` |
| Swift (SwiftPM) | `references/swift.md` |

Read only the file for the ecosystem in front of you.

## Evidence labels

Rules in this skill use the meaning. Output uses the label.

| Meaning | When | ko | en | ja | zh |
| --- | --- | --- | --- | --- | --- |
| `verified` | Checked in local source. Add `path:line`. | [소스] | [source] | [ソース] | [源码] |
| `inferred` | Not checked. | [추론] | [inferred] | [推論] | [推断] |

1. If the project instructions define their own labels, use those.
2. Otherwise use the column of the language you are answering in.
3. For any other language, use `en`.
4. `path:line` is the same in every language.

## Never

- Read a version folder other than the resolved one.
- Search the web before checking local source.
- Decompile the same artifact again for each question. Keep the output and reuse it.
- Edit anything inside a package cache.
- Read a large file whole. Search for the symbol, then read around the line.

## When the source is not there

Say so, label the claim `inferred`, and give the command that would fetch it. Download into a
cache only with the user's approval. Never install a global tool without asking.

## Build check

If the project instructions name a check command, run it after the change. Otherwise suggest the
language file's check command only when it fits this project. When an error names an external type,
open that type's source.

## Project overrides

Reference paths in the project instructions (for example a checked-out engine source tree) take
precedence over this skill.

## Tools

The scripts are in this skill's base directory. Run them with
`powershell -NoProfile -ExecutionPolicy Bypass -File <skill dir>/scripts/<name>.ps1` on Windows,
or `pwsh -File ...` elsewhere.

| Script | Use |
| --- | --- |
| `locate.ps1 -Package <name> [-Lang <lang>] [-ProjectDir <dir>] [-Version <v>]` | Prints the resolved version and source folder. Supports java, rust, node, python and dotnet. For other ecosystems, it points to the language file. |
| `fetch-refs.ps1 -List` / `-Name <ref> [-Ref <tag>]` | Fetches reference data that package managers do not download (`refs.json`). |
| `decompiler.ps1 -Tool vineflower\|ilspycmd [-Fetch]` | Finds an installed decompiler. With `-Fetch`, downloads Vineflower into the cache. It never installs ilspycmd. |
| `gradle-sources.init.gradle` | Gradle init script that downloads `-sources.jar` files. See `references/java-kotlin.md`. |

The cache is `$SOURCE_LOOKUP_HOME`. When it is not set, the cache is
`%LOCALAPPDATA%\source-lookup` on Windows and `~/.cache/source-lookup` elsewhere. Never point it
inside a project.

## Red flags

Stop and look up the source when you catch yourself thinking any of these:

- "I know this API well."
- "The older version had it, so this one does too."
- "The docs online say so." (You have not checked local source yet.)
- "I'll write the call now and check it if the build fails."
