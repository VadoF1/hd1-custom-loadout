# Custom Loadout

The loadout screen's single PERKS box becomes four slots:

| Slot | Choices |
|---|---|
| Perk | None, Stratagem Priority, Cardio Accelerator, Strong Arm, Precision Call-In |
| Sidearm | P-2 Peacemaker, P-6 Gunslinger, Flam-24 Pyro, Plas-3 Singe, Saber |
| Grenades | Standard, Stun, Smoke, Incendiary |
| Equipment | Laser Aim Module, Heavy Armor, MD-99 Auto-Injector, Displacement Field, All Terrain Boots |

A sidearm or grenade type is available once its old perk is unlocked. The
Saber is always available. Old loadouts move their perk into the matching
slot the first time you open the screen.

## Install

Drag the `.zip` onto the mod list in Obsidian, switch it on, and deploy.

## Works with other mods

- The mod replaces no game files. It patches the loadout scripts while the
  game runs, so it works on top of the 16 Players mod's 16-slot loadout screen
  and alongside Boss Variety. Its place in the load order does not matter.
- Session scope: in a lobby where Obsidian doesn't allow session mods, the game's
  own loadout screen is shown and you spawn with your Equipment perk, the
  standard pistol and the standard grenades. Your four slot choices are kept for
  the next lobby that allows the mod.
- The screen decides which layout to use when it opens, and keeps it until it
  closes.

## Known limits

- Other players see "-" for your Perk, Sidearm and Grenades slots on the
  loadout screen; only the Equipment slot is sent over the network. Their
  weapons and grenades still work in game.
- Gunslinger, Pyro and Singe show their old perk names (the game has no weapon
  names for them).
