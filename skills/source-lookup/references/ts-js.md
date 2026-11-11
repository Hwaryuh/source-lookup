# TypeScript and JavaScript

## Pin the version and find the package

The lock file records versions, but the package that actually loads depends on where Node
resolution finds it from the importing file. Resolve from the folder of the file that imports the
package. In a monorepo this is often a workspace package, not the repository root.

```
node <skill dir>/scripts/resolve-node.js <package>
```

Run it with the importing folder as the working directory, or use
`locate.ps1 -Lang node -Package <package> -ProjectDir <folder>`. It prints the real path (pnpm
symlinks resolved), the version and the type entry point.

Do not use `require.resolve('<package>/package.json')`. It throws `ERR_PACKAGE_PATH_NOT_EXPORTED`
for packages whose `exports` map does not list `./package.json`. Do not build pnpm paths
(`node_modules/.pnpm/<name>@<version>...`) by hand either.

Yarn Plug'n'Play has no `node_modules` folder. Run `yarn unplug <package>` with the user's approval,
or read the zip archive in `.yarn/cache`.

## Signatures

`.d.ts` files are the signatures. Find them in this order:

1. The `types` condition inside `exports` in the package's `package.json`, for the entry you import.
2. The `types` or `typings` field.
3. `@types/<name>` (for `@scope/name`, use `@types/scope__name`). Its version can differ from the
   runtime package. Check both versions.

## Source

Read the package folder. If it ships only bundled output, read `dist` and prefer `.d.ts`. Source
maps (`*.map`) often contain the original source in `sourcesContent`.

## Traps

- `exports` conditions (`import`, `require`, `browser`, `node`, `default`) can point the same
  specifier at different files with different exports.
- ESM-only packages cannot be loaded with `require`, and CommonJS default exports appear as
  `default` when imported as ESM.
- Framework APIs (React, Next.js, Vite and others) change between major versions. Check the
  resolved major version before using a feature.

## Check

Run the project's type check, for example `npx tsc --noEmit`, or the `typecheck` script in
`package.json`.
