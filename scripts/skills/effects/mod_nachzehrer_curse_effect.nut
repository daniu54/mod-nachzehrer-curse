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

		local savedState = this.captureState(cursed);

		this.hideEquipment(cursed);
		this.swapSprites(cursed);
		this.swapSounds(cursed);
		this.addGhoulSkills(cursed);
		this.assignGhoulAI(cursed);

		try
		{
			local revertEffect = this.new("scripts/skills/effects/mod_nachzehrer_transformed_effect");
			revertEffect.setSavedState(savedState);
			cursed.getSkills().add(revertEffect);
			::logInfo("[mod_nachzehrer_curse] Revert effect added to " + cursed.getName());
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] Failed to add revert effect: " + e); }

		try { cursed.setDirty(true); } catch (e) {}

		::logInfo("[mod_nachzehrer_curse] " + cursed.getName() + " transformation complete");
		this.removeSelf();
	}

	function captureState( _cursed )
	{
		local state = {
			Armor           = "",
			ArmorUpgradeFront = "",
			ArmorUpgradeBack  = "",
			Accessory       = "",
			Helmet          = "",
			HelmetDamage    = "",
			SocketBrush     = "",
			BodyBrush       = "",
			BodySaturation  = 1.0,
			BodyColor       = 0xFFFFFF,
			HeadBrush       = "",
			HeadSaturation  = 1.0,
			HeadColor       = 0xFFFFFF,
			InjuryBrush     = "",
			HiddenSpritesVisible = {},
			SoundDamage     = [],
			SoundDeath      = [],
			SoundFlee       = [],
			SoundIdle       = []
		};

		try
		{
			local app = _cursed.getItems().getAppearance();
			state.Armor             = app.Armor;
			state.ArmorUpgradeFront = app.ArmorUpgradeFront;
			state.ArmorUpgradeBack  = app.ArmorUpgradeBack;
			state.Accessory         = app.Accessory;
			state.Helmet            = app.Helmet;
			state.HelmetDamage      = app.HelmetDamage;
			::logInfo("[mod_nachzehrer_curse] captureState: Armor=" + state.Armor + " Helmet=" + state.Helmet);
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] captureState: appearance failed: " + e); }

		try { state.SocketBrush = _cursed.getSprite("socket").getBrush().Name; } catch (e) {}

		try
		{
			local body = _cursed.getSprite("body");
			state.BodyBrush      = body.getBrush().Name;
			state.BodySaturation = body.Saturation;
			state.BodyColor      = body.Color;
			::logInfo("[mod_nachzehrer_curse] captureState: BodyBrush=" + state.BodyBrush);
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] captureState: body failed: " + e); }

		try
		{
			local head = _cursed.getSprite("head");
			state.HeadBrush      = head.getBrush().Name;
			state.HeadSaturation = head.Saturation;
			state.HeadColor      = head.Color;
			::logInfo("[mod_nachzehrer_curse] captureState: HeadBrush=" + state.HeadBrush);
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] captureState: head failed: " + e); }

		try { state.InjuryBrush = _cursed.getSprite("injury").getBrush().Name; } catch (e) {}

		foreach (name in ["hair", "beard", "beard_top", "eye_rings", "closed_eyes"])
		{
			try { state.HiddenSpritesVisible[name] <- _cursed.getSprite(name).Visible; } catch (e) {}
		}
		::logInfo("[mod_nachzehrer_curse] captureState: HiddenSpritesVisible captured");

		try { state.SoundDamage = _cursed.m.Sound[this.Const.Sound.ActorEvent.DamageReceived]; } catch (e) {}
		try { state.SoundDeath  = _cursed.m.Sound[this.Const.Sound.ActorEvent.Death]; } catch (e) {}
		try { state.SoundFlee   = _cursed.m.Sound[this.Const.Sound.ActorEvent.Flee]; } catch (e) {}
		try { state.SoundIdle   = _cursed.m.Sound[this.Const.Sound.ActorEvent.Idle]; } catch (e) {}
		::logInfo("[mod_nachzehrer_curse] captureState: sounds captured");

		return state;
	}

	function hideEquipment( _cursed )
	{
		foreach (name in ["armor", "helmet", "helmet_damage", "surcoat"])
		{
			try { _cursed.getSprite(name).Visible = false; }
			catch (e) { ::logInfo("[mod_nachzehrer_curse] hideEquipment: " + name + " sprite not found"); }
		}
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

		// Re-apply correct horizontal flip after setBrush resets it.
		// Allied entities (player side, facing right) need flip=false;
		// enemy entities need flip=true. The user-visible issue was that
		// allied bros showed the ghoul sprite facing the wrong direction.
		try
		{
			local flip = !_cursed.isAlliedWithPlayer();
			foreach (name in ["socket", "body", "armor", "head", "face", "injury",
			                   "beard", "hair", "helmet", "helmet_damage",
			                   "beard_top", "body_blood", "dirt"])
			{
				try { _cursed.getSprite(name).setHorizontalFlipping(flip); } catch (e) {}
			}
			::logInfo("[mod_nachzehrer_curse] Sprite flip set to " + flip + " for " + _cursed.getName());
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] flipSprites failed: " + e); }
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
