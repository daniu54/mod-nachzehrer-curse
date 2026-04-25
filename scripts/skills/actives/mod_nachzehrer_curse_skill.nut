this.mod_nachzehrer_curse_skill <- this.inherit("scripts/skills/skill", {
	m = {},

	function create()
	{
		::Legends.Actives.onCreate(this, ::Legends.Active.ModNachzehrerCurse);
		this.m.Description = "Imbue a knife with cursed unholy energy and plunge it into your target, initiating their transformation into a Nachzehrer. Works on self, allies, and enemies. Against enemies, HP damage must be dealt for the curse to take hold — beasts and other non-humanoids are unaffected. The caster takes no damage when targeting themselves or allies. The knife is consumed in the ritual.";
		this.m.Icon = "skills/active_03.png";
		this.m.IconDisabled = "skills/active_03_sw.png";
		this.m.Overlay = "active_03";
		this.m.KilledString = "Stabbed";
		this.m.SoundOnUse = [
			"sounds/combat/stab_01.wav",
			"sounds/combat/stab_02.wav",
			"sounds/combat/stab_03.wav"
		];
		this.m.SoundOnHitHitpoints = [
			"sounds/combat/stab_hit_01.wav",
			"sounds/combat/stab_hit_02.wav",
			"sounds/combat/stab_hit_03.wav"
		];
		this.m.Type = this.Const.SkillType.Active;
		this.m.Order = this.Const.SkillOrder.OffensiveTargeted;
		this.m.IsSerialized = false;
		this.m.IsActive = true;
		this.m.IsTargeted = true;
		this.m.IsStacking = false;
		this.m.IsAttack = true;
		this.m.IsWeaponSkill = false;
		this.m.InjuriesOnBody = this.Const.Injury.PiercingBody;
		this.m.InjuriesOnHead = this.Const.Injury.PiercingHead;
		this.m.DirectDamageMult = 0.2;
		this.m.ActionPointCost = 4;
		this.m.FatigueCost = 7;
		this.m.MinRange = 0;
		this.m.MaxRange = 1;
	}

	function getEquippedDagger()
	{
		local actor = this.getContainer().getActor();
		local mainhand = actor.getItems().getItemAtSlot(this.Const.ItemSlot.Mainhand);
		if (mainhand == null) return null;
		if (mainhand.getCategories().find("Dagger") == null) return null;
		if (mainhand.m.Condition <= 0) return null;
		return mainhand;
	}

	function isUsable()
	{
		if (!this.skill.isUsable()) return false;
		if (::ModNachzehrerCurse.Mod.ModSettings.getSetting("RequireKnife").getValue())
		{
			return this.getEquippedDagger() != null;
		}
		return true;
	}

	function getTooltip()
	{
		local ret = this.getDefaultTooltip();
		ret.push({
			id = 11,
			type = "text",
			icon = "ui/icons/special.png",
			text = "Transforms the target into a Nachzehrer. Against enemies: HP damage must be dealt and target must be humanoid."
		});
		if (::ModNachzehrerCurse.Mod.ModSettings.getSetting("RequireKnife").getValue() && this.getEquippedDagger() == null)
		{
			ret.push({
				id = 12,
				type = "text",
				icon = "ui/icons/special.png",
				text = "[color=" + this.Const.UI.Color.NegativeValue + "]Requires a knife or dagger with durability remaining equipped in the mainhand.[/color]"
			});
		}
		return ret;
	}

	// Override to allow targeting self, allies, AND enemies.
	// The default skill.onVerifyTarget blocks ally targeting when IsAttack = true.
	function onVerifyTarget( _originTile, _targetTile )
	{
		if (_targetTile.IsEmpty || !_targetTile.getEntity().isAlive() || _targetTile.getEntity().isDying())
		{
			return false;
		}

		if (this.Math.abs(_targetTile.Level - _originTile.Level) > this.m.MaxLevelDifference)
		{
			return false;
		}

		return true;
	}

	function onUse( _user, _targetTile )
	{
		if (::ModNachzehrerCurse.Mod.ModSettings.getSetting("RequireKnife").getValue())
		{
			local knife = this.getEquippedDagger();
			if (knife != null)
			{
				knife.lowerCondition(knife.m.Condition);
				::logInfo("[mod_nachzehrer_curse] Knife consumed: " + knife.getName());
			}
		}

		local target = _targetTile.getEntity();

		local relation = this.getRelation(_user, target);
		::logInfo("[mod_nachzehrer_curse] onUse: user=" + _user.getName() + " target=" + target.getName() + " relation=" + relation);

		if (relation == "enemy")
		{
			return this.useOnEnemy(_user, target);
		}
		else
		{
			return this.useOnFriendly(_user, target, relation);
		}
	}

	// For enemies: attack first, apply curse only if HP damage dealt AND target is humanoid.
	function useOnEnemy( _user, _target )
	{
		local hpBefore = _target.getHitpoints();
		local success = this.attackEntity(_user, _target);

		if (success && _target.isAlive())
		{
			local hpAfter = _target.getHitpoints();
			local hpDamageDealt = hpBefore - hpAfter;

			if (hpDamageDealt > 0)
			{
				if (_target.getFlags().has("human"))
				{
					::logInfo("[mod_nachzehrer_curse] HP damage " + hpDamageDealt + " dealt to humanoid " + _target.getName() + ", applying curse (3 turns)");
					this.applyCurse(_target, 3, "undead");
				}
				else
				{
					::logInfo("[mod_nachzehrer_curse] Target " + _target.getName() + " is not humanoid, no curse applied");
				}
			}
			else
			{
				::logInfo("[mod_nachzehrer_curse] No HP damage dealt to " + _target.getName() + ", no curse applied");
			}
		}

		return success;
	}

	// For self and allies: skip the attack, directly apply the curse.
	function useOnFriendly( _user, _target, _relation )
	{
		local turns = 0;
		local ghoulFaction = "";

		if (_relation == "self")
		{
			turns = 1;
			ghoulFaction = "player";
			::logInfo("[mod_nachzehrer_curse] Self-curse applied, 1 turn");
		}
		else if (_relation == "player_bro")
		{
			turns = 1;
			ghoulFaction = "player";
			::logInfo("[mod_nachzehrer_curse] Player bro curse applied to " + _target.getName() + ", 1 turn");
		}
		else
		{
			// ai_ally
			turns = 2;
			ghoulFaction = "player_animal";
			::logInfo("[mod_nachzehrer_curse] AI ally curse applied to " + _target.getName() + ", 2 turns");
		}

		this.applyCurse(_target, turns, ghoulFaction);
		return true;
	}

	function applyCurse( _target, _turnsLeft, _ghoulFaction )
	{
		if (_target.getSkills().hasSkill("effects.mod_nachzehrer_curse"))
		{
			::logInfo("[mod_nachzehrer_curse] " + _target.getName() + " already cursed, refreshing");
			_target.getSkills().removeByID("effects.mod_nachzehrer_curse");
		}

		local effect = this.new("scripts/skills/effects/mod_nachzehrer_curse_effect");
		effect.setTurnsLeft(_turnsLeft);
		effect.setGhoulFaction(_ghoulFaction);
		_target.getSkills().add(effect);
		::logInfo("[mod_nachzehrer_curse] Curse applied to " + _target.getName() + ": " + _turnsLeft + " turns, ghoulFaction=" + _ghoulFaction);
	}

	// Classify the relationship from the user's perspective.
	function getRelation( _user, _target )
	{
		if (_user.getID() == _target.getID())
		{
			return "self";
		}

		if (_target.getFaction() == this.Const.Faction.Player && _target.m.IsControlledByPlayer)
		{
			return "player_bro";
		}

		if (_user.isAlliedWith(_target))
		{
			return "ai_ally";
		}

		return "enemy";
	}

});
