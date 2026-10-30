--[[ 37_sword_thousand_truths.lua (Family LAN, 2026-10-28 by WoWbot; user t1451u)
  "The Sword of A Thousand Truths": item 919001, Epic one-hand sword (two-hander stats), ilvl 320, no level / class / race limit.
  Very rare world drop: every creature kill anywhere rolls 1 in RateOneIn (default 50000). Only REAL players can get it
  (never a bot account), only players on the creature's loot list (the tapper or the tapping group, same map, within
  MaxDistance yards), and never someone who already owns one (bags, bank, mail). Critters, totems and player pets
  never count. The winner gets it in the bags (mailbox if the bags are full) plus a world announcement.
  TeachSkill = 1: whoever receives it (drop, .additem, mail) learns One-Handed Swords if the class lacks it, so every
  class can wield it.

  GATE: this folder is shared with the LIVE realm. The script only switches itself on when the world DB has BOTH the
  item (item_template 919001) and the table familylan_sotr_config (both only on the test realm until the live push).
  Settings live in acore_world.familylan_sotr_config (Enable, RateOneIn, TeachSkill, Announce, MaxDistance).

  GM commands (GM rank 2+): .sotr | .sotr give [name] | .sotr force | .sotr rate <N> | .sotr reload
  UNDO: move this file out of lua_scripts + sotr_rollback.sql + restart (see talent4\sotr\README.md).
]]
local ITEM = 919001
local SKILL_SPELL, SKILL_ID = 201, 43 -- One-Handed Swords (the sword is a one-hander since t1454u)
local LINK = "|cffa335ee|Hitem:919001:0:0:0:0:0:0:0:0|h[The Sword of A Thousand Truths]|h|r"
local TAG = "[sotr]"

local function q(fn, sql) local ok, r = pcall(fn, sql); if ok then return r end return nil end

local function GateOpen()
  local t = q(WorldDBQuery, "SELECT table_name FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'familylan_sotr_config' LIMIT 1")
  if not t then return false end
  return q(WorldDBQuery, "SELECT entry FROM item_template WHERE entry = " .. ITEM) ~= nil
end

if not GateOpen() then
  print(TAG .. " off on this realm (no item 919001 / familylan_sotr_config in the world DB)")
  return
end

local CFG = { Enable = 1, RateOneIn = 50000, TeachSkill = 1, Announce = 1, MaxDistance = 100 }
local function LoadConfig()
  local r = q(WorldDBQuery, "SELECT k, v FROM familylan_sotr_config")
  if r then
    repeat
      local k, v = r:GetString(0), tonumber(r:GetString(1))
      if k and v and CFG[k] ~= nil then CFG[k] = v end
    until not r:NextRow()
  end
  CFG.RateOneIn = math.max(1, math.floor(CFG.RateOneIn))
end
LoadConfig()
math.randomseed(os.time())

local STATS = { kills = 0, wins = 0, noEligible = 0 }
local forceNext = {} -- GM guidLow -> true: that GM's next eligible kill always drops (test)

local function safeCall(o, m, ...)
  local args = { ... }
  local ok, r = pcall(function() local f = o[m]; if not f then return nil end; return f(o, (table.unpack or unpack)(args)) end)
  if ok then return r end
  return nil
end

-- Same bot test as 07_racial_mounts.lua (IsPlayerbot / IsRandomBot / headless / bot account names)
local function IsBot(p)
  if safeCall(p, "IsPlayerbot") == true or safeCall(p, "IsRandomBot") == true then return true end
  if safeCall(p, "GetPlayerIP") == "headless" then return true end
  local acc = safeCall(p, "GetAccountName")
  if type(acc) == "string" then
    local u = string.upper(acc)
    if u:find("^RNDBOT") or u:find("PLAYERBOT") or u:find("^AHBOT") or u:find("^RAIDBOT") then return true end
  end
  return false
end

local function OwnsOne(p)
  if p:HasItem(ITEM, 1, true) then return true end
  local r = q(CharDBQuery, string.format("SELECT 1 FROM item_instance WHERE itemEntry = %d AND owner_guid = %d LIMIT 1", ITEM, p:GetGUIDLow()))
  return r ~= nil
end

local function TeachSkill(p)
  if CFG.TeachSkill ~= 1 or IsBot(p) or p:HasSpell(SKILL_SPELL) then return end
  p:LearnSpell(SKILL_SPELL)
  local v = math.max(1, p:GetLevel() * 5)
  pcall(function() p:SetSkill(SKILL_ID, 0, v, v) end)
  p:SendBroadcastMessage("|cff00ff00You learned One-Handed Swords so you can wield " .. LINK .. ".|r")
end

local function Log(p, killed, how)
  pcall(CharDBExecute, string.format(
    "INSERT INTO familylan_sotr_log (guid, name, creature_entry, map_id, how) VALUES (%d, '%s', %d, %d, '%s')",
    p:GetGUIDLow(), p:GetName():gsub("'", ""), killed and killed:GetEntry() or 0, p:GetMapId(), how))
end

local function Give(p, killed, how)
  local item = p:AddItem(ITEM, 1)
  local where = "in your bags"
  if not item then
    SendMail("The Sword of A Thousand Truths", "Your bags were full, so the sword waited for you here.", p:GetGUIDLow(), 0, 61, 0, 0, 0, ITEM, 1)
    where = "in your mailbox (bags were full)"
  end
  TeachSkill(p)
  p:SendBroadcastMessage("|cffff8000*** You found " .. LINK .. "|cffff8000! It is " .. where .. ". ***|r")
  pcall(function() p:SendAreaTriggerMessage("You found The Sword of A Thousand Truths!") end)
  pcall(function() p:PlayDirectSound(888) end)
  if CFG.Announce == 1 and how ~= "gm-give" then
    SendWorldMessage("|cffff8000[Legend]|r " .. p:GetName() .. " found " .. LINK .. "|cffff8000!|r")
  end
  STATS.wins = STATS.wins + 1
  Log(p, killed, how)
  print(string.format("%s %s (guid %d) got the sword (%s, creature %d, map %d)", TAG, p:GetName(), p:GetGUIDLow(), how, killed and killed:GetEntry() or 0, p:GetMapId()))
end

local function Eligible(killed, list, seen, p)
  if not p then return end
  local g = p:GetGUIDLow()
  if seen[g] then return end
  seen[g] = true
  if IsBot(p) then return end
  if p:GetMapId() ~= killed:GetMapId() or killed:GetDistance(p) > CFG.MaxDistance then return end
  if OwnsOne(p) then return end
  list[#list + 1] = p
end

local function OnKill(_, _, killed)
  if CFG.Enable ~= 1 or not killed then return end
  STATS.kills = STATS.kills + 1
  local rolled = math.random(CFG.RateOneIn) == 1
  if not rolled and next(forceNext) == nil then return end -- the common, cheap path
  -- creature checks only after a winning roll (critters, totems, triggers, player pets never count)
  local ctype = safeCall(killed, "GetCreatureType")
  if ctype == 8 or ctype == 11 or safeCall(killed, "IsTrigger") == true then return end
  local owner = safeCall(killed, "GetOwner")
  if owner and safeCall(owner, "GetTypeId") == 4 then return end -- TYPEID_PLAYER
  -- who is on the loot list: the tapping group, else the tapping player
  local list, seen = {}, {}
  local grp = safeCall(killed, "GetLootRecipientGroup")
  if grp then
    for _, m in ipairs(grp:GetMembers() or {}) do Eligible(killed, list, seen, m) end
  else
    Eligible(killed, list, seen, safeCall(killed, "GetLootRecipient"))
  end
  if not rolled then -- GM test: only a GM who used .sotr force wins
    local f = {}
    for _, p in ipairs(list) do if forceNext[p:GetGUIDLow()] then f[#f + 1] = p end end
    list = f
  end
  if #list == 0 then if rolled then STATS.noEligible = STATS.noEligible + 1 end return end
  local winner = list[math.random(#list)]
  forceNext[winner:GetGUIDLow()] = nil
  Give(winner, killed, rolled and "drop" or "gm-force")
end
RegisterPlayerEvent(7, OnKill)   -- PLAYER_EVENT_ON_KILL_CREATURE (killing blow by a player, also a bot in your group)
RegisterPlayerEvent(58, OnKill)  -- PLAYER_EVENT_ON_PET_KILL (killing blow by a pet / totem)

RegisterPlayerEvent(53, function(_, p, item) -- STORE_NEW_ITEM (loot, .additem)
  if item and item:GetEntry() == ITEM then TeachSkill(p) end
end)
RegisterPlayerEvent(3, function(_, p) -- LOGIN (mail, bank)
  if CFG.TeachSkill == 1 and p:HasItem(ITEM, 1, true) then TeachSkill(p) end
end)

local function Status()
  return string.format("%s Enable=%d RateOneIn=%d TeachSkill=%d Announce=%d MaxDistance=%d | since load: kills %d, drops %d, winning rolls with nobody eligible %d",
    TAG, CFG.Enable, CFG.RateOneIn, CFG.TeachSkill, CFG.Announce, CFG.MaxDistance, STATS.kills, STATS.wins, STATS.noEligible)
end

RegisterPlayerEvent(42, function(_, player, command)
  local c = tostring(command or ""):lower()
  if c ~= "sotr" and c:sub(1, 5) ~= "sotr " then return end
  if not player then print(Status()); return false end
  if player:GetGMRank() < 2 then return end
  local args = {}
  for w in c:gmatch("%S+") do args[#args + 1] = w end
  local sub = args[2] or "status"
  if sub == "status" then
    player:SendBroadcastMessage(Status())
  elseif sub == "give" then
    local t = player
    if args[3] then t = GetPlayerByName(args[3]:sub(1, 1):upper() .. args[3]:sub(2)) end
    if not t then player:SendBroadcastMessage(TAG .. " no online player " .. args[3]); return false end
    if OwnsOne(t) then player:SendBroadcastMessage(TAG .. " " .. t:GetName() .. " already owns one"); return false end
    Give(t, nil, "gm-give")
  elseif sub == "force" then
    forceNext[player:GetGUIDLow()] = true
    player:SendBroadcastMessage(TAG .. " your next eligible kill drops the sword (you must not own one; bots never get it)")
  elseif sub == "rate" and tonumber(args[3]) then
    CFG.RateOneIn = math.max(1, math.floor(tonumber(args[3])))
    pcall(WorldDBExecute, string.format("REPLACE INTO familylan_sotr_config (k, v) VALUES ('RateOneIn', '%d')", CFG.RateOneIn))
    player:SendBroadcastMessage(TAG .. " RateOneIn = " .. CFG.RateOneIn .. " (saved)")
  elseif sub == "reload" then
    LoadConfig(); player:SendBroadcastMessage(Status())
  else
    player:SendBroadcastMessage(TAG .. " .sotr | .sotr give [name] | .sotr force | .sotr rate <N> | .sotr reload")
  end
  return false
end)

print(Status() .. " (loaded)")