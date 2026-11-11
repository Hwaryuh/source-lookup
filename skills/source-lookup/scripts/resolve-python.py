"""Find an installed Python package without importing it, and print JSON.

Usage: python resolve-python.py <import name or distribution name>
Accepts an import name (yaml) or a distribution name (PyYAML).
"""

import importlib.metadata as metadata
import importlib.util
import json
import sys


def import_to_dists():
    try:
        return metadata.packages_distributions()
    except AttributeError:  # Python < 3.10
        return {}


def modules_of_distribution(name):
    """Top-level modules of an installed distribution, or None if it is not installed."""
    try:
        dist = metadata.distribution(name)
    except metadata.PackageNotFoundError:
        return None
    top_level = dist.read_text("top_level.txt")
    if top_level:
        return [line.strip() for line in top_level.splitlines() if line.strip()]
    found = set()
    for path in dist.files or []:
        first = path.parts[0] if path.parts else ""
        if not first or first.endswith((".dist-info", ".egg-info", ".data")) or first == "..":
            continue
        if len(path.parts) == 1:
            if first.endswith(".py"):
                found.add(first[:-3])
        else:
            found.add(first)
    return sorted(found)


def module_location(module):
    try:
        spec = importlib.util.find_spec(module)
    except (ImportError, ValueError):
        return None
    if spec is None:
        return None
    locations = list(spec.submodule_search_locations or [])
    return {"name": module, "origin": spec.origin, "searchLocations": locations}


def main():
    if len(sys.argv) != 2:
        print("usage: python resolve-python.py <name>", file=sys.stderr)
        return 64
    query = sys.argv[1]
    top_level = query.split(".")[0]
    mapping = import_to_dists()

    modules = []
    dists = []
    if top_level in mapping:
        modules.append(top_level)
        dists.extend(mapping[top_level])
    else:
        wanted = query.lower().replace("_", "-")
        for module, owners in mapping.items():
            if any(owner.lower().replace("_", "-") == wanted for owner in owners):
                modules.append(module)
                dists.extend(owners)
        if not modules:
            dist_modules = modules_of_distribution(query)
            if dist_modules is None:
                modules.append(top_level)
            else:
                modules.extend(dist_modules)
                dists.append(query)

    result = {
        "query": query,
        "python": sys.executable,
        "pythonVersion": "%d.%d.%d" % sys.version_info[:3],
        "distributions": [],
        "modules": [],
    }
    for dist in sorted(set(dists)):
        try:
            result["distributions"].append({"name": dist, "version": metadata.version(dist)})
        except metadata.PackageNotFoundError:
            pass
    for module in sorted(set(modules)):
        location = module_location(module)
        if location is not None:
            result["modules"].append(location)

    result["found"] = bool(result["modules"])
    print(json.dumps(result))
    return 0 if result["found"] else 1


if __name__ == "__main__":
    sys.exit(main())
