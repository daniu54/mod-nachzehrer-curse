// Attached to an entity after the nachzehrer transformation is applied.
// Stores the original visual/audio state and reverts everything when combat ends.
this.mod_nachzehrer_transformed_effect <- this.inherit("scripts/skills/skill", {
	m = {
		SavedState = null
	},

	function create()
	{
		this.m.ID = "effects.mod_nachzehrer_transformed";
		this.m.Name = "Transformed";
		this.m.Description = "This character has been transformed into a Nachzehrer.";
		this.m.Icon = "skills/status_effect_72.png";
		this.m.IconMini = "status_effect_72_mini";
		this.m.Overlay = "status_effect_72";
		this.m.Type = this.Const.SkillType.StatusEffect;
		this.m.IsActive = false;
		this.m.IsStacking = false;
		this.m.IsRemovedAfterBattle = false;
	}

	function setSavedState( _state )
	{
		this.m.SavedState = _state;
	}

	function onCombatFinished()
	{
		::logInfo("[mod_nachzehrer_curse] onCombatFinished: reverting transformation");
		local actor = this.getContainer().getActor();
		this.revertTransformation(actor);
		this.removeSelf();
	}

	function revertTransformation( _actor )
	{
		local state = this.m.SavedState;
		if (state == null)
		{
			::logInfo("[mod_nachzehrer_curse] revert: no saved state, skipping");
			return;
		}

		::logInfo("[mod_nachzehrer_curse] reverting " + _actor.getName());

		// Restore appearance fields and trigger a visual update
		try
		{
			local app = _actor.getItems().getAppearance();
			app.Armor = state.Armor;
			app.ArmorUpgradeFront = state.ArmorUpgradeFront;
			app.ArmorUpgradeBack = state.ArmorUpgradeBack;
			app.Accessory = state.Accessory;
			app.Helmet = state.Helmet;
			app.HelmetDamage = state.HelmetDamage;
			_actor.getItems().updateAppearance();
			::logInfo("[mod_nachzehrer_curse] revert: appearance restored (Armor=" + state.Armor + " Helmet=" + state.Helmet + ")");
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] revert: appearance restore failed: " + e); }

		// Restore socket brush
		try
		{
			_actor.getSprite("socket").setBrush(state.SocketBrush);
			::logInfo("[mod_nachzehrer_curse] revert: socket restored to " + state.SocketBrush);
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] revert: socket restore failed: " + e); }

		// Restore body brush + color variation
		try
		{
			local body = _actor.getSprite("body");
			body.setBrush(state.BodyBrush);
			body.Saturation = state.BodySaturation;
			body.Color = state.BodyColor;
			::logInfo("[mod_nachzehrer_curse] revert: body restored to " + state.BodyBrush);
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] revert: body restore failed: " + e); }

		// Restore head brush + color
		try
		{
			local head = _actor.getSprite("head");
			head.setBrush(state.HeadBrush);
			head.Saturation = state.HeadSaturation;
			head.Color = state.HeadColor;
			::logInfo("[mod_nachzehrer_curse] revert: head restored to " + state.HeadBrush);
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] revert: head restore failed: " + e); }

		// Restore injury brush
		try { _actor.getSprite("injury").setBrush(state.InjuryBrush); }
		catch (e) { ::logInfo("[mod_nachzehrer_curse] revert: injury restore failed: " + e); }

		// Restore visibility of human-specific layers
		foreach (name in ["hair", "beard", "beard_top", "eye_rings", "closed_eyes"])
		{
			if (name in state.HiddenSpritesVisible)
			{
				try { _actor.getSprite(name).Visible = state.HiddenSpritesVisible[name]; } catch (e) {}
			}
		}
		::logInfo("[mod_nachzehrer_curse] revert: human sprite layers visibility restored");

		// Re-show equipment sprite layers
		foreach (name in ["armor", "helmet", "helmet_damage", "surcoat"])
		{
			try { _actor.getSprite(name).Visible = true; } catch (e) {}
		}
		::logInfo("[mod_nachzehrer_curse] revert: equipment sprites shown");

		// Re-apply correct horizontal flip after setBrush may have reset it
		try
		{
			local flip = !_actor.isAlliedWithPlayer();
			foreach (name in ["socket", "body", "armor", "head", "face", "injury",
			                   "beard", "hair", "helmet", "helmet_damage",
			                   "beard_top", "body_blood", "dirt"])
			{
				try { _actor.getSprite(name).setHorizontalFlipping(flip); } catch (e) {}
			}
			::logInfo("[mod_nachzehrer_curse] revert: sprite flip restored to " + flip);
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] revert: flip restore failed: " + e); }

		// Restore sounds
		try
		{
			_actor.m.Sound[this.Const.Sound.ActorEvent.DamageReceived] = state.SoundDamage;
			::logInfo("[mod_nachzehrer_curse] revert: DamageReceived sound restored (" + state.SoundDamage.len() + " entries)");
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] revert: DamageReceived restore failed: " + e); }

		try
		{
			_actor.m.Sound[this.Const.Sound.ActorEvent.Death] = state.SoundDeath;
			::logInfo("[mod_nachzehrer_curse] revert: Death sound restored (" + state.SoundDeath.len() + " entries)");
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] revert: Death restore failed: " + e); }

		try
		{
			_actor.m.Sound[this.Const.Sound.ActorEvent.Flee] = state.SoundFlee;
			::logInfo("[mod_nachzehrer_curse] revert: Flee sound restored (" + state.SoundFlee.len() + " entries)");
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] revert: Flee restore failed: " + e); }

		try
		{
			_actor.m.Sound[this.Const.Sound.ActorEvent.Idle] = state.SoundIdle;
			::logInfo("[mod_nachzehrer_curse] revert: Idle sound restored (" + state.SoundIdle.len() + " entries)");
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] revert: Idle restore failed: " + e); }

		// Remove skills added during transformation.
		// perk_pathfinder ID is "perk.pathfinder"; ghoul_claws keeps ID "actives.ghoul_claws".
		try
		{
			if (_actor.getSkills().hasSkill("perk.pathfinder"))
			{
				_actor.getSkills().removeByID("perk.pathfinder");
				::logInfo("[mod_nachzehrer_curse] revert: perk.pathfinder removed");
			}
			else
			{
				::logInfo("[mod_nachzehrer_curse] revert: perk.pathfinder not found (already gone?)");
			}
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] revert: perk.pathfinder removal failed: " + e); }

		try
		{
			if (_actor.getSkills().hasSkill("actives.ghoul_claws"))
			{
				_actor.getSkills().removeByID("actives.ghoul_claws");
				::logInfo("[mod_nachzehrer_curse] revert: actives.ghoul_claws removed");
			}
			else
			{
				::logInfo("[mod_nachzehrer_curse] revert: actives.ghoul_claws not found (already gone?)");
			}
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] revert: actives.ghoul_claws removal failed: " + e); }

		_actor.m.Skills.update();
		try { _actor.setDirty(true); } catch (e) {}

		::logInfo("[mod_nachzehrer_curse] revert complete for " + _actor.getName());
	}

});
