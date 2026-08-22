-- ─────────────────────────── bash-selector (x-script-selector-YAZI.sh) ───────────────────────────
-- Hover descriptions + right-column linemode for the Yazi-based bash function/script/history
-- selector. Only active when launched by that script (BASH_SELECTOR_CACHE set); otherwise both
-- hooks below return "", matching normal Yazi's previous behavior exactly (linemode = "none").
--
-- This file is VERSIONED here (not hand-pasted into ~/.config/yazi/init.lua) and SYMLINKED to
-- $YAZI_CONFIG_HOME/bash-selector-ui.lua -- same @create-symlinks.ps1 entry (in the DOTFILES/
-- shared-resources repo) that links bash-selector-plugin/main.lua, set up ONCE per machine, not
-- by x-script-selector-YAZI.sh. init.lua itself only keeps a two-line stub that dofiles the
-- link. See BASH_SCRIPTS/yazi-selector/ -- descriptions.json is the file to edit for
-- functions/scripts; build-history.sh is what produces history.lua.
--
-- Two separate tables, on purpose:
--   DESCS -- functions + scripts, flat, loaded once eagerly from index.lua (cheap, small, and
--           ready before the user can hover anything).
--   HIST  -- Command History, NESTED as { recent = {...}, frequent = {...}, bytool = {...},
--           bytool_dirs = {...} }, loaded lazily. recent/frequent/bytool stay separate because
--           Recent/, Frequent/, and every "By Tool/<tool>/" folder genuinely share filenames
--           (your newest command is often also a frequent one, and the same piped command files
--           under more than one tool) -- a flat merge would let one view's display data silently
--           win for the others. bytool_dirs is keyed by bare tool name (no rank prefix), one
--           entry per "By Tool/<tool>" folder ROW itself, not per command inside it. Lazy because
--           history.lua doesn't exist until build-history.sh has run at least once (triggered on
--           first entry into "Command History" by bash-selector-plugin/main.lua, not at Yazi startup).
local CACHE = os.getenv("BASH_SELECTOR_CACHE")

local DESCS = {}
if CACHE then
	local ok, idx = pcall(dofile, CACHE .. "/index.lua")
	if ok and type(idx) == "table" then
		for k, v in pairs(idx.functions or {}) do
			DESCS[k] = v
		end
		for k, v in pairs(idx.scripts or {}) do
			DESCS[k] = v
		end
	end
end

local HIST = { recent = {}, frequent = {}, bytool = {}, bytool_dirs = {} }
local HIST_LAST_TRY = 0 -- os.time() of the last history.lua reload attempt; throttles re-parsing
-- a genuinely unknown filename (e.g. a row from a since-superseded rank) to at most once/second.

-- Which view a row belongs to, from its PARENT DIRECTORY -- never the filename, which every one
-- of these views can share (see above). Handles both path separator styles defensively, matching
-- the same checks bash-selector-plugin/main.lua's history_view() already makes.
--
-- Two "By Tool" cases, distinguished purely by parent DEPTH, checked in this order because the
-- first pattern is a strict prefix of the second and would otherwise never get a turn:
--   ".../By Tool"          -- the row itself IS a tool folder      -> bytool_dirs
--   ".../By Tool/<tool>"   -- the row is a ranked command file     -> bytool
local function view_of(url)
	if not CACHE or not url then
		return nil
	end
	local p = tostring(url.parent or "")
	if p:match("[/\\]Frequent$") then
		return "frequent"
	end
	if p:match("[/\\]Recent$") then
		return "recent"
	end
	if p:match("[/\\]By Tool$") then
		return "bytool_dirs"
	end
	if p:match("[/\\]By Tool[/\\][^/\\]+$") then
		return "bytool"
	end
	return nil
end

-- Looks up one history row, reloading history.lua on a miss (throttled). A rebuild renumbers the
-- "0001 · " rank prefixes, so stale ranks always arrive here as a miss -- this path self-heals
-- display data after a rebuild without needing a DDS subscription or fs-change hook.
local function hist_entry(view, name)
	local e = HIST[view][name]
	if e then
		return e
	end
	local now = os.time()
	if now == HIST_LAST_TRY then
		return nil
	end
	HIST_LAST_TRY = now
	local ok, t = pcall(dofile, CACHE .. "/history.lua")
	if ok and type(t) == "table" then
		HIST = {
			recent = t.recent or {},
			frequent = t.frequent or {},
			bytool = t.bytool or {},
			bytool_dirs = t.bytool_dirs or {},
		}
	end
	return HIST[view][name]
end

-- Single lookup shared by both hooks below so the linemode column and the status hover line can
-- never disagree about what a row is.
local function lookup(file)
	local view = view_of(file.url)
	if view then
		return hist_entry(view, file.name)
	end
	return DESCS[file.name]
end

function Linemode:desc()
	local d = lookup(self._file)
	return d and (d.description_linemode_col or "") or ""
end

Status:children_add(function(self)
	if not CACHE then
		return ""
	end
	local h = self._current.hovered
	if not h then
		return ""
	end
	local d = lookup(h)
	if not d then
		return ui.Span("  (no description)"):fg("darkgray")
	end
	return ui.Line({
		ui.Span("  " .. (d.desc or "")):fg("cyan"),
		ui.Span(d.example and ("   ex: " .. d.example) or ""):fg("darkgray"),
	})
end, 2000, Status.LEFT)
