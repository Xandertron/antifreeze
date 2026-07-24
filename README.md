# antifreeze

a swiss army knife multi-tool script for [LJE](https://github.com/lj-expand/lj-expand) (a tool for garry's mod allowing you to run clientside lua with basically no detection)

you wouldnt stab someone with a multi-tool would you? don't cheat for your own gain.

press `f5` in-game to open menu, you may have to run `unbind f5` in gmod's console if you wish to not take screenshots

requires installation of [lje-imgui](https://github.com/lj-expand/lje-imgui#installation) and [lje-ffi](https://lj-expand.github.io/lje-ffi/installation)

soft-like fork of [gilbhax](https://github.com/lj-expand/gilbhax)

## writing a module

modules are plain lua files dropped in `modules/`, auto-loaded on startup and wired into the `CreateMove`/`PostRender` hooks. see [`docs/example-module.lua`](docs/example-module.lua) for an annotated walkthrough of the full contract (moduleInfo, config/UI option types, and every lifecycle hook).