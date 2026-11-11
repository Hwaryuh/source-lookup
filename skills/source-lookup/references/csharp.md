# C# and .NET

## Pin the version

After a restore, `obj/project.assets.json` of each project holds the exact resolved graph:

- `libraries` keys are `<PackageId>/<Version>`.
- `packageFolders` holds the NuGet package root.

`locate.ps1 -Lang dotnet -Package <id>` reads these files. If there is no `project.assets.json`,
run `dotnet restore` first. `dotnet list package --include-transitive` gives the same versions
in a slower way.

## Find the files

- Package root: `dotnet nuget locals global-packages --list`. It is `~/.nuget/packages` unless
  `NUGET_PACKAGES` or the NuGet config changes it.
- Package folder: `<root>/<package id in lower case>/<version>/`.
- Assemblies: `lib/<tfm>/` and reference assemblies in `ref/<tfm>/`. Pick the TFM folder closest to
  the project's `TargetFramework`.

## Signatures

Read `<Assembly>.xml` next to the DLL in the TFM folder. It holds the documented members and their
summaries.

Base class library: the reference packs are in `<dotnet root>/packs/Microsoft.NETCore.App.Ref/<version>/ref/<tfm>/`,
with XML docs. Find `<dotnet root>` with `dotnet --list-sdks`.

## No source

Most packages ship only compiled assemblies. Decompile with ILSpy:

1. Find it with `decompiler.ps1 -Tool ilspycmd`. If it is missing, ask the user before running
   `dotnet tool install -g ilspycmd`.
2. Decompile only the type you need. `ilspycmd --help` shows the option that limits output to one
   type.
3. Write the output to the cache and reuse it.

Windows Runtime metadata (`.winmd`, for example from the Windows App SDK) can be opened the same way.

## Traps

- APIs gated by TFM (`#if NET8_0_OR_GREATER`) or by platform (`[SupportedOSPlatform]`).
- WinUI 3 (`Microsoft.UI.Xaml`) and WPF (`System.Windows`) have similar names but are separate APIs.
- Preview package versions change APIs without notice.

## Check

`dotnet build` for the project or solution you changed.
