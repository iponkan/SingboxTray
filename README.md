## Singbox Tray Tool

This project now also includes a tray utility for [sing-box](https://github.com/SagerNet/sing-box), sharing the same design philosophy as the Rclone tool.

### 📂 Singbox Directory Structure

```text
SingboxTray/
│
├── SingboxTray.bat       <-- Startup Script (Double-click this)
│
└── core/                 <-- [Core Folder]
    ├── sing-box.exe      <-- [NOTE] Place your sing-box.exe here
    └── windows.json      <-- [NOTE] Place your config file here
```

### ✨ Singbox Features

- **System Tray Icon**: Provides a dedicated tray icon for `sing-box` for easy management.
- **UI Dashboard Access**: Quickly open the `sing-box` Web UI (`http://127.0.0.1:9090/ui/`) by double-clicking or right-clicking the tray icon.
- **Silent Background Operation**: All processes run in the background without any disruptive console windows.
- **Shortcuts & Auto-Start**: Easily create desktop shortcuts or add the tool to your startup programs via the `SingboxTray.bat` menu.

### 🚀 How to Use Singbox Tray

1.  Place your downloaded `sing-box.exe` and your configuration file, `windows.json`, into the `SingboxTray/core/` folder.
2.  Double-click `SingboxTray/SingboxTray.bat`.
3.  Use the menu options to **[1] Start the Tray**, or use **[2] and [3]** to create shortcuts and set up auto-start.

## 📄 License

MIT License
