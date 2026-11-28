# DST-Fixed

A collection of tweaks to vanilla Don't Starve Together. Each tweak can be enabled or disabled independently.

## Modules

Modules follow the categories in `modinfo.lua`. Show Bundle is enabled by default; all other modules are disabled by default.

### Default On

- **Show Bundle** — Show bundle and gift contents on mouse hover.

### Player

- **Enable Quick Attack** — Remove the player attack-speed limit, including darts and the Howlitzer.
- **Inventory Unwrap** — Unwrap items into an inventory or container instead of dropping them on the ground.
- **Extended Player Skins** — Allow players to use other characters' skins.
- **Static Sit Emote** — Always use the sitting animation for `/sit`.
- **Scratch Emote**
- **Disable Ghost Hounded** — Exclude ghost players from the player count when hound attacks start.
- **Enhanced Localized Description** — Make most inspection text follow the client's language. Experimental.
- **Wortox the Time Traveler**
- **Magic Hat for Everyone** — Allow all players to use the Magician's Top Hat.
- **FTK Memes** — Replace some dialogue with For the King lines.

### Equipment

- **Orange Staff Map Blink** — Allow the Lazy Explorer and the King's Staff socketed with an Orange Gem to teleport via the map.
- **Combinable Equipment** — Combine durability between equipment of the same type.
- **Hide Inactive Enlightened Crown**
- **Enhanced Enlightened Crown** — Use Moon Shards instead of sanity for attacks; replace Gestalts with an effect that benefits from player damage multipliers (at least 1×) and buffs.
- **Enhanced Howlitzer** — Allow Moon Shards to be inserted into the Howlitzer.
- **Enhanced Lunar Grimoire** — Reading it during a full moon changes the phase to a new moon.
- **Enhanced Sand Stone** — Use a Desert Stone from the inventory to create a temporary, single-use Lazy Deserter.
- **Nameable Backtrek Watch** — Name Backtrek and Rift Watches with a Feather Pencil.
- **Short Backtrek Watch Cooldown** — Reduce subsequent Backtrek Watch cooldowns to 1 minute, including watches produced by Rift Watches. Existing cooldowns are unchanged.
- **No Blow Dart Waste** — Drop darts instead of consuming them when they hit an invalid target.
- **Reskin From Inventory** — Use the Clean Sweeper on inventory items, except Walking Canes, the King's Staff, and the Orange Staff.
- **No Bowing for Bee Queen Crown** — Stop players from bowing to other players wearing the crown.
- **Glowing Mushroom Hats**
- **Enhanced Gloomerang** — Remove the limit on active Gloomerang projectiles.
- **Horseshoe More Stacks** — Increase the Horseshoe stack limit to 40.
- **Repair Kit More Stacks** — Increase the Brightshade Repair Kit, Void Repair Kit, and Auto-Mat-O-Chanic stack limit to 40.

### Buildings

- **Expanded Shadow Storage** — Expand shared shadow storage to 20 slots.
- **Enhanced Icker Preserve** — Allow the Icker Preserve to be upgraded with an Elastispacer. Turning the option off removes the upgrade from standing Icker Preserves, but collapsed ones still load with it, so rebuilding them recovers their contents.
- **Fireflies in Lamps** — Put Fireflies into Mushlights and Glowcaps for permanent light.
- **Enhanced Sisturn** — Allow Bone Shards and Mourning Glory in Sisturns.
- **Glommer Statue Repairing** — Repair Glommer's Statue with Marble.
- **No Dismantle Crockpots** — Require a Hammer to remove Portable Crock Pots.
- **Classic Lure Plants** — Restore unrestricted Lureplant placement spacing.
- **Floating Burnt End Table** — Remove the End Table's burnt animation.
- **No Firepit Charcoal**

### Mobs

- **Birds No Sleeping** — Keep birds awake at night.
- **Block Pooping With a Bung** — Use a Bung to stop Beefalo from producing manure.
- **Tentacle Pillars No Looting** — Remove Tentacle Pillar drops.
- **Inthralled Drop Only Pure Horror** — Make creatures possessed by a Void Masque drop only Pure Horror instead of masques and their regular loot.
- **Bee Queen Extra Drops** — Make Bee Queen drop a Gift Wrap Blueprint.
- **Fix Guardian's Loot** — Fix the types of loot in the Ancient Guardian's Large Ornate Chest.
- **Delayed Great Depths Worm Despawn** — Make Great Depths Worms and Blighted Great Depths Worms disappear after about 5 minutes away from all players instead of 30 seconds.

### World

- **Cave Migration Queue** — Queue shard migrations and gate client map-loading completion to avoid concurrent cave-loading issues. Adapted from Cutlass's [No More Cave Bug](https://steamcommunity.com/sharedfiles/filedetails/?id=3828908041); do not enable both together.
- **Seeds Disappear on Perished** — Make ordinary Seeds disappear when spoiled instead of producing Rot.
- **No Picking Evil Flowers** — Require digging to remove Evil Flowers.
- **No Ocean Tree Strike Drops** — Stop planted ocean trees from dropping Cut Grass and Twigs when struck by lightning.
- **Isekai Summon Magic** — [Video reference](https://www.bilibili.com/video/BV1bo4y1S736).
- **Mourning Glory into Dug Grave** — Restore dug graves with Mourning Glory.
- **Enhanced Eyeturrets** — Make Eyeturrets target bats.
- **Gather Moon Dial's Glass** — Move glass dropped by Moon Dials at the end of the storm event to the Celestial Portal.
- **No Halloween Candies** — Stop Pig King and King of the Merms trades, Leaf Piles, Frankenswine, Vamphares, and Mermummies from producing Halloween candies; other Hallowed Nights rewards still drop.
- **Less Loots in Winter's Feast** — Disable trinket and snack drops while preserving boss ornaments.
- **Offscreen Coals Throttling** — While away from all players, make scattered Coals look for targets every 2.5 seconds instead of 0.5, and update targets burning on them every 2.5 seconds instead of every frame, catching up on the elapsed time when they wake. Creatures, and burnables heating up to catch fire, still update every frame.

### Crafting

- **Random Winter Lights** — Add a recipe in the lighting category that produces a random Winter Light.
- **Enlightened Crown Shard** — Add an Enlightened Crown Shard recipe.
- **Prop Sign** — Add a Prop Sign recipe in the magic category.
- **Classic Applied Horticulture** — Restore classic Applied Horticulture with an updated recipe.

### Deprecated

These options remain listed for compatibility, but their values are no longer read and their modules have been removed.

- **Custom Action Fail String** — Character-specific action-failure dialogue is now provided by the game.
- **Disable Forest Resources Regen** — Use the world's Basic Resource Regrowth setting instead.
- **Better Fossil Repairing** — The game guarantees the correct fossil form when a Shadow Heart is nearby, including in a player's inventory; unconditional success is no longer provided.

## Patch Notes

`main/asscleaner` holds vanilla bug fixes and performance fixes that leave gameplay unchanged. They always load, with no option to disable them.

### King's Staff Effect During Shard Changes

The King's Staff's client-side effect can rebuild before the staff itself after moving between the surface and the caves. Vanilla then crashes with `attempt to index local 'owner' (a nil value)` and leaves the gem and corruption effects stuck until the staff is re-equipped. `fix_king_cane_fx.lua` waits for the staff instead of failing.

### Great Depths Worm After Loading

A full-length Great Depths Worm saved while digging to a new spot crashes the caves with `attempt to index field 'dirt_start' (a nil value)` when its head next emerges. `fix_worm_boss_tail.lua` skips the tail dirt that loading already removed.

### Shadow Arms Piling Up at the Ancient Gateway

When a player disconnects or changes shards inside the Ancient Gateway's arena, the gateway keeps acting as if they were still there. If a Keystone lies nearby, it then spawns a hand every second while no one is around, and each hand leaves its shadow arm behind. Thousands of arms pile up until the server restarts, and lag the server for whoever next approaches. `fix_atrium_keystone_hand.lua` makes the gateway forget players who leave this way and removes any arm whose hand is already gone.

### Coals Piled Into One Spot

A Great Depths Worm that can't swallow any more items flings nearby placed Coals next to its head, and they stay placed. If a flung Coals lands in the square of another placed Coals, every later load crashes with `assertion failed!` in `trap_fumarole_util.lua`. `fix_trap_fumarole_cell.lua` turns Coals back into items before the worm flings them, and loads any extra placed Coals in an occupied square as an item, so worlds already affected load again.

### Query Optimization

Some vanilla code repeats the same work every frame or for every item, which lags large, long-running worlds. `query_optimization.lua` skips the repeated work with the same results:

- W.O.B.O.T.s and W.I.N.bots look up nearby containers once per search instead of once for every item on the ground.
- Thermal Stones look up the local temperature once per update instead of twice, with a faster scan of Ice Crystaleyezers.
- Map icons of Moon Dials, Ocuvigils, Ice Crystaleyezers and Lazy Deserters stop following their structure while it is away from all players and not on a boat.
- Boats stop updating their health trend arrow, which nothing displays, while away from all players.

### Chester's Light Beam Left in Saves

Chester's light beam is written to the save if the world saves while Chester is transforming, and once loaded nothing ever removes it. It stays invisible, but the server keeps sending it to nearby players. Mourning Glory into Dug Grave left one per honored grave at every dawn before 2.30.2. `fix_chesterlight_save.lua` removes light beams restored from a save.

### Plank Left Occupied

If jumping off a Plank with Abandon Ship is interrupted, for example when armor breaks, the Plank stays occupied and no one can use it again. `abandon_ship_board.lua` frees the Plank when the jump is cut short.

### Bats From Graves Without Land Nearby

Digging up a grave during Hallowed Nights can release bats. When no land lies near the grave, vanilla has no position for them and the server crashes with `attempt to index local 'pos' (a nil value)`. `fix_mound_bats.lua` releases them at the grave instead.

### Weapons Moved Into a Backpack Mid-Shot

A shot from a weapon such as the Gloomerang or a staff deals no damage if the weapon is moved into a backpack while the shot is still in flight, and a Gloomerang's shot then vanishes instead of flying back. `fix_projectile_container_owner.lua` credits the hit to whoever carries the backpack.

### Brightshade Staff's Last Hit

The Brightshade Staff spends durability when its projectile hits, so the hit that uses the last charge breaks the staff and removes its weapon while the projectile is still bouncing on to the next target. That bounce then attacks with a staff that is no longer a weapon, which can crash the server. `fix_staff_lunarplant.lua` spends durability when the staff fires, and keeps a broken staff a weapon so shots already in flight still land.

### Dummy Targets

The Dummy Target and its lunar and shadow versions have no names, die to a single hit of 1,000 damage or more, and show only the latest hit, so hits landing in the same frame replace each other. `dummytarget_dps.lua` names them, keeps them alive, and shows the last hit, the total for that frame, and the damage over the last second.
