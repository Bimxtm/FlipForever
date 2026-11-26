-- Item notes (switch itemNotes): a short personal note per item and realm, shown in the item's
-- tooltip. /ff note <item> <text> sets it, /ff note remove <item> removes it, /ff note lists them.
-- Notes made in the app arrive with the shopping list file (FlipForever_Notes); the newer one wins.
local FF = FlipForever
local N = {}
FF.Notes = N

function N:Enabled() return FlipForeverDB ~= nil and FlipForeverDB.settings.itemNotes ~= false end

function N:Store()
  local db = FF:DB()
  db.notes = db.notes or {}
  return db.notes
end

-- the newest note for the item (this realm), from the game or the app; nil when none or removed
function N:Get(id)
  if not id then return nil end
  local mine = self:Store()[id]
  local fromApp = type(FlipForever_Notes) == "table" and type(FlipForever_Notes[FF:RealmKey()]) == "table"
    and FlipForever_Notes[FF:RealmKey()][id]
  local e = mine
  if type(fromApp) == "table" and (not e or (fromApp.t or 0) > (e.t or 0)) then e = fromApp end
  if type(e) == "table" and e.text and e.text ~= "" then return e.text end
  return nil
end

-- an empty text removes the note (kept with its time, so the app removes it too)
function N:Set(id, text)
  text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
  self:Store()[id] = { text = text:sub(1, 200), t = time() }
end

function N:TooltipLine(id)
  if not self:Enabled() then return nil end
  local text = self:Get(id)
  if not text then return nil end
  return { FF:T("  |cffffd200your note|r"), text }
end

function N:Command(rest)
  rest = rest or ""
  if rest == "" then
    local rows = {}
    for id in pairs(self:Store()) do
      local text = self:Get(id)
      if text then rows[#rows + 1] = { FF:ItemName(id), text } end
    end
    if type(FlipForever_Notes) == "table" and type(FlipForever_Notes[FF:RealmKey()]) == "table" then
      for id in pairs(FlipForever_Notes[FF:RealmKey()]) do
        local text = not self:Store()[id] and self:Get(id)
        if text then rows[#rows + 1] = { FF:ItemName(id), text } end
      end
    end
    table.sort(rows, function(a, b) return a[1] < b[1] end)
    if #rows == 0 then
      FF:Print(FF:T("No item notes. Add: /ff note <item> <text>, for example /ff note [Linen Cloth] sells best on weekends."))
    else
      FF:Print(FF:T("Item notes (%d). Remove: /ff note remove <item>."):format(#rows))
      for _, r in ipairs(rows) do FF:Print(("  %s: %s"):format(r[1], r[2])) end
    end
    return
  end
  local W = FF.WatchList
  local removeArg = rest:match("^remove%s+(.+)$")
  if removeArg then
    local id = W and W:ItemOf(removeArg)
    if id and self:Get(id) then
      self:Set(id, "")
      FF:Print(FF:T("Removed the note for %s."):format(FF:ItemName(id)))
    else
      FF:Print(FF:T("That item has no note."))
    end
    return
  end
  -- an item link first, else an item ID, else the longest known item name at the start
  local id, text
  local link, after = rest:match("^(|c%x+|H.-|h.-|h|r)%s*(.*)$")
  if not link then link, after = rest:match("^(|H.-|h.-|h)%s*(.*)$") end
  if link then id, text = W and W:ItemOf(link), after
  else
    local num, more = rest:match("^(%d+)%s+(.+)$")
    if num then id, text = tonumber(num), more
    elseif W then
      local words = {}
      for w in rest:gmatch("%S+") do words[#words + 1] = w end
      for n = #words - 1, 1, -1 do
        local found = W:ItemOf(table.concat(words, " ", 1, n))
        if found then id, text = found, table.concat(words, " ", n + 1) break end
      end
    end
  end
  if not id or not text or text == "" then
    FF:Print(FF:T("Use /ff note <item> <text>: shift-click the item (or type its name or ID), then your note."))
    return
  end
  self:Set(id, text)
  FF:Print(FF:T("Note for %s saved."):format(FF:ItemName(id)))
end

local baseSlash = SlashCmdList.FLIPFOREVER
SlashCmdList.FLIPFOREVER = function(msg)
  local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)%s*$")
  if (cmd or ""):lower() == "note" and N:Enabled() then
    FF.inSlash = true
    local ok, err = pcall(N.Command, N, rest)
    FF.inSlash = false
    if not ok then error(err, 0) end
    return
  end
  return baseSlash(msg)
end
