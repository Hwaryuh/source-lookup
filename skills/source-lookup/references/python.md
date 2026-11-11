# Python

## Use the project's interpreter

Use the interpreter the project runs with, not a global `python`:

- `.venv/Scripts/python.exe` (Windows) or `.venv/bin/python`
- `uv run python`, `poetry run python`, `pipenv run python`
- the interpreter configured in the project instructions

## Pin the version and find the package

```
<python> <skill dir>/scripts/resolve-python.py <name>
```

`locate.ps1 -Lang python -Package <name>` finds the interpreter and runs the same script. It accepts
an import name or a distribution name and prints both, the version and the source location. It finds
the module without importing it, so no package code runs.

The import name and the distribution name can differ, for example `yaml` and `PyYAML`, or `PIL`
and `Pillow`.

## Signatures

1. `.pyi` stubs next to the module, or in a `<name>-stubs` distribution.
2. The source itself. Most packages are plain Python.
3. For C extensions, use stubs or `inspect.signature` at runtime:
   `<python> -c "import inspect, mod; print(inspect.signature(mod.func))"`. Builtins may have no
   signature.

## Traps

- Namespace packages have no `__init__.py` and no single file. The script prints every search path.
- Editable installs point to another project's source folder. That folder is the real source.
- Modules can create attributes dynamically with `__getattr__`. A search for the name may find nothing.
- APIs can be gated on the Python version (`sys.version_info`). Check the interpreter's version.

## Check

Run the type checker or tests configured in the project (pyright, mypy, pytest).
`<python> -m py_compile <file>` proves only that the syntax is valid.
