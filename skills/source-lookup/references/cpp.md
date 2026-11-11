# C++

C++ has no single package manager. The include paths of the build decide which headers are used.

## Find the build

1. Find the build folder the user builds with: `build/`, `out/build/<preset>/` or `cmake-build-*`.
   If there are several, ask which one.
2. Read `compile_commands.json` in that folder. If it is missing, the user can configure with
   `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`. The `-I` and `-isystem` flags (or `/I` for MSVC) of the
   file you edit list the real include folders.

## Pin the version and find the source

- **FetchContent**: the `GIT_TAG` in `CMakeLists.txt`. The source is in `<build>/_deps/<name>-src/`,
  with the name in lower case (`FetchContent_Declare(JUCE ...)` gives `_deps/juce-src`).
  `git -C <build>/_deps/<name>-src describe --tags` confirms what was checked out.
- **CPM.cmake**: like FetchContent. With `CPM_SOURCE_CACHE` set, the source is in that cache.
- **vcpkg** in manifest mode: `vcpkg.json` and the baseline in `vcpkg-configuration.json`. Headers are in
  `<build>/vcpkg_installed/<triplet>/include` or `vcpkg_installed/` next to the manifest.
- **Conan 2**: `~/.conan2/p/`. `conan list` shows the packages.
- **Git submodules**: `git submodule status`.

## Signatures

Headers are the signatures. Templates and inline functions also have their implementation in the
header. For framework modules (for example JUCE `modules/juce_*/`), start at the module header and
follow its includes.

Standard library: the toolchain's own headers. Find them in the include paths of
`compile_commands.json`: the MSVC `include` folder, libstdc++ or libc++.

## Traps

- **Conditional compilation.** An API can exist only when a macro is set (`#if <LIB>_...`). Check
  the definitions in `compile_commands.json`.
- **Language standard.** The `-std=` or `/std:` flag decides which standard library features exist.
- **Two build folders with different dependency versions.** Use the one the user builds.
- **Deprecation.** `[[deprecated]]` or library macros mark it, and only the header shows it.

## Check

`cmake --build <build folder> --target <target>`.
