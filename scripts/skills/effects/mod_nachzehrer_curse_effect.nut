this.mod_nachzehrer_curse_effect <- this.inherit("scripts/skills/skill", {
	m = {
		TurnsLeft = 1
	},

	function create()
	{
		this.m.ID = "effects.mod_nachzehrer_curse";
		this.m.Name = "Nachzehrer Curse";
		this.m.Description = "This character has been cursed with the nachzehrer's affliction and will transform into a ghoul.";
		this.m.Icon = "skills/status_effect_72.png";
		this.m.IconMini = "status_effect_72_mini";
		this.m.Overlay = "status_effect_72";
		this.m.Type = this.Const.SkillType.StatusEffect;
		this.m.IsActive = false;
		this.m.IsStacking = false;
		this.m.IsRemovedAfterBattle = true;
	}

	function setTurnsLeft( _turns )
	{
		this.m.TurnsLeft = _turns;
	}

	function getDescription()
	{
		return "This character will transform into a Nachzehrer at the end of their [color=" + this.Const.UI.Color.NegativeValue + "]" + this.m.TurnsLeft + "[/color] turn(s).";
	}

	function onTurnStart()
	{
		--this.m.TurnsLeft;
		::logInfo("[mod_nachzehrer_curse] " + this.getContainer().getActor().getName() + " curse countdown: " + this.m.TurnsLeft + " turns left");

		if (this.m.TurnsLeft <= 0)
		{
			local feastSounds = [
				"sounds/enemies/gruesome_feast_01.wav",
				"sounds/enemies/gruesome_feast_02.wav",
				"sounds/enemies/gruesome_feast_03.wav",
				"sounds/enemies/gruesome_feast_04.wav"
			];
			local tile = this.getContainer().getActor().getTile();
			if (tile != null)
			{
				this.Sound.play(feastSounds[this.Math.rand(0, feastSounds.len() - 1)], this.Const.Sound.Volume.Skill, tile.Pos);
			}

			this.transform();
		}
	}

	// Transform the entity in-place: swap sprites, sounds, and skills to ghoul equivalents.
	// No removeFromMap or TurnSequenceBar manipulation — avoids all turn-bar sync issues.
	function transform()
	{
		local cursed = this.getContainer().getActor();
		::logInfo("[mod_nachzehrer_curse] Transforming " + cursed.getName() + " (sprite swap)");

		this.hideEquipment(cursed);
		this.swapSprites(cursed);
		this.swapSounds(cursed);
		this.addGhoulSkills(cursed);
		this.assignGhoulAI(cursed);

		try { cursed.setDirty(true); } catch (e) {}

		::logInfo("[mod_nachzehrer_curse] " + cursed.getName() + " transformation complete");
		this.removeSelf();
	}

	// Clear appearance fields so the game hides body armor, helmet, and accessory sprites,
	// then hide the surcoat sprite layer (managed separately by heraldic_armor, not in Appearance).
	function hideEquipment( _cursed )
	{
		try
		{
			local app = _cursed.getItems().getAppearance();
			app.Armor = "";
			app.ArmorUpgradeFront = "";
			app.ArmorUpgradeBack = "";
			app.Accessory = "";
			app.Helmet = "";
			app.HelmetDamage = "";
			_cursed.getItems().updateAppearance();
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] hideEquipment appearance clear failed: " + e); }

		try { _cursed.getSprite("surcoat").Visible = false; } catch (e) {}
	}

	// For non-player-controlled entities, replace the AI agent with the ghoul agent
	// so the entity fights like a ghoul (pathfinding, target priority, skill usage).
	function assignGhoulAI( _cursed )
	{
		if (_cursed.m.IsControlledByPlayer) return;

		try
		{
			local agent = this.new("scripts/ai/tactical/agents/ghoul_agent");
			agent.setActor(_cursed);
			_cursed.m.AIAgent = agent;
			::logInfo("[mod_nachzehrer_curse] Ghoul AI agent assigned to " + _cursed.getName());
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] AI agent assignment failed: " + e); }
	}

	function swapSprites( _cursed )
	{
		// Base socket
		try { _cursed.getSprite("socket").setBrush("bust_base_beasts"); } catch (e) { ::logInfo("[mod_nachzehrer_curse] socket swap failed: " + e); }

		// Body
		try
		{
			local body = _cursed.getSprite("body");
			body.setBrush("bust_ghoul_body_01");
			body.varySaturation(0.25);
			body.varyColor(0.06, 0.06, 0.06);
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] body swap failed: " + e); }

		// Head — match body color variation
		try
		{
			local body = _cursed.getSprite("body");
			local head = _cursed.getSprite("head");
			head.setBrush("bust_ghoul_head_01");
			head.Saturation = body.Saturation;
			head.Color = body.Color;
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] head swap failed: " + e); }

		// Injury — update brush so it shows the ghoul injury art when triggered
		try { _cursed.getSprite("injury").setBrush("bust_ghoul_01_injured"); } catch (e) {}

		// Hide human-specific visual layers
		foreach (name in ["hair", "beard", "beard_top", "eye_rings", "closed_eyes"])
		{
			try { _cursed.getSprite(name).Visible = false; } catch (e) {}
		}
	}

	function swapSounds( _cursed )
	{
		_cursed.m.Sound[this.Const.Sound.ActorEvent.DamageReceived] = [
			"sounds/enemies/ghoul_hurt_01.wav",
			"sounds/enemies/ghoul_hurt_02.wav",
			"sounds/enemies/ghoul_hurt_03.wav",
			"sounds/enemies/ghoul_hurt_04.wav",
			"sounds/enemies/ghoul_hurt_05.wav",
			"sounds/enemies/ghoul_hurt_06.wav",
			"sounds/enemies/ghoul_hurt_07.wav",
			"sounds/enemies/ghoul_hurt_08.wav",
			"sounds/enemies/ghoul_hurt_09.wav",
			"sounds/enemies/ghoul_hurt_10.wav",
			"sounds/enemies/ghoul_hurt_11.wav",
			"sounds/enemies/ghoul_hurt_12.wav",
			"sounds/enemies/ghoul_hurt_13.wav",
			"sounds/enemies/ghoul_hurt_14.wav",
			"sounds/enemies/ghoul_hurt_15.wav"
		];
		_cursed.m.Sound[this.Const.Sound.ActorEvent.Death] = [
			"sounds/enemies/ghoul_death_01.wav",
			"sounds/enemies/ghoul_death_02.wav",
			"sounds/enemies/ghoul_death_03.wav",
			"sounds/enemies/ghoul_death_04.wav",
			"sounds/enemies/ghoul_death_05.wav",
			"sounds/enemies/ghoul_death_06.wav",
			"sounds/enemies/ghoul_death_07.wav"
		];
		_cursed.m.Sound[this.Const.Sound.ActorEvent.Flee] = [
			"sounds/enemies/ghoul_flee_01.wav",
			"sounds/enemies/ghoul_flee_02.wav",
			"sounds/enemies/ghoul_flee_03.wav",
			"sounds/enemies/ghoul_flee_04.wav",
			"sounds/enemies/ghoul_flee_05.wav",
			"sounds/enemies/ghoul_flee_06.wav",
			"sounds/enemies/ghoul_flee_07.wav",
			"sounds/enemies/ghoul_flee_08.wav"
		];
		_cursed.m.Sound[this.Const.Sound.ActorEvent.Idle] = [
			"sounds/enemies/ghoul_idle_01.wav",
			"sounds/enemies/ghoul_idle_02.wav",
			"sounds/enemies/ghoul_idle_03.wav",
			"sounds/enemies/ghoul_idle_04.wav",
			"sounds/enemies/ghoul_idle_05.wav",
			"sounds/enemies/ghoul_idle_06.wav",
			"sounds/enemies/ghoul_idle_07.wav",
			"sounds/enemies/ghoul_idle_08.wav",
			"sounds/enemies/ghoul_idle_09.wav",
			"sounds/enemies/ghoul_idle_10.wav",
			"sounds/enemies/ghoul_idle_11.wav",
			"sounds/enemies/ghoul_idle_12.wav",
			"sounds/enemies/ghoul_idle_13.wav",
			"sounds/enemies/ghoul_idle_14.wav",
			"sounds/enemies/ghoul_idle_15.wav",
			"sounds/enemies/ghoul_idle_16.wav",
			"sounds/enemies/ghoul_idle_17.wav",
			"sounds/enemies/ghoul_idle_18.wav",
			"sounds/enemies/ghoul_idle_19.wav",
			"sounds/enemies/ghoul_idle_20.wav",
			"sounds/enemies/ghoul_idle_21.wav",
			"sounds/enemies/ghoul_idle_22.wav",
			"sounds/enemies/ghoul_idle_23.wav",
			"sounds/enemies/ghoul_idle_24.wav",
			"sounds/enemies/ghoul_idle_25.wav",
			"sounds/enemies/ghoul_idle_26.wav",
			"sounds/enemies/ghoul_idle_27.wav"
		];
	}

	function addGhoulSkills( _cursed )
	{
		try { _cursed.m.Skills.add(this.new("scripts/skills/perks/perk_pathfinder")); } catch (e) { ::logInfo("[mod_nachzehrer_curse] perk_pathfinder failed: " + e); }
		try { _cursed.m.Skills.add(this.new("scripts/skills/actives/mod_nachzehrer_ghoul_claws")); } catch (e) { ::logInfo("[mod_nachzehrer_curse] mod_nachzehrer_ghoul_claws failed: " + e); }
		_cursed.m.Skills.update();
	}

	function onCombatFinished()
	{
		this.removeSelf();
	}

});
