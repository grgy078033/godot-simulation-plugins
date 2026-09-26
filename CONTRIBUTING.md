# Contributing

Thanks for helping improve these small standalone Godot addons.

## Before changing behavior

- For a bug, include the plugin name, Godot version/platform, expected vs actual behavior and a minimal reproduction.
- Discuss larger features first. Keep each addon independent; no shared framework, required Autoload or unrelated gameplay systems.
- Never upload credentials or private game data. Use a small synthetic example instead.
- Contributions must be yours to contribute and submitted under this repository's MIT license. Do not copy third-party assets or code without checking their license.

## Local testing

Install Godot separately. The existing validation used Godot 4.7.2 on Windows with the Compatibility renderer; other environments are not yet certified.

From this repository root, replace `godot` with the path/name of your Godot executable:

```sh
godot --headless --path npc-routine-scheduler --editor --import
godot --headless --path npc-routine-scheduler --script tests/test_core.gd
godot --headless --path npc-routine-scheduler --script tests/test_demo.gd
```

Use the corresponding project folder for another plugin. Restaurant Queue also has `tests/test_readme_example.gd`. For UI changes, open that project's demo normally and check the actual rendered layout; headless tests alone are not visual acceptance.

Keep tests focused on externally observable behavior and the documented edge cases. Do not change assertions simply to conceal a failure.

## Source ZIPs

Each product includes `tools/build_release.py`, requiring Python 3's standard library. Run it from that product folder:

```sh
python tools/build_release.py
```

It produces a standalone source ZIP under `release/` with addon, demo, README and MIT license. It does not export an executable/PCK. Tests, tools, caches and generated captures are intentionally excluded from the download ZIP but development tests remain in Git.

Do not commit `.godot/`, release archives, generated capture assets or local logs. Keep pull requests small and state which checks you actually ran. Review and response times are not guaranteed.
