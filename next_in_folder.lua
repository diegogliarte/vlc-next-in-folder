-- next_in_folder.lua
-- VLC lua/intf script.
-- Builds a cyclic folder playlist from the opened file:
-- current -> end -> beginning -> previous.

local CHECK_INTERVAL_US = 1000000 -- 1 second

local anchor_path = nil
local anchor_dir = nil
local queued = {}

local media_exts = {
	mkv = true, mp4 = true, avi = true, webm = true, mov = true,
	m4v = true, flv = true, wmv = true, mpg = true, mpeg = true,
	ts = true, m2ts = true, ogm = true,

	mp3 = true, flac = true, wav = true, ogg = true, m4a = true, opus = true
}

local function is_windows()
	return package.config:sub(1, 1) == "\\"
end

local function normalize(path)
	path = path:gsub("\\", "/")
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
	local item = vlc.input.item()
	return item and item:uri() or nil
end

local function current_path()
	return uri_to_path(current_uri())
end

local function scan_folder(dir)
	local entries = vlc.net.opendir(dir)
	local files = {}

	if not entries then
		return files
	end

	for _, name in ipairs(entries) do
		if is_media_file(name) then
			local path = join_path(dir, name)

			table.insert(files, {
				name = name,
				path = path,
				uri = vlc.strings.make_uri(path)
			})
		end
	end

	table.sort(files, function(a, b)
		local ak = natural_key(a.name)
		local bk = natural_key(b.name)

		if ak == bk then
			return a.name:lower() < b.name:lower()
		end

		return ak < bk
	end)

	return files
end

local function find_index(files, path)
	path = normalize(path)

	for i, file in ipairs(files) do
		if normalize(file.path) == path then
			return i
		end
	end

	return nil
end

local function queue_folder()
	local path = current_path()

	if not path then
		return
	end

	local dir = split_dir(path)

	if not dir then
		return
	end

	local uri = current_uri()

	if not anchor_path or normalize(dir) ~= normalize(anchor_dir) or not queued[uri] then
		anchor_path = path
		anchor_dir = dir
		queued = {}
		queued[uri] = true
	end

	local files = scan_folder(anchor_dir)
	local start = find_index(files, anchor_path)

	if not start then
		return
	end

	local items = {}

	for i = start + 1, #files do
		local file = files[i]

		if not queued[file.uri] then
			table.insert(items, { path = file.uri })
			queued[file.uri] = true
		end
	end

	for i = 1, start - 1 do
		local file = files[i]

		if not queued[file.uri] then
			table.insert(items, { path = file.uri })
			queued[file.uri] = true
		end
	end

	if #items > 0 then
		vlc.playlist.enqueue(items)
	end
end

while true do
	pcall(queue_folder)
	vlc.misc.mwait(vlc.misc.mdate() + CHECK_INTERVAL_US)
end