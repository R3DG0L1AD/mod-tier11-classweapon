-- 22_legendary_quest.lua : "The Thaw" legendary quest helper (legendary-lk10, STAGED 2026-10-13 - not installed).
-- Tirion's Echo (915310, Guild House) gives the quests 915200-915221. This file adds his gossip: quest list,
-- a trip to the Halls of Reflection entrance, and calling your Class Trial boss (915300-915309).
-- Real players only: bots never get the quests, the trial or the forge option.
local KEEPER = 915310
local Q_ESCAPE = 915201
local IDX = {[1]=0,[2]=1,[3]=2,[4]=3,[5]=4,[6]=5,[7]=6,[8]=7,[9]=8,[11]=9}   -- class id -> trial index
local HOR = {571, 5630.44, 1994.01, 798.059, 4.58756}                            -- Halls of Reflection entrance (game_tele)
local TXT = 1
local active = {}   -- guidLow -> creature guid of a running trial

local function IsBot(p)
  local ok, b = pcall(function() return p:IsBot() end)
  if ok and b then return true end
  local ok2, acc = pcall(function() return p:GetAccountName() end)
  if ok2 and type(acc) == "string" then
    local u = acc:upper()
    if u:find("^RNDBOT") or u:find("PLAYERBOT") or u:find("^AHBOT") then return true end
  end
  return false
end
local function say(p, m) p:SendBroadcastMessage("|cff69ccf0[Tirion's Echo]|r " .. m) end
local function trialQuest(p) local i = IDX[p:GetClass()]; return i and (915202 + i), i and (915300 + i) end


-- ===== Spec swap (added 2026-10-13, UNDO: see the server undo notes) =====
local FURY_READY = true   -- flipped to true after the restart that lifts Kor'thazan's one-copy limit
local SETS = {
  [1]  = { {"Arms / Fury: Kor'thazan", {915100}}, {"Fury (Titan's Grip): two Kor'thazans", {915100,915100}, fury=true}, {"Protection: Bulwark-Blade + Dreamward Aegis", {915101,915105}} },
  [2]  = { {"Retribution: Dawnsorrow", {915102}}, {"Holy: Light of the First Aspect", {915103}}, {"Protection: Emerald Oathkeeper + Dreamward Aegis", {915104,915105}} },
  [6]  = { {"Frost / Unholy: Frostmourne Reborn", {915110}}, {"Blood: Frostmourne Reborn, Guardian's Edge", {915111}} },
  [7]  = { {"Enhancement: Twinstorm Axe", {915112}}, {"Elemental / Restoration: Primal Stormcaller + Totem", {915113,915114}} },
  [11] = { {"Balance / Restoration: Tindral's Dreamgrowth Staff", {915117}}, {"Feral: Earthwarder's Aspect Polearm", {915118}} },
}
local function classItems(cls)
  local t, seen = {}, {}
  for _, s in ipairs(SETS[cls] or {}) do for _, e in ipairs(s[2]) do if not seen[e] then seen[e] = true; t[#t+1] = e end end end
  return t
end
local function ownsAny(p)
  for e = 915100, 915118 do if p:GetItemCount(e, true) > 0 then return true end end
  return false
end
local function equippedLegendary(p)
  for slot = 15, 17 do local it = p:GetEquippedItemBySlot(slot); if it and it:GetEntry() >= 915100 and it:GetEntry() <= 915118 then return it:GetName() end end
  return nil
end
local function addSwapMenu(p)
  if IsBot(p) or not SETS[p:GetClass()] or not ownsAny(p) then return end
  for i, s in ipairs(SETS[p:GetClass()]) do
    if s.fury and not FURY_READY then
      p:GossipMenuAddItem(4, "Swap legendary for another spec: " .. s[1] .. " (available after next restart)", 0, 300 + i)
    else
      p:GossipMenuAddItem(4, "Swap legendary for another spec: " .. s[1], 0, 200 + i, false,
        "Your current legendary weapons in your BAGS will be taken and replaced with:\n" .. s[1] .. "\n\nUnequip them first. Continue?")
    end
  end
end
local function doSwap(p, i)
  local set = SETS[p:GetClass()] and SETS[p:GetClass()][i]; if not set then return end
  if set.fury and not FURY_READY then say(p, "The Titan's Grip pair becomes available after the next server restart."); return end
  local eq = equippedLegendary(p); if eq then say(p, "Please unequip " .. eq .. " first, then ask me again."); return end
  -- take before give: remove every class legendary from bags
  local taken = 0
  for _, e in ipairs(classItems(p:GetClass())) do
    local n = p:GetItemCount(e, false)
    if n > 0 then p:RemoveItem(e, n); taken = taken + n end
  end
  if taken == 0 then say(p, "I can only swap legendaries that are in your bags (not the bank)."); return end
  local mailed = 0
  for _, e in ipairs(set[2]) do
    if not p:AddItem(e, 1) then
      SendMail("Your legendary", "Your bags were full, so Tirion's Echo sent this by mail.", p:GetGUIDLow(), 0, 61, 0, 0, 0, e, 1); mailed = mailed + 1
    end
  end
  say(p, "Done! You now have: " .. set[1] .. (mailed > 0 and (" (" .. mailed .. " sent by mail, bags were full)") or ""))
end

local function onHello(event, p, c)
  p:GossipClearMenu()
  pcall(function() p:GossipAddQuests(c) end)
  if not IsBot(p) then
    if p:GetQuestStatus(Q_ESCAPE) == 3 then p:GossipMenuAddItem(2, "Send me to the Frozen Halls (Halls of Reflection).", 0, 1) end
    local q = trialQuest(p)
    if q and p:GetQuestStatus(q) == 3 then p:GossipMenuAddItem(9, "I am ready for my Class Trial.", 0, 2) end
  end
  addSwapMenu(p)
  p:GossipSendMenu(TXT, c)
  return true
end

local function onSelect(event, p, c, sender, intid)
  p:GossipComplete()
  if IsBot(p) then return end
  if intid == 1 and p:GetQuestStatus(Q_ESCAPE) == 3 then
    say(p, "Good luck! Run fast and stay together.")
    p:Teleport(HOR[1], HOR[2], HOR[3], HOR[4], HOR[5])
  elseif intid > 300 and intid < 400 then
    say(p, "The Titan's Grip pair becomes available after the next server restart.")
  elseif intid > 200 and intid < 300 then
    doSwap(p, intid - 200)
  elseif intid == 2 then
    local q, boss = trialQuest(p)
    if not q or p:GetQuestStatus(q) ~= 3 then return end
    local g = p:GetGUIDLow()
    if active[g] then
      local w = p:GetMap() and p:GetMap():GetWorldObject(active[g]); if w then say(p, "Your trial is already waiting for you!"); return end
    end
    local o = p:GetO()
    local b = p:SpawnCreature(boss, p:GetX() + 8 * math.cos(o), p:GetY() + 8 * math.sin(o), p:GetZ() + 0.5, o + math.pi, 4, 180000)
    if not b then say(p, "The trial could not appear here. Try a more open spot."); return end
    active[g] = b:GetGUID()
    say(p, "Your Class Trial begins! If it goes badly, you will be brought back safe and can try again.")
    b:AttackStart(p)
  end
end

-- soft fail: a trial boss that defeats a player leaves, and the player is brought back up
RegisterPlayerEvent(8, function(event, killer, p)   -- PLAYER_EVENT_ON_KILLED_BY_CREATURE
  if not killer or killer:GetEntry() < 915300 or killer:GetEntry() > 915309 then return end
  killer:DespawnOrUnsummon(0); active[p:GetGUIDLow()] = nil
  local pg = p:GetGUID()
  CreateLuaEvent(function()
    local pl = GetPlayerByGUID(pg)
    if pl and pl:IsDead() then pl:ResurrectPlayer(100, false) end
    if pl then say(pl, "That was a tough one! Catch your breath, then ask me to call your trial again.") end
  end, 2000, 1)
end)
RegisterPlayerEvent(4, function(e, p) active[p:GetGUIDLow()] = nil end)

RegisterCreatureGossipEvent(KEEPER, 1, onHello)
RegisterCreatureGossipEvent(KEEPER, 2, onSelect)
