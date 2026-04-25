this.mod_nachzehrer_curse_effect <- this.inherit("scripts/skills/skill", {
	m = {
		TurnsLeft = 1,
		// Faction to assign the spawned nachzehrer. Set at curse application time.
		// "player"        -> player-controlled (Faction.Player + IsControlledByPlayer)
		// "player_animal" -> ai-friendly (Faction.PlayerAnimals)
		// "undead"        -> hostile enemy (Faction.Undead)
		GhoulFaction = "undead"
	},

	function create()
	{
		this.m.ID = "effects.mod_nachzehrer_curse";
		this.m.Name = "Nachzehrer Curse";
		this.m.Description = "This character has been cursed with the nachzehrer's affliction and will transform into a ghoul.";
		this.m.Icon = "skills/status_effect_39.png";
		this.m.IconMini = "status_effect_39_mini";
		this.m.Overlay = "status_effect_39";
		this.m.Type = this.Const.SkillType.StatusEffect;
		this.m.IsActive = false;
		this.m.IsStacking = false;
		this.m.IsRemovedAfterBattle = true;
	}

	function setTurnsLeft( _turns )
	{
		this.m.TurnsLeft = _turns;
	}

	function setGhoulFaction( _faction )
	{
		this.m.GhoulFaction = _faction;
	}

	function getDescription()
	{
		return "This character will transform into a Nachzehrer at the start of their next [color=" + this.Const.UI.Color.NegativeValue + "]" + this.m.TurnsLeft + "[/color] turn(s).";
	}

	function onTurnStart()
	{
		--this.m.TurnsLeft;
		::logInfo("[mod_nachzehrer_curse] " + this.getContainer().getActor().getName() + " curse countdown: " + this.m.TurnsLeft + " turns left");

		if (this.m.TurnsLeft <= 0)
		{
			this.transform();
		}
	}

	function transform()
	{
		local cursed = this.getContainer().getActor();
		local tile = cursed.getTile();

		if (tile == null)
		{
			::logError("[mod_nachzehrer_curse] transform: cursed entity has no tile, aborting");
			return;
		}

		::logInfo("[mod_nachzehrer_curse] Transforming " + cursed.getName() + " into Nachzehrer at (" + tile.Coords.X + ", " + tile.Coords.Y + ")");

		// Play the feast sound before removing the entity
		local feastSounds = [
			"sounds/enemies/gruesome_feast_01.wav",
			"sounds/enemies/gruesome_feast_02.wav",
			"sounds/enemies/gruesome_feast_03.wav",
			"sounds/enemies/gruesome_feast_04.wav"
		];
		this.Sound.play(feastSounds[this.Math.rand(0, feastSounds.len() - 1)], this.Const.Sound.Volume.Skill, tile.Pos);

		// Snapshot stats and perks BEFORE removing from map
		local sourceProps = cursed.getBaseProperties();
		local sourceHp = cursed.getHitpoints();
		local sourcePerks = cursed.getSkills().getAllSkillsOfType(this.Const.SkillType.Perk);

		// Remove the original entity from the map (no death event, no loot drop)
		cursed.removeFromMap();
		::logInfo("[mod_nachzehrer_curse] Original entity removed from map");

		// Spawn the nachzehrer at the same tile
		local ghoul = this.Tactical.spawnEntity("scripts/entity/tactical/enemies/ghoul", tile.Coords.X, tile.Coords.Y);
		::logInfo("[mod_nachzehrer_curse] Nachzehrer spawned");

		// Configure faction and player control based on the curse's stored faction
		if (this.m.GhoulFaction == "player")
		{
			ghoul.setFaction(this.Const.Faction.Player);
			ghoul.m.IsControlledByPlayer = true;
			ghoul.setName("Cursed " + cursed.getName());
			ghoul.getSprite("body").setHorizontalFlipping(true);
			ghoul.getSprite("head").setHorizontalFlipping(true);
			::logInfo("[mod_nachzehrer_curse] Ghoul set as player-controlled");
		}
		else if (this.m.GhoulFaction == "player_animal")
		{
			ghoul.setFaction(this.Const.Faction.PlayerAnimals);
			ghoul.setName("Cursed " + cursed.getName());
			ghoul.getSprite("body").setHorizontalFlipping(true);
			ghoul.getSprite("head").setHorizontalFlipping(true);
			::logInfo("[mod_nachzehrer_curse] Ghoul set as friendly AI (PlayerAnimals)");
		}
		else
		{
			// Enemy: use Undead faction (nachzehrer's native faction)
			ghoul.setFaction(this.Const.Faction.Undead);
			ghoul.setName("Cursed " + cursed.getName());
			// Enemy nachzehrer faces left (default), no flip needed
			::logInfo("[mod_nachzehrer_curse] Ghoul set as enemy (Undead)");
		}

		ghoul.setMoraleState(this.Const.MoraleState.Confident);

		// Inherit stats: take the better value for each stat field
		this.inheritStats(ghoul, sourceProps, sourceHp);

		// Inherit perks from the original entity
		this.inheritPerks(ghoul, sourcePerks);

		// Force skills update so stat changes take effect
		ghoul.getSkills().update();

		// Make the ghoul act immediately this round (same pattern as wardog unleash / summon skill)
		this.Tactical.TurnSequenceBar.removeEntity(ghoul);
		ghoul.m.IsActingImmediately = true;
		this.Tactical.TurnSequenceBar.insertEntity(ghoul);
		::logInfo("[mod_nachzehrer_curse] Nachzehrer inserted to act immediately");

		// Remove this effect from the (now off-map) entity's container
		this.removeSelf();
	}

	function inheritStats( _ghoul, _sourceProps, _sourceHp )
	{
		// Stats to inherit: take max(source, ghoul default) for each.
		// Changing this array is the intended way to adjust inheritance later.
		local statFields = [
			"Hitpoints",
			"MeleeSkill",
			"RangedSkill",
			"MeleeDefense",
			"RangedDefense",
			"Initiative",
			"Bravery",
			"Stamina"
		];

		local ghoulBase = _ghoul.m.BaseProperties;
		local ghoulCurrent = _ghoul.m.CurrentProperties;

		foreach (field in statFields)
		{
			if (_sourceProps[field] > ghoulBase[field])
			{
				::logInfo("[mod_nachzehrer_curse] Inherit stat " + field + ": " + ghoulBase[field] + " -> " + _sourceProps[field]);
				ghoulBase[field] = _sourceProps[field];
				ghoulCurrent[field] = _sourceProps[field];
			}
		}

		// Set current HP to max(source current HP, ghoul base HP)
		local newHp = this.Math.max(_sourceHp, ghoulBase.Hitpoints);
		_ghoul.m.Hitpoints = newHp;
		::logInfo("[mod_nachzehrer_curse] Inherited HP: " + newHp);
	}

	function inheritPerks( _ghoul, _perks )
	{
		foreach (perk in _perks)
		{
			local id = perk.getID();
			local script = null;

			// Look up script path via Legends perk registry (covers all registered perks)
			if ("LookupMap" in ::Const.Perks && id in ::Const.Perks.LookupMap)
			{
				script = ::Const.Perks.LookupMap[id].Script;
			}

			if (script == null)
			{
				::logWarning("[mod_nachzehrer_curse] Could not find script for perk '" + id + "', skipping");
				continue;
			}

			try
			{
				_ghoul.m.Skills.add(this.new(script));
				::logInfo("[mod_nachzehrer_curse] Inherited perk: " + id);
			}
			catch (e)
			{
				::logWarning("[mod_nachzehrer_curse] Could not add perk '" + id + "' to ghoul: " + e);
			}
		}
	}

	function onCombatFinished()
	{
		this.removeSelf();
	}

});
