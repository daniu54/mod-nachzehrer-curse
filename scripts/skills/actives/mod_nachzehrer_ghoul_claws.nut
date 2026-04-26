// Wraps the vanilla ghoul_claws skill. Overrides onUpdate to handle transformed
// entities (player bros, human enemies) that don't define getSize() on their class.
// Keeps ID "actives.ghoul_claws" so ai_attack_default.PossibleSkills still selects it.
this.mod_nachzehrer_ghoul_claws <- this.inherit("scripts/skills/actives/ghoul_claws", {
	m = {},

	function onUpdate( _properties )
	{
		_properties.DamageRegularMin += 25;
		_properties.DamageRegularMax += 40;
		_properties.DamageArmorMult *= 0.75;
		local actor = this.getContainer().getActor();
		local size = 1;
		try { size = actor.getSize(); } catch (e) {}
		this.m.ChanceDecapitate = 25 * size;
		this.m.ChanceDisembowel = 25 * size;
	}

});
