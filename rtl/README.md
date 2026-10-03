Structure
---------------

All modules have the following structure.
Try to follow it.

```            
nameOfModule
│       ├── doc
│       │   ├── digram.dwg
│       │   └── nameModule.md
│       ├── hdl
│       │   └── name\_top.sv
│       │   └── submodules.sv
│       ├── includes
│       └── tb
│           └── Makefile
│           └── Questa
│               └── files
│           └── Verilator
│               └── files
│           └── SBY
│               └── files
```            
Original folder
---------------

The original folder is just as reference, not a submodules, and it will be
removed at release. It does contain all the original code of lagarto but with
the spyglass warnings solved.

Data cache
----------

The `dcache` directory and its `rtl/memory_library` dependency are vendored
snapshots tracked directly by this repository, not Git submodules. No submodule
initialization is needed for these directories.

The snapshots originate from `https://github.com/bsc-loca/cv-hpdcache.git`
at commit `39fc2914a2f35aa0bb6fe3fcd45db54204aa99ac` and its memory library
at commit `0aaf6ea23d6fcaf2325c1d1dee46f1dee6b593e3`, respectively, with local
integration changes retained.

Instruction cache
-----------------

The `icache` directory and its `rtl/memory_library` dependency are vendored
snapshots tracked directly by this repository, not Git submodules. No submodule
initialization is needed for these directories.

The snapshots originate from `https://github.com/bsc-loca/instruction_cache.git`
at commit `b228ae2ec6402d5abdaa23bc6c88ab94ddd99eea` and its memory library
at commit `0aaf6ea23d6fcaf2325c1d1dee46f1dee6b593e3`, respectively, with local
integration changes retained.
