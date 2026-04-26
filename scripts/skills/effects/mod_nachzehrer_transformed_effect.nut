// Attached to an entity immediately after the nachzehrer transformation is applied.
// Its sole purpose is to undo the transformation when combat ends.
//
// WHY THIS EXISTS: Battle Brothers does not automatically revert sprite changes
// (visibility, scale, brush), skill additions, or sound overrides when a battle ends.
// All of those persist on the entity indefinitely unless we manually restore them.
// This skill holds the pre-transform snapshot and calls undoTransformationAfterBattle()
// in onCombatFinished().
this.mod_nachzehrer_transformed_effect <- this.inherit("scripts/skills/skill", {
	m = {
		// The snapshot captured before transformation in capturePreTransformState().
		PreTransformState = null
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
		// Do NOT set IsRemovedAfterBattle — we need onCombatFinished() to fire so
		// we can do the cleanup ourselves before removing this skill.
		this.m.IsRemovedAfterBattle = false;
	}

	function setPreTransformState( _state )
	{
		this.m.PreTransformState = _state;
	}

	// Called by the game when combat ends. BB does not revert sprites or skills
	// automatically, so this is where we undo everything the transformation changed.
	function onCombatFinished()
	{
		::logInfo("[mod_nachzehrer_curse] onCombatFinished: undoing transformation");
		local actor = this.getContainer().getActor();
		this.undoTransformationAfterBattle(actor);
		this.removeSelf();
	}

	// Restores the entity to its pre-transformation state.
	// BB never auto-resets any of these after battle, so we restore them all manually
	// from the snapshot in PreTransformState.
	function undoTransformationAfterBattle( _actor )
	{
		local state = this.m.PreTransformState;
		if (state == null)
		{
			::logInfo("[mod_nachzehrer_curse] undoTransformation: no saved state, cannot revert");
			return;
		}

		::logInfo("[mod_nachzehrer_curse] undoTransformation: reverting " + _actor.getName());

		// --- Sprites ---
		// Restore every sprite's visibility, scale, and (for brush-swapped layers) brush+color.
		// We must do this because BB does not reset sprite state between battles.
		// Setting both Visible and Scale mirrors what hideAllSprites() did so that
		// any sprite that was hidden during transformation becomes fully visible again.
		foreach (name, entry in state.Sprites)
		{
			try
			{
				local s = _actor.getSprite(name);
				s.Visible = entry.Visible;
				s.Scale   = entry.Scale;
				if ("Brush" in entry)
				{
					s.setBrush(entry.Brush);
					s.Saturation = entry.Saturation;
					s.Color      = entry.Color;
				}
				::logInfo("[mod_nachzehrer_curse] undoTransformation: sprite '" + name + "' Visible=" + entry.Visible + " Scale=" + entry.Scale);
			}
			catch (e) { ::logInfo("[mod_nachzehrer_curse] undoTransformation: sprite '" + name + "' restore failed: " + e); }
		}

		// --- Appearance ---
		// Restoring appearance fields and calling updateAppearance() re-drives the armor,
		// helmet, and accessory sprite brushes from the items system. Without this the
		// equipment sprite layers would be blank even though we restored their Visible/Scale.
		try
		{
			local app = _actor.getItems().getAppearance();
			app.Armor             = state.AppArmor;
			app.ArmorUpgradeFront = state.AppArmorUpgradeFront;
			app.ArmorUpgradeBack  = state.AppArmorUpgradeBack;
			app.Accessory         = state.AppAccessory;
			app.Helmet            = state.AppHelmet;
			app.HelmetDamage      = state.AppHelmetDamage;
			_actor.getItems().updateAppearance();
			::logInfo("[mod_nachzehrer_curse] undoTransformation: appearance restored (Armor='" + state.AppArmor + "' Helmet='" + state.AppHelmet + "')");
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] undoTransformation: appearance restore failed: " + e); }

		// Re-apply correct horizontal flip after the brush restores above may have reset it.
		try
		{
			local flip = !_actor.isAlliedWithPlayer();
			foreach (name in ["socket", "body", "armor", "head", "face", "injury",
			                   "beard", "hair", "helmet", "helmet_damage",
			                   "beard_top", "body_blood", "dirt"])
			{
				try { _actor.getSprite(name).setHorizontalFlipping(flip); } catch (e) {}
			}
			::logInfo("[mod_nachzehrer_curse] undoTransformation: sprite flip restored to " + flip);
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] undoTransformation: flip restore failed: " + e); }

		// --- Sounds ---
		// BB never resets sound overrides between battles, so we restore all four events.
		try
		{
			_actor.m.Sound[this.Const.Sound.ActorEvent.DamageReceived] = state.SoundDamage;
			::logInfo("[mod_nachzehrer_curse] undoTransformation: DamageReceived sound restored (" + state.SoundDamage.len() + " entries)");
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] undoTransformation: DamageReceived restore failed: " + e); }

		try
		{
			_actor.m.Sound[this.Const.Sound.ActorEvent.Death] = state.SoundDeath;
			::logInfo("[mod_nachzehrer_curse] undoTransformation: Death sound restored (" + state.SoundDeath.len() + " entries)");
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] undoTransformation: Death restore failed: " + e); }

		try
		{
			_actor.m.Sound[this.Const.Sound.ActorEvent.Flee] = state.SoundFlee;
			::logInfo("[mod_nachzehrer_curse] undoTransformation: Flee sound restored (" + state.SoundFlee.len() + " entries)");
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] undoTransformation: Flee restore failed: " + e); }

		try
		{
			_actor.m.Sound[this.Const.Sound.ActorEvent.Idle] = state.SoundIdle;
			::logInfo("[mod_nachzehrer_curse] undoTransformation: Idle sound restored (" + state.SoundIdle.len() + " entries)");
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] undoTransformation: Idle restore failed: " + e); }

		// --- Skills ---
		// BB does NOT remove skills added mid-battle when combat ends. We remove the two
		// skills we added during transformation. If they are missing it means the entity
		// died during combat, which is fine — just log and continue.
		// perk_pathfinder has ID "perk.pathfinder" (vanilla BB).
		// mod_nachzehrer_ghoul_claws inherits ghoul_claws and keeps its ID "actives.ghoul_claws".
		try
		{
			if (_actor.getSkills().hasSkill("perk.pathfinder"))
			{
				_actor.getSkills().removeByID("perk.pathfinder");
				::logInfo("[mod_nachzehrer_curse] undoTransformation: perk.pathfinder removed");
			}
			else
			{
				::logInfo("[mod_nachzehrer_curse] undoTransformation: perk.pathfinder not present (entity may have died)");
			}
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] undoTransformation: perk.pathfinder removal failed: " + e); }

		try
		{
			if (_actor.getSkills().hasSkill("actives.ghoul_claws"))
			{
				_actor.getSkills().removeByID("actives.ghoul_claws");
				::logInfo("[mod_nachzehrer_curse] undoTransformation: actives.ghoul_claws removed");
			}
			else
			{
				::logInfo("[mod_nachzehrer_curse] undoTransformation: actives.ghoul_claws not present (entity may have died)");
			}
		}
		catch (e) { ::logInfo("[mod_nachzehrer_curse] undoTransformation: actives.ghoul_claws removal failed: " + e); }

		_actor.m.Skills.update();
		try { _actor.setDirty(true); } catch (e) {}

		::logInfo("[mod_nachzehrer_curse] undoTransformation: complete for " + _actor.getName());
	}

});
