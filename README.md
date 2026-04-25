# mod-nachzehrer-curse

A Battle Brothers mod for the Legends overhaul.

Adds a **Cursed Knife** skill to the Preserver background. The wielder can stab any humanoid — ally, brother, or enemy — with a cursed blade, initiating a slow transformation into a Nachzehrer (ghoul).

## Requirements

- mod_msu >= 1.7.0
- mod_legends >= 19.0.0

## Mechanics

The **Cursed Knife** skill is an active stab attack. On use:

- **Self or player-controlled brother**: always applies the curse, no damage dealt. Transformation triggers at the start of their next turn (1 turn).
- **AI-controlled ally**: always applies the curse, no damage dealt. Transforms after 2 turns.
- **Enemy (humanoid only)**: attacks the target normally. If HP damage is dealt, applies the curse. Transforms after 3 turns.
- **Enemy (beast / non-humanoid)**: only deals normal stab damage. No curse is applied.

### Transformation

When the countdown expires, the cursed entity is removed from the battlefield and replaced by a Nachzehrer on the same tile. The Nachzehrer acts immediately after the transformation.

- **Transformed player brother** → player-controlled Nachzehrer
- **Transformed AI ally** → AI-controlled friendly Nachzehrer (PlayerAnimals faction)
- **Transformed enemy** → hostile Nachzehrer (Undead faction)

The Nachzehrer inherits the better stats of the two (original entity vs. base Nachzehrer). Perks are also transferred.

## Perk Tree

The skill is unlocked via the **Nachzehrer Curse** perk in the Preserver background perk tree.

## Settings

In the MSU mod configuration menu, you can toggle:

- **Enable Nachzehrer Curse perk tree**: adds/removes the perk from the Preserver background.
