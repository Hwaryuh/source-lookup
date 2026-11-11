# Swift

First run `swift --version` to get the toolchain version and target triple. What can be checked
locally depends on the API layer:

| Layer | Local check | How |
| --- | --- | --- |
| SwiftPM packages | yes | `Package.resolved`, then `.build/checkouts/` |
| Standard library, Foundation | yes, for this platform | `swift-synthesize-interface`, Foundation sources |
| Platform modules (WinSDK, Glibc, WinRT bindings) | yes | SDK modules and package sources |
| Apple-only frameworks (SwiftUI, AppKit, UIKit, Combine and others) | only on macOS | SDK `.swiftinterface` files |

## SwiftPM packages

- Version: `Package.resolved` holds `pins[]` with `identity`, `location` and `state.version` or
  `state.revision`.
- Source: `.build/checkouts/<repo>/` after `swift package resolve`. Xcode projects keep checkouts
  under DerivedData in `SourcePackages/checkouts/`.

## Standard library and Foundation

Generate the interface of a compiled module and search it:

```
swift-synthesize-interface -module-name <Module> -target <triple> -sdk <sdk path> -o <cache>/<Module>.swift
```

- On Windows, the SDK is `<Swift install>/Platforms/<version>/Windows.platform/Developer/SDKs/Windows.sdk`.
  `Foundation` and `FoundationEssentials` are there.
- On macOS, the SDK path is `xcrun --show-sdk-path`.

For Foundation implementation source, fetch the tag that matches the toolchain. Run
`fetch-refs.ps1` as shown in the Tools section of SKILL.md:

```
fetch-refs.ps1 -Name swift-foundation -Ref swift-<version>-RELEASE
fetch-refs.ps1 -Name swift-corelibs-foundation -Ref swift-<version>-RELEASE
```

## Apple frameworks

Off macOS, these SDKs are not available. Label every claim about SwiftUI, AppKit, UIKit, Combine
and other Apple-only frameworks `inferred`. Apple's online documentation is the only secondary
source, and it describes the latest SDK, not a specific one.

On macOS, use `swift-synthesize-interface` with the macOS or iOS SDK, or read the `.swiftinterface`
files inside the SDK.

## Foundation is not the same on every platform

On Windows and Linux, Foundation is a separate implementation (`swift-foundation` and
`swift-corelibs-foundation`). Some APIs are missing there, and some behave differently. If the code
targets Apple platforms, a Foundation API checked on Windows or Linux is still `inferred`.

## Traps

- `@available` and `#if canImport(...)` hide APIs on some platforms and OS versions.
- Swift 6 language mode enforces strict concurrency checking. Code valid in Swift 5 mode can fail.

## Check

`swift build` for SwiftPM packages. Apple-only code cannot be built off macOS.
