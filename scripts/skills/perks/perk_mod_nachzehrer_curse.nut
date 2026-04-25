this.perk_mod_nachzehrer_curse <- this.inherit("scripts/skills/skill", {
	m = {},
	function create()
	{
		this.m.ID = "perk.mod_nachzehrer_curse";
		this.m.Name = "Nachzehrer Curse";
		this.m.Description = "You have learned to transfer the nachzehrer curse through a blade. You can stab any humanoid to initiate their transformation into a nachzehrer.";
		this.m.Icon = "ui/perks/favoured_ghoul_01.png";
		this.m.IconDisabled = "ui/perks/favoured_ghoul_bw.png";
		this.m.Type = this.Const.SkillType.Perk;
		this.m.Order = this.Const.SkillOrder.Perk;
		this.m.IsActive = false;
		this.m.IsStacking = false;
		this.m.IsHidden = false;
	}

	function onAdded()
	{
		if (!this.m.Container.hasActive(::Legends.Active.ModNachzehrerCurse))
		{
			::Legends.Actives.grant(this, ::Legends.Active.ModNachzehrerCurse);
		}
	}

	function onRemoved()
	{
		::Legends.Actives.remove(this, ::Legends.Active.ModNachzehrerCurse);
	}

});
