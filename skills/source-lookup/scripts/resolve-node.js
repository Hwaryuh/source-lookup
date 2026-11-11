'use strict';
// Finds an npm package the way Node resolution does from the current directory,
// without going through the package's "exports" map, and prints JSON.
// Usage: node resolve-node.js <package>

const fs = require('fs');
const path = require('path');
const { createRequire } = require('module');

const name = process.argv[2];
if (!name) {
  console.error('usage: node resolve-node.js <package>');
  process.exit(64);
}

const localRequire = createRequire(path.join(process.cwd(), '__source_lookup__.js'));
const searchDirs = localRequire.resolve.paths(name) || [];

function findPackageDir(pkg) {
  for (const dir of searchDirs) {
    const manifest = path.join(dir, pkg, 'package.json');
    if (fs.existsSync(manifest)) return fs.realpathSync(path.dirname(manifest));
  }
  return null;
}

function readManifest(dir) {
  return JSON.parse(fs.readFileSync(path.join(dir, 'package.json'), 'utf8'));
}

// First "types" condition reachable from an exports entry.
function typesFromExports(node) {
  if (!node || typeof node !== 'object') return null;
  if (Array.isArray(node)) {
    for (const item of node) {
      const found = typesFromExports(item);
      if (found) return found;
    }
    return null;
  }
  if (typeof node.types === 'string') return node.types;
  for (const value of Object.values(node)) {
    const found = typesFromExports(value);
    if (found) return found;
  }
  return null;
}

function typesEntry(manifest) {
  const exp = manifest.exports;
  if (exp && typeof exp === 'object' && !Array.isArray(exp)) {
    const hasSubpaths = Object.keys(exp).some((key) => key.startsWith('.'));
    const rootEntry = hasSubpaths ? exp['.'] : exp;
    const found = typesFromExports(rootEntry);
    if (found) return found;
  }
  return manifest.types || manifest.typings || null;
}

function typesPackageName(pkg) {
  if (pkg.startsWith('@types/')) return null;
  return '@types/' + (pkg.startsWith('@') ? pkg.slice(1).replace('/', '__') : pkg);
}

const dir = findPackageDir(name);
if (!dir) {
  console.log(JSON.stringify({ name, found: false, searched: searchDirs }));
  process.exit(1);
}

const manifest = readManifest(dir);
const result = {
  name,
  found: true,
  version: manifest.version || null,
  dir,
  types: typesEntry(manifest),
  typesPackage: null,
};

const typesName = typesPackageName(name);
const typesDir = typesName ? findPackageDir(typesName) : null;
if (typesDir) {
  const typesManifest = readManifest(typesDir);
  result.typesPackage = { name: typesName, version: typesManifest.version || null, dir: typesDir };
}

console.log(JSON.stringify(result));
