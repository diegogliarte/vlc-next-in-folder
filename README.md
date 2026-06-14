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

Order:

```txt
current file -> next files -> subfolders -> previous files
```

This makes VLC's **Previous** button go to the real previous file.

## Sorting

Optional with `sort`.

Default:

```txt
sort="name"
```

Sort values:

```txt
name        = filename, ascending
name_desc   = filename, descending
mtime       = modification date, oldest first
mtime_desc  = modification date, newest first
ctime       = creation date, oldest first
ctime_desc  = creation date, newest first
size        = file size, smallest first
size_desc   = file size, largest first
```

Example:

```txt
lua-config=next_in_folder={sort="ctime_desc"}
```

With `mtime`, `ctime`, and `size`, files with the same value are ordered like Windows Explorer.

Creation date availability depends on what VLC and your operating system expose. If creation date is unavailable for some files, those files go after files where creation date is available. If creation date is unavailable for all files, the order falls back to filename order.

## Subfolders

Optional with `depth`.

Example:

```txt
Episode 01.mkv
Episode 02.mkv
Episode 03.mkv
Extras/
  Extra A.mkv
  Extra B.mkv
```

Opening `Episode 02.mkv` with `depth=1` makes:

```txt
Episode 02.mkv
Episode 03.mkv
Extras/Extra A.mkv
Extras/Extra B.mkv
Episode 01.mkv
```

Depth values:

```txt
0 = current folder only
1 = direct subfolders
2 = two folder levels
```

Example config:

```txt
lua-config=next_in_folder={depth=1}
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

In VLC's config file, lines that start with `#` are comments. VLC ignores them.

For example, this is disabled:

```txt
#extraintf=
#lua-intf=
```

To enable a setting, remove the `#` at the start of the line and set the value.

Add or change:

```txt
extraintf=luaintf
lua-intf=next_in_folder
```

Use `next_in_folder`, not `next_in_folder.lua`.

To enable subfolders:

```txt
lua-config=next_in_folder={depth=1}
```

To sort by modification date, newest first:

```txt
lua-config=next_in_folder={sort="mtime_desc"}
```

Full example:

```txt
extraintf=luaintf
lua-intf=next_in_folder
lua-config=next_in_folder={depth=1,sort="mtime_desc"}
```

Restart VLC.

## Use

Double-click any media file.

Enjoy.
