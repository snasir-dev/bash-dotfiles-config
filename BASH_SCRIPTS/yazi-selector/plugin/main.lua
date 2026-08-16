-- bash-selector.yazi
--
-- Bound to `l` / <Enter> only while running inside x-script-selector-YAZI.sh
-- (detected via the BASH_SELECTOR_CACHE env var). Outside the selector it
-- re-emits whatever it replaced, so normal Yazi is unaffected.
--
-- On a hovered entry, opens a ya.which action menu (execute / execute with
-- args / open in VS Code -- or, inside "Command History": execute / edit &
-- insert into prompt / cd & run / open the raw history log in VS Code),
-- writes the chosen action + resolved data to $BASH_SELECTOR_OUT, then
-- quits. Print name / print path / copy path
-- were dropped -- Yazi's own default "c" (copy) submenu already covers
-- those. All resolution is done by name via $BASH_SELECTOR_CACHE/index.lua
-- (functions/scripts) and history.lua (Command History) -- this plugin
-- never compares its own path strings against bash's, since Yazi (native
-- Windows binary) and Git Bash can represent the same path differently.
--
-- Entering the "Command History" folder itself is intercepted too: it
-- synchronously runs build-history.sh (see BASH_SCRIPTS/yazi-selector/) to
-- lazily materialize Recent/ and Frequent/ before actually navigating in --
-- see build-history.sh's own header for why this is a real, felt wait (not
-- instant) and how its debounce keeps repeat visits cheap.

local emit = ya.emit or ya.mgr_emit or ya.manager_emit

-- Also grabs the CURRENT DIRECTORY (not just the hovered file), needed to
-- tell a "Command History/Recent" entry apart from the identically-named
-- "Command History/Frequent" one (history.lua is nested by view -- see
-- build-history.sh -- because the two can legitimately disagree on display
-- data for what is otherwise the same filename). cx.active.current.cwd is
-- an established API here: bunny.yazi and simple-tag.yazi (both already
-- installed) already read it the same way.
local get_hovered = ya.sync(function()
	local h = cx.active.current.hovered
	local cwd = tostring(cx.active.current.cwd)
	if not h then
		return nil, false, cwd
	end
	return h.name, h.cha.is_dir, cwd
end)

local ACTIONS_DEFAULT = { "exec", "args", "code" }
local ACTIONS_HISTORY = { "exec", "insert", "cd", "open-log" }

local INDEX = nil
local function load_index()
	if INDEX then
		return INDEX
	end
	local cache = os.getenv("BASH_SELECTOR_CACHE")
	INDEX = {}
	if cache then
		local ok, t = pcall(dofile, cache .. "/index.lua")
		if ok and type(t) == "table" then
			INDEX = t
		end
		local hok, hist = pcall(dofile, cache .. "/history.lua")
		INDEX.history = (hok and type(hist) == "table") and hist or { recent = {}, frequent = {}, bytool = {}, bytool_dirs = {} }
	end
	return INDEX
end

-- Re-reads history.lua into the ALREADY-cached INDEX table (mutating it in
-- place, not replacing it) right after a lazy build finishes. Needed because
-- load_index() above only dofiles history.lua ONCE per Yazi session (on
-- first hover-resolve, functions/scripts included) -- without this, a build
-- that happens to run AFTER that first memoization would never be picked up
-- for the rest of the session.
local function refresh_history_index()
	local cache = os.getenv("BASH_SELECTOR_CACHE")
	if not cache then
		return
	end
	local idx = load_index()
	local ok, hist = pcall(dofile, cache .. "/history.lua")
	if ok and type(hist) == "table" then
		idx.history = hist
	end
end

-- Which view (Recent / Frequent / a "By Tool/<tool>" folder) is currently
-- being browsed, from the current directory path -- NOT from the filename,
-- which any of these can share (a piped command sits in more than one tool
-- folder; see build-history.sh). Handles both path separator styles
-- defensively. Deliberately does NOT match bare ".../By Tool" itself: that
-- row set is tool-name FOLDERS, not executable history entries -- they fall
-- through to the generic is_dir branch below like any other directory, no
-- resolve() support needed.
local function history_view(cwd)
	if cwd:match("[/\\]Frequent$") then
		return "frequent"
	end
	if cwd:match("[/\\]Recent$") then
		return "recent"
	end
	if cwd:match("[/\\]By Tool[/\\][^/\\]+$") then
		return "bytool"
	end
	return nil
end

-- Resolve a hovered filename to (kind, realpath, line, invoke). Functions and
-- scripts never share a name in this repo, so a plain name lookup is enough.
-- `invoke` is the real, callable bash identifier: for functions this differs
-- from `name` (the cache file is "largest.sh" so Yazi/syntect highlight it,
-- but the actual function is "largest"); for scripts `name` already IS the
-- real, runnable filename, so `invoke` is just that same value, unused. For
-- history, `invoke` carries the command TEXT, still in its app-level-escaped
-- form (see bash-history-log.sh) -- x-script-selector-YAZI.sh decodes it
-- right before use, in exactly one place, because the decode is single-pass
-- and order-sensitive (a naive multi-pass sed/gsub unescape is ambiguous
-- whenever a literal backslash in the original command precedes an 'n' or
-- 't', e.g. `printf "\n"` -- see that script for the full reasoning).
local function resolve(name, cwd)
	local idx = load_index()
	if idx.functions and idx.functions[name] then
		local e = idx.functions[name]
		return "functions", e.realpath, e.line, e.invoke
	end
	if idx.scripts and idx.scripts[name] then
		local e = idx.scripts[name]
		return "scripts", e.realpath, e.line, name
	end
	local view = history_view(cwd)
	if view and idx.history and idx.history[view] and idx.history[view][name] then
		local e = idx.history[view][name]
		return "history", e.cwd or "", 0, e.cmd
	end
	return nil
end

return {
	entry = function(_, job)
		local fallback = (job.args and job.args.fallback) or "enter"

		-- Not inside the selector? Behave exactly like the key we replaced.
		if not os.getenv("BASH_SELECTOR_CACHE") then
			emit(fallback, {})
			return
		end

		local name, is_dir, cwd = get_hovered()
		if not name then
			return
		end
		if is_dir then
			if name == "Command History" then
				local bash = os.getenv("BASH_SELECTOR_BASH")
				local script = os.getenv("BASH_SELECTOR_HISTORY_SCRIPT")
				if bash and script then
					ya.notify({ title = "Command History", content = "Building command history…", timeout = 2, level = "info" })
					local output, err = Command(bash):arg(script):output()
					if output and output.status and output.status.success then
						refresh_history_index()
					else
						ya.notify({
							title = "Command History",
							content = "build-history.sh failed: " .. tostring(err or (output and output.stderr) or "unknown error"),
							timeout = 4,
							level = "error",
						})
					end
				end
			end
			emit("enter", {})
			return
		end

		local kind, realpath, line, invoke = resolve(name, cwd)
		if not kind then
			return -- hovering something outside the generated index; ignore
		end

		local action = job.args and job.args[1]
		if not action then
			local cands, actions
			if kind == "history" then
				cands = {
					{ on = "e", desc = "Execute" },
					{ on = "a", desc = "Edit / insert into prompt" },
					{ on = "d", desc = "cd to recorded directory, then run" },
					{ on = "v", desc = "Open history log in VS Code" },
				}
				actions = ACTIONS_HISTORY
			else
				cands = {
					{ on = "e", desc = "Execute" },
					{ on = "a", desc = "Execute with arguments..." },
					{ on = "v", desc = "Open in VS Code" },
				}
				actions = ACTIONS_DEFAULT
			end
			local idx = ya.which({ cands = cands })
			if not idx then
				return -- cancelled
			end
			action = actions[idx]
		end

		local out = os.getenv("BASH_SELECTOR_OUT")
		if out then
			local f = io.open(out, "wb")
			if f then
				f:write(table.concat({ action, kind, invoke, realpath, tostring(line) }, "\n") .. "\n")
				f:close()
			end
		end

		emit("quit", { no_cwd_file = true })
	end,
}
