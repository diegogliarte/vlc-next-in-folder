-- next_in_folder.lua
-- VLC lua/intf script.
--
-- Playlist order:
-- current file -> next files -> subfolders -> previous files
--
-- Optional depth:
-- lua-config=next_in_folder={depth=1}

local CHECK_INTERVAL_US = 1000000 -- 1 second
local DEPTH = math.max(0, math.floor(tonumber(config and config.depth) or 0))
local DEBUG = false

local anchor_path = nil
local queued = {}

local media_exts = {
	mkv = true, mp4 = true, avi = true, webm = true, mov = true,
	m4v = true, flv = true, wmv = true, mpg = true, mpeg = true,
	ts = true, m2ts = true, ogm = true,

	mp3 = true, flac = true, wav = true, ogg = true, m4a = true, opus = true
}

local function log(message)
	if DEBUG then
		vlc.msg.warn("[Next in Folder] " .. tostring(message))
	end
end

local function is_windows()
	return package.config:sub(1, 1) == "\\"
end

local function normalize(path)
	path = (path or ""):gsub("\\", "/")
	return is_windows() and path:lower() or path
end

local function is_media_file(name)
	local ext = name and name:match("%.([^%.]+)$")
	return ext and media_exts[ext:lower()] == true
end

local function natural_key(name)
	return name:lower():gsub("%d+", function(n)
		return string.format("%020d", tonumber(n))
	end)
end

local function sort_names(names)
	table.sort(names, function(a, b)
		local ak = natural_key(a)
		local bk = natural_key(b)

		if ak == bk then
			return a:lower() < b:lower()
		end

		return ak < bk
	end)
end

local function uri_to_path(uri)
	if not uri or uri:sub(1, 7) ~= "file://" then
		return nil
	end

	local parsed = vlc.strings.url_parse(uri)

	if not parsed or not parsed.path then
		return nil
	end

	local path = vlc.strings.decode_uri(parsed.path)

	if not is_windows() then
		return path
	end

	if parsed.host and parsed.host ~= "" then
		return "\\\\" .. parsed.host .. path:gsub("/", "\\")
	end

	return path:gsub("^/(%a:)", "%1"):gsub("/", "\\")
end

local function split_dir(path)
	local dir = path:gsub("\\", "/"):match("^(.*)/.-$")

	if is_windows() and dir then
		dir = dir:gsub("/", "\\")
	end

	return dir
end

local function join_path(dir, name)
	local sep = is_windows() and "\\" or "/"

	if dir:sub(-1) == "\\" or dir:sub(-1) == "/" then
		return dir .. name
	end

	return dir .. sep .. name
end

local function current_uri()
	local ok, item = pcall(function()
		return vlc.input.item()
	end)

	if not ok or not item then
		return nil
	end

	local ok_uri, uri = pcall(function()
		return item:uri()
	end)

	return ok_uri and uri or nil
end

local function current_path()
	local uri = current_uri()

	if not uri then
		return nil
	end

	return uri_to_path(uri)
end

local function list_entries(dir)
	local ok, entries = pcall(function()
		return vlc.net.opendir(dir)
	end)

	if not ok or not entries then
		return {}
	end

	sort_names(entries)

	return entries
end

local function is_dir(path)
	local ok, entries = pcall(function()
		return vlc.net.opendir(path)
	end)

	return ok and entries ~= nil
end

local function list_files(dir)
	local files = {}

	for _, name in ipairs(list_entries(dir)) do
		if name ~= "." and name ~= ".." and is_media_file(name) then
			local path = join_path(dir, name)

			table.insert(files, {
				path = path,
				uri = vlc.strings.make_uri(path)
			})
		end
	end

	return files
end

local function list_dirs(dir)
	local dirs = {}

	for _, name in ipairs(list_entries(dir)) do
		if name ~= "." and name ~= ".." then
			local path = join_path(dir, name)

			if is_dir(path) then
				table.insert(dirs, path)
			end
		end
	end

	return dirs
end

local function scan_tree(dir, depth)
	local files = list_files(dir)

	if depth <= 0 then
		return files
	end

	for _, subdir in ipairs(list_dirs(dir)) do
		for _, file in ipairs(scan_tree(subdir, depth - 1)) do
			table.insert(files, file)
		end
	end

	return files
end

local function find_index(files, path)
	local wanted = normalize(path)

	for i, file in ipairs(files) do
		if normalize(file.path) == wanted then
			return i
		end
	end

	return nil
end

local function add_if_new(items, file)
	local key = normalize(file.path)

	if queued[key] then
		return
	end

	table.insert(items, { path = file.uri })
	queued[key] = true
end

local function queue_folder()
	local path = current_path()

	if not path then
		return
	end

	local key = normalize(path)

	if not anchor_path or not queued[key] then
		anchor_path = path
		queued = {}
		queued[key] = true

		log("anchor: " .. anchor_path)
		log("depth: " .. DEPTH)
	end

	local anchor_dir = split_dir(anchor_path)

	if not anchor_dir then
		return
	end

	local root_files = list_files(anchor_dir)
	local start = find_index(root_files, anchor_path)

	if not start then
		return
	end

	local items = {}

	-- 1. Files after the opened file.
	for i = start + 1, #root_files do
		add_if_new(items, root_files[i])
	end

	-- 2. Subfolders, if enabled.
	if DEPTH > 0 then
		for _, subdir in ipairs(list_dirs(anchor_dir)) do
			for _, file in ipairs(scan_tree(subdir, DEPTH - 1)) do
				add_if_new(items, file)
			end
		end
	end

	-- 3. Files before the opened file.
	-- This makes Previous from the opened file go to the real previous file.
	for i = 1, start - 1 do
		add_if_new(items, root_files[i])
	end

	if #items > 0 then
		vlc.playlist.enqueue(items)
		log("queued " .. #items .. " item(s)")
	end
end

while true do
	local ok, err = pcall(queue_folder)

	if not ok then
		log("error: " .. tostring(err))
	end

	vlc.misc.mwait(vlc.misc.mdate() + CHECK_INTERVAL_US)
end