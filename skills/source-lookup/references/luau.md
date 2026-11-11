# Roblox Luau

Roblox does not ship engine source. The ground truth is the API dump for the Studio version in use,
then the official reference docs, then the running engine.

## Fetch the references

Run `fetch-refs.ps1` as shown in the Tools section of SKILL.md:

```
fetch-refs.ps1 -Name roblox-api-dump       # Full-API-Dump.json and version.txt
fetch-refs.ps1 -Name roblox-creator-docs   # Engine API reference as YAML, with STUDIO_VERSION
fetch-refs.ps1 -Name luau-docs             # Luau language and type system docs
```

Ask the user before the first fetch. `fetch-refs.ps1 -List` shows what is cached and when it was
fetched.

## Pin the version

Get the Studio version from the user, or run `print(version())` in Studio (for example through a
Studio MCP server, if one is connected). Compare it with `version.txt` in the API dump and with
`content/en-us/reference/engine/STUDIO_VERSION` in creator-docs. If they differ, say so. Members
added after the cached version are not in the dump yet.

## Signatures

`Full-API-Dump.json` is large (several MB). Search it; never read it whole.

- The top level has `Classes`, `Enums` and `Version`.
- Each class has `Name`, `Superclass` and `Members`. Inherited members are listed on the
  superclass, so walk the `Superclass` chain.
- Each member has `MemberType` (Property, Function, Event, Callback), `Name`, `Security`, `Tags`
  and `ThreadSafety`. Properties also have `ValueType`, `Category` and `Default`. Functions and
  events have their parameter and return types.
- `Tags` (when present) contains values such as `Deprecated`, `NotScriptable`, `ReadOnly`,
  `Hidden` and `NotReplicated`. A member with `Deprecated` still exists but must not be used in
  new code.
- `Security` is a string for functions and events, and an object with `Read` and `Write` for
  properties. Any value other than `None` (for example `PluginSecurity`) means a normal game script
  cannot use that access.
- `Enums` lists enum items and their values.

## Docs

creator-docs: `content/en-us/reference/engine/{classes,datatypes,enums,globals,libraries}/<Name>.yaml`.
These files hold descriptions, deprecation messages and code samples.

Luau language: `src/content/docs/` in luau-docs. Type system details are in `types/`, and the
standard library is in `reference/library.md`.

## Packages

Wally packages are in `Packages/` (the real sources are under `_Index`). Rojo maps files to
instances in `default.project.json`.

## Runtime

The dump says what exists, not exactly how it behaves. Check behaviour in a play test or through a
Studio MCP server. Some APIs work only on the server or only on the client.

## Traps

- Deprecated members remain in the dump and in old tutorials.
- The new type solver and the old one accept different code.
- A `NotScriptable` property cannot be read or written from a script, even though it is listed.

## Check

Run `luau-lsp`, `selene` or `luau-analyze` if the project uses them. Otherwise test in Studio.
