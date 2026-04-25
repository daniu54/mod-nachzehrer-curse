::ModNachzehrerCurse <- {
	ID = "mod_nachzehrer_curse",
	Name = "Nachzehrer Curse",
	Version = "0.1.0"
};
::ModNachzehrerCurse.Hooks <- ::Hooks.register(::ModNachzehrerCurse.ID, ::ModNachzehrerCurse.Version, ::ModNachzehrerCurse.Name);
::ModNachzehrerCurse.Hooks.require("mod_msu >= 1.7.0");
::ModNachzehrerCurse.Hooks.require("mod_legends >= 19.0.0");

::ModNachzehrerCurse.Hooks.queue(">mod_legends", function() {
	::logInfo("[mod_nachzehrer_curse] Registering MSU mod object and settings");
	::ModNachzehrerCurse.Mod <- ::MSU.Class.Mod(::ModNachzehrerCurse.ID, ::ModNachzehrerCurse.Version, ::ModNachzehrerCurse.Name);
	local page = ::ModNachzehrerCurse.Mod.ModSettings.addPage("General");
	page.addBooleanSetting(
		"EnablePerkTree",
		true,
		"Enable Nachzehrer Curse perk tree",
		"When enabled, the Nachzehrer Curse perk is added to the Preserver background. Disable to hide the mod's perks (requires a game restart to take effect)."
	);

	::logInfo("[mod_nachzehrer_curse] Registering Cursed Knife active");
	::Legends.Actives.addActiveDefObjects([{
		ID = "actives.mod_nachzehrer_curse",
		Script = "scripts/skills/actives/mod_nachzehrer_curse_skill",
		Const = "ModNachzehrerCurse",
		Name = "Cursed Knife",
	}]);

	::logInfo("[mod_nachzehrer_curse] Registering Nachzehrer Curse perk");
	::Const.Perks.addPerkDefObjects([{
		ID = "perk.mod_nachzehrer_curse",
		Script = "scripts/skills/perks/perk_mod_nachzehrer_curse",
		Const = "ModNachzehrerCurse",
		Name = "Nachzehrer Curse",
		Tooltip = "You have learned to transfer the nachzehrer curse through a blade. You can stab any humanoid to initiate their transformation into a nachzehrer.",
		Icon = "ui/perks/favoured_ghoul_01.png",
		IconDisabled = "ui/perks/favoured_ghoul_bw.png",
	}]);

	::logInfo("[mod_nachzehrer_curse] Mod loaded");
	::include("mod_nachzehrer_curse/load");
});
