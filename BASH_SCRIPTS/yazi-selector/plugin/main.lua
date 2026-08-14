-- bash-selector.yazi
--
-- Bound to `l` / <Enter> only while running inside x-script-selector-YAZI.sh
-- (detected via the BASH_SELECTOR_CACHE env var). Outside the selector it
-- re-emits whatever it replaced, so normal Yazi is unaffected.
--
-- On a hovered entry, opens a ya.which action menu (execute / execute with
-- args / open in VS Code), writes the chosen action + resolved data to
-- $BASH_SELECTOR_OUT, then quits. Print name / print path / copy path were
-- dropped -- Yazi's own default "c" (copy) submenu already covers those. All
-- resolution is done by name via $BASH_SELECTOR_CACHE/index.lua -- this
-- plugin never compares its own path strings against bash's, since Yazi
-- (native Windows binary) and Git Bash can represent the same path
-- differently.

local emit = ya.emit or ya.mgr_emit or ya.manager_emit

local get_hovered = ya.sync(function()
	local h = cx.active.current.hovered
	if not h then
		return nil, false
	end
	return h.name, h.cha.is_dir
end)

local ACTIONS = { "exec", "args", "code" }

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
	end
	return INDEX
end

-- Resolve a hovered filename to (kind, realpath, line, invoke). Functions and
-- scripts never share a name in this repo, so a plain name lookup is enough.
-- `invoke` is the real, callable bash identifier: for functions this differs
-- from `name` (the cache file is "largest.sh" so Yazi/syntect highlight it,
-- but the actual function is "largest"); for scripts `name` already IS the
-- real, runnable filename, so `invoke` is just that same value, unused.
local function resolve(name)
	local idx = load_index()
	if idx.functions and idx.functions[name] then
		local e = idx.functions[name]
		return "functions", e.realpath, e.line, e.invoke
	end
	if idx.scripts and idx.scripts[name] then
		local e = idx.scripts[name]
		return "scripts", e.realpath, e.line, name
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

		local name, is_dir = get_hovered()
		if not name then
			return
		end
		if is_dir then
			emit("enter", {})
			return
		end

		local kind, realpath, line, invoke = resolve(name)
		if not kind then
			return -- hovering something outside the generated index; ignore
		end

		local action = job.args and job.args[1]
		if not action then
			local idx = ya.which({
				cands = {
					{ on = "e", desc = "Execute" },
					{ on = "a", desc = "Execute with arguments..." },
					{ on = "v", desc = "Open in VS Code" },
				},
			})
			if not idx then
				return -- cancelled
			end
			action = ACTIONS[idx]
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
