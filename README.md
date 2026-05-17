# VLC Next In Folder

A tiny VLC script that makes VLC continue with the next files in the same folder.

## Problem

You double-click one episode:

```txt
Episode 03.mkv
```

VLC plays only that file.

## What this does

It adds the rest of the folder to the VLC playlist automatically.

Example folder:

```txt
Episode 01.mkv
Episode 02.mkv
Episode 03.mkv
Episode 04.mkv
Episode 05.mkv
```

Open:

```txt
Episode 03.mkv
```

Playlist becomes:

```txt
Episode 03.mkv
Episode 04.mkv
Episode 05.mkv
Episode 01.mkv
Episode 02.mkv
```

## Setup

Copy `next_in_folder.lua` to:

```txt
C:\Users\<YOUR_USER>\AppData\Roaming\vlc\lua\intf\next_in_folder.lua
```

Open VLC config:

```txt
C:\Users\<YOUR_USER>\AppData\Roaming\vlc\vlcrc
```

Add or change these lines:

```txt
extraintf=luaintf
lua-intf=next_in_folder
```

Restart VLC.

## Use

Double-click any media file.

Done.