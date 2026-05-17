# VLC Next In Folder

Tiny VLC Lua script that queues the rest of the files in the same folder.

## Problem

You double-click:

```txt
Episode 03.mkv
```

VLC only plays that file.

## What it does

Given:

```txt
Episode 01.mkv
Episode 02.mkv
Episode 03.mkv
Episode 04.mkv
Episode 05.mkv
```

Opening `Episode 03.mkv` makes the playlist:

```txt
Episode 03.mkv
Episode 04.mkv
Episode 05.mkv
Episode 01.mkv
Episode 02.mkv
```

## Setup

This is a VLC Lua **interface script**.

Copy `next_in_folder.lua` to VLC's `lua/intf` folder.

Common paths might be:

```txt
Windows:       C:\Users\<YOU>\AppData\Roaming\vlc\lua\intf\next_in_folder.lua
Linux:         ~/.local/share/vlc/lua/intf/next_in_folder.lua
Linux Flatpak: ~/.var/app/org.videolan.VLC/data/vlc/lua/intf/next_in_folder.lua
macOS:         ~/Library/Application Support/org.videolan.vlc/lua/intf/next_in_folder.lua
```

Then edit VLC's config file.

Common config paths might be:

```txt
Windows:       C:\Users\<YOU>\AppData\Roaming\vlc\vlcrc
Linux:         ~/.config/vlc/vlcrc
Linux Flatpak: ~/.var/app/org.videolan.VLC/config/vlc/vlcrc
macOS:         ~/Library/Preferences/org.videolan.vlc/vlcrc
```

Add or change:

```txt
extraintf=luaintf
lua-intf=next_in_folder
```

Use `next_in_folder`, not `next_in_folder.lua`.

Restart VLC.

## Use

Double-click any media file.

Enjoy.