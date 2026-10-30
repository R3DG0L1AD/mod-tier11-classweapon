# mod-tier11-classweapon

Family LAN **“The Thaw”** class legendaries (items **915100–915118**) plus **The Sword of a Thousand Truths** (**919001**).

These are **intentionally overpowered** for 3.3.5a: legendary (or near-legendary) weapons meant for **heroics and Mythic+** with kids + playerbots. One per character for the Thaw set; the Truth Sword is a very rare world drop.

## Server (AzerothCore 3.3.5a + Eluna + Playerbots)

1. Apply `sql/item_template.sql` and `sql/quest_template.sql` to `acore_world`.
2. Copy `lua_scripts/thaw_quest.lua` and `lua_scripts/truth_sword.lua` into the Lua folder.
3. Merge the same item IDs into client **Item.dbc** (and ItemDisplayInfo if you use custom display ids 134439+).
4. `.reload ale` / restart.

Bots never receive Thaw quests or the Truth Sword.

## The Thaw

Tirion’s Echo (NPC 915310, Guild House) hands out quests 915200–915221, teleports to Halls of Reflection, and can **swap** the class legendary when you change spec (unequip first). See `THAW.md`.

Examples: Kor’thazan (Warrior), Dawnsorrow (Paladin), Frostmourne Reborn (DK), Twinstorm Axe (Shaman), Tindral’s Dreamgrowth Staff / Earthwarder’s Aspect (Druid).

## Truth Sword

Item 919001, one-hand sword, ~1 in 50 000 creature kills, real players only, teaches One-Handed Swords so every class can wield it.

Requires **mod-eluna**. No core C++ patch.
