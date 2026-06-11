-- next_in_folder.lua
-- VLC lua/intf script.
--
-- Playlist order:
-- current file -> next files -> subfolders -> previous files
--
-- Optional config:
-- lua-config=next_in_folder={depth=1,sort="mtime_desc"}
--
-- Sort values:
--   name        natural filename sort, ascending, default
--   name_desc   natural filename sort, descending
--   mtime       modification time, oldest first
--   mtime_desc  modification time, newest first
--   size        file size, smallest first
--   size_desc   file size, largest first
--
-- Tie behavior:
--   When mtime or size are equal, names are always sorted ascending.
--   This matches the usual Windows Explorer behavior for equal values.

local CHECK_INTERVAL_US = 1000000 -- 1 second
local DEPTH = math.max(0, math.floor(tonumber(config and config.depth) or 0))
local DEBUG = false

local SORT = tostring((config and config.sort) or "name"):lower()
local SORT_DESC = false

if SORT:match("_desc$") then
	SORT_DESC = true
	SORT = SORT:gsub("_desc$", "")
end

if SORT ~= "name" and SORT ~= "mtime" and SORT ~= "size" then
	SORT = "name"
	SORT_DESC = false
end

local NEED_STAT = SORT == "mtime" or SORT == "size"

local anchor_path = nil
local queued = {}
local stat_cache = {}

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
	return tostring(name or ""):lower():gsub("%d+", function(n)
		return string.format("%020d", tonumber(n))
	end)
end

local function compare_name(a, b, desc)
	local ak = natural_key(a.name)
	local bk = natural_key(b.name)

	if ak ~= bk then
		if desc then
			return ak > bk
		end

		return ak < bk
	end

	local an = tostring(a.name or ""):lower()
	local bn = tostring(b.name or ""):lower()

	if an ~= bn then
		if desc then
			return an > bn
		end

		return an < bn
	end

	return false
end

local function compare_number(a, b, field, desc)
	local av = a[field]
	local bv = b[field]

	if av ~= nil and bv ~= nil and av ~= bv then
		if desc then
			return av > bv
		end

		return av < bv
	end

	-- Files/folders with missing metadata go last.
	if av ~= nil and bv == nil then
		return true
	end

	if av == nil and bv ~= nil then
		return false
	end

	-- Windows-style tie-breaker:
	-- if mtime/size is equal, keep name ascending.
	return compare_name(a, b, not desc)
end

local function sort_items(items)
	table.sort(items, function(a, b)
		if SORT == "name" then
			return compare_name(a, b, SORT_DESC)
		end

		return compare_number(a, b, SORT, SORT_DESC)
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

local function stat_path(path)
	local key = normalize(path)

	if stat_cache[key] ~= nil then
		return stat_cache[key] or nil
	end

	local ok, stat = pcall(function()
		return vlc.net.stat(path)
	end)

	if ok and type(stat) == "table" then
		stat_cache[key] = stat
		return stat
	end

	stat_cache[key] = false
	return nil
end

local function make_item(dir, name, with_uri)
	local path = join_path(dir, name)
	local stat = NEED_STAT and stat_path(path) or nil

	return {
		name = name,
		path = path,
		uri = with_uri and vlc.strings.make_uri(path) or nil,
		mtime = stat and tonumber(stat.modification_time) or nil,
		size = stat and tonumber(stat.size) or nil
	}
end

local function list_entries(dir)
	local ok, entries = pcall(function()
		return vlc.net.opendir(dir)
	end)

	if not ok or not entries then
		return {}
	end

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
			table.insert(files, make_item(dir, name, true))
		end
	end

	sort_items(files)

	if DEBUG then
		log("sorted files in: " .. dir)

		for i, file in ipairs(files) do
			log(
				string.format(
					"%03d | %s | mtime=%s | size=%s",
					i,
					file.name,
					tostring(file.mtime),
					tostring(file.size)
				)
			)
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
				table.insert(dirs, make_item(dir, name, false))
			end
		end
	end

	sort_items(dirs)

	return dirs
end

local function scan_tree(dir, depth)
	local files = list_files(dir)

	if depth <= 0 then
		return files
	end

	for _, subdir in ipairs(list_dirs(dir)) do
		for _, file in ipairs(scan_tree(subdir.path, depth - 1)) do
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

local function reset_anchor(path, key)
	anchor_path = path
	queued = {}
	stat_cache = {}
	queued[key] = true

	log("anchor: " .. anchor_path)
	log("depth: " .. DEPTH)
	log("sort: " .. SORT .. (SORT_DESC and "_desc" or ""))
end

local function queue_folder()
	local path = current_path()

	if not path then
		return
	end

	local key = normalize(path)

	if not anchor_path or not queued[key] then
		reset_anchor(path, key)
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

	-- 1. Files after the opened file, according to the configured sort.
	for i = start + 1, #root_files do
		add_if_new(items, root_files[i])
	end

	-- 2. Subfolders, if enabled.
	if DEPTH > 0 then
		for _, subdir in ipairs(list_dirs(anchor_dir)) do
			for _, file in ipairs(scan_tree(subdir.path, DEPTH - 1)) do
				add_if_new(items, file)
			end
		end
	end

	-- 3. Files before the opened file, according to the configured sort.
	-- This makes Previous from the opened file go to the previous item in that order.
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