-- Trainer reminder: when you open your class trainer, FlipForever notes the spells you can't learn
-- yet (with their level and cost). When you reach that level, the Advisor shows "New at your class
-- trainer". Nothing is bought for you. Setting: trainerReminder (on by default).
local FF = FlipForever
local T = {}
FF.Trainer = T

function T:Enabled() return FlipForeverDB.settings.trainerReminder ~= false end

local function store() return FF.Advisor:CharStore() end

-- read the open trainer window; returns the list it saved, or nil for profession trainers
function T:Read()
  if not (GetNumTrainerServices and GetTrainerServiceInfo) then return nil end
  if IsTradeskillTrainer and IsTradeskillTrainer() then return nil end
  local list = {}
  for i = 1, GetNumTrainerServices() or 0 do
    local name, rank, category = GetTrainerServiceInfo(i)
    if name and category ~= "used" and category ~= "header" then
      local level = GetTrainerServiceLevelReq and tonumber(GetTrainerServiceLevelReq(i)) or 0
      local cost = GetTrainerServiceCost and tonumber((GetTrainerServiceCost(i))) or 0
      list[#list + 1] = { name = name, rank = rank ~= "" and rank or nil, level = level, cost = cost }
    end
  end
  store().trainer = { services = list, t = time and time() or 0 }
  return list
end

-- spells you have the level for: list and total cost
function T:Due(level)
  local due, cost = {}, 0
  local t = store().trainer
  for _, s in ipairs(t and t.services or {}) do
    if (s.level or 0) <= (level or 0) then
      due[#due + 1] = s
      cost = cost + (s.cost or 0)
    end
  end
  table.sort(due, function(a, b)
    if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) < (b.level or 0) end
    return a.name < b.name
  end)
  return due, cost
end

-- the reason line of the Advisor step: the spell names
function T:Why(due)
  local names = {}
  for i, s in ipairs(due) do
    if i > 8 then names[#names + 1] = FF:T("(+%d more)"):format(#due - 8) break end
    names[#names + 1] = s.rank and (s.name .. " (" .. s.rank .. ")") or s.name
  end
  return FF:T("From your last visit to the class trainer: ") .. table.concat(names, ", ") .. "."
end

FF:On("TRAINER_SHOW", function() if T:Enabled() then pcall(T.Read, T) end end)
-- what you learn changes the list: read it again while the window is open
FF:On("TRAINER_UPDATE", function() if T:Enabled() then pcall(T.Read, T) end end)
