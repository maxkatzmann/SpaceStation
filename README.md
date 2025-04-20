# SpaceStation

- Archive the app from Xcode and add it to the "Anmeldeobjekte" in Settings
- Build the `main` file using

```bash
swiftc Sources/main.swift -o main
```

- Add the following to your `.aerospace[-debug].toml`

```toml
on-focus-changed = ['exec-and-forget /Users/mkatzmann/Local/SpaceStation/main']
```

## AeroSpace

- We are using a fork in which the `list-windows` command is adjust to not sort
  windows alphabetically but rather to keep the sorting as it is in the tree
- We are running the debug version, as it does not crash on an issue about
  [windows always have parent](https://github.com/nikitabobko/AeroSpace/issues/1306).
