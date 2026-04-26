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

		// Snapshot the entity's current visual and audio state before making any changes.
		// BB does NOT auto-reset sprite visibility, scale, brush, or added skills after
		// combat — we must restore everything manually via mod_nachzehrer_transformed_effect.
		local preTransformState = this.capturePreTransformState(cursed);

		::ModNachzehrerCurse.AppearanceHelper.hideEquipment(cursed);
		this.hideAllSprites(cursed);
		this.swapSpritesToGhoul(cursed);
		this.swapSounds(cursed);
		this.addGhoulSkills(cursed);
		this.assignGhoulAI(cursed);

		// Attach the revert skill so it can undo the transformation when combat ends.
		try
		{
			local revertSkill = this.new("scripts/skills/effects/mod_nachzehrer_transformed_effect");
			revertSkill.setPreTransformState(preTransformState);
			cursed.getSkills().add(revertSkill);
			::logInfo("[mod_nachzehrer_curse] Revert skill attached to " + cursed.getName());
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] Failed to attach revert skill: " + e); }

		try { cursed.setDirty(true); } catch (e) {}

		::logInfo("[mod_nachzehrer_curse] " + cursed.getName() + " transformation complete");
		this.removeSelf();
	}

	// Captures a complete snapshot of everything that transformation will change.
	// BB never resets sprite state or added skills at battle end — this snapshot
	// is the only record of what the entity looked like before the transformation.
	function capturePreTransformState( _cursed )
	{
		local state = {
			// Per-sprite snapshot: Visible, Scale, and (for brush-swapped layers) Brush/Saturation/Color.
			Sprites = {},
			// Sound arrays for the four events we overwrite during transformation.
			SoundDamage = [],
			SoundDeath  = [],
			SoundFlee   = [],
			SoundIdle   = []
			// Appearance fields are merged in below via AppearanceHelper.captureState().
		};

		// Capture every known human entity sprite. We log each one found so the developer
		// can verify which sprites are live on the entity at transformation time.
		local allHumanSpriteNames = [
			"background", "socket", "quiver",
			"body", "tattoo_body", "scar_body", "injury_body",
			"armor", "surcoat", "armor_upgrade_back", "armor_upgrade_front",
			"bandage_1", "bandage_2", "bandage_3",
			"shaft",
			"head", "eye_rings", "closed_eyes", "tattoo_head", "scar_head",
			"injury",
			"permanent_injury_1", "permanent_injury_2", "permanent_injury_3", "permanent_injury_4",
			"beard", "beard_top", "hair",
			"helmet", "helmet_damage",
			"accessory", "accessory_special",
			"body_blood", "dirt"
		];

		// Sprites whose brush we swap during transformation need full brush/color capture.
		local brushSwappedSprites = ["socket", "body", "head", "injury"];

		foreach (name in allHumanSpriteNames)
		{
			try
			{
				local s = _cursed.getSprite(name);
				local entry = { Visible = s.Visible, Scale = s.Scale };
				if (brushSwappedSprites.find(name) != null)
				{
					entry.Brush      <- s.getBrush().Name;
					entry.Saturation <- s.Saturation;
					entry.Color      <- s.Color;
				}
				state.Sprites[name] <- entry;
				::logInfo("[mod_nachzehrer_curse] captureState: sprite '" + name + "' Visible=" + s.Visible + " Scale=" + s.Scale);
			}
			catch (e) {}
		}

		// Appearance — delegated to AppearanceHelper (handles Legends layer fields and item refs)
		local appState = ::ModNachzehrerCurse.AppearanceHelper.captureState(_cursed);
		foreach (k, v in appState) { state[k] <- v; }

		// Sounds
		try { state.SoundDamage = _cursed.m.Sound[this.Const.Sound.ActorEvent.DamageReceived]; } catch (e) {}
		try { state.SoundDeath  = _cursed.m.Sound[this.Const.Sound.ActorEvent.Death]; } catch (e) {}
		try { state.SoundFlee   = _cursed.m.Sound[this.Const.Sound.ActorEvent.Flee]; } catch (e) {}
		try { state.SoundIdle   = _cursed.m.Sound[this.Const.Sound.ActorEvent.Idle]; } catch (e) {}
		::logInfo("[mod_nachzehrer_curse] captureState: sounds captured");

		return state;
	}

	// Hide every sprite layer on the entity before applying ghoul visuals.
	// Weapon items are managed by the items system and are not sprite layers, so they
	// are excluded automatically. Both Visible and Scale are set so the sprites stay
	// suppressed even if the game resets Visible on turn transitions.
	function hideAllSprites( _cursed )
	{
		local allHumanSpriteNames = [
			"background", "socket", "quiver",
			"body", "tattoo_body", "scar_body", "injury_body",
			"armor", "surcoat", "armor_upgrade_back", "armor_upgrade_front",
			"bandage_1", "bandage_2", "bandage_3",
			"shaft",
			"head", "eye_rings", "closed_eyes", "tattoo_head", "scar_head",
			"injury",
			"permanent_injury_1", "permanent_injury_2", "permanent_injury_3", "permanent_injury_4",
			"beard", "beard_top", "hair",
			"helmet", "helmet_damage",
			"accessory", "accessory_special",
			"body_blood", "dirt"
		];

		local hiddenNames = [];
		foreach (name in allHumanSpriteNames)
		{
			try
			{
				local s = _cursed.getSprite(name);
				s.Visible = false;
				s.Scale = 0.001;
				hiddenNames.push(name);
			}
			catch (e) {}
		}

		local joined = "";
		foreach (n in hiddenNames) { joined += n + " "; }
		::logInfo("[mod_nachzehrer_curse] hideAllSprites: suppressed " + hiddenNames.len() + " sprites: [" + joined + "]");

		// Force a visual refresh so the changes take effect immediately.
		try { _cursed.setDirty(true); } catch (e) {}
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

	// Apply ghoul brushes to the relevant sprite layers, then make only those layers
	// visible. All other layers were suppressed by hideAllSprites().
	function swapSpritesToGhoul( _cursed )
	{
		// Socket (base backing sprite)
		try
		{
			local s = _cursed.getSprite("socket");
			s.setBrush("bust_base_beasts");
			s.Visible = true;
			s.Scale = 1.0;
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] socket swap failed: " + e); }

		// Body
		try
		{
			local body = _cursed.getSprite("body");
			body.setBrush("bust_ghoul_body_01");
			body.varySaturation(0.25);
			body.varyColor(0.06, 0.06, 0.06);
			body.Visible = true;
			body.Scale = 1.0;
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
			head.Visible = true;
			head.Scale = 1.0;
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] head swap failed: " + e); }

		// Injury — swap brush but keep hidden; the engine shows it automatically when injured
		try { _cursed.getSprite("injury").setBrush("bust_ghoul_01_injured"); } catch (e) {}

		// Re-apply correct horizontal flip after setBrush resets it.
		// Allied entities (player side, facing right) get flip=false;
		// enemy entities get flip=true. Without this, ghoul sprites on player bros
		// appear facing the wrong direction.
		try
		{
			local flip = _cursed.isAlliedWithPlayer();
			foreach (name in ["socket", "body", "armor", "head", "face", "injury",
			                   "beard", "hair", "helmet", "helmet_damage",
			                   "beard_top", "body_blood", "dirt"])
			{
				try { _cursed.getSprite(name).setHorizontalFlipping(flip); } catch (e) {}
			}
			::logInfo("[mod_nachzehrer_curse] swapSpritesToGhoul: flip=" + flip + " for " + _cursed.getName());
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
