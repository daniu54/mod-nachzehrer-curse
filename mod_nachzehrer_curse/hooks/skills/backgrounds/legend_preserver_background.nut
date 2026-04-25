// Add the Nachzehrer Curse perk to the Preserver background perk tree.
// Gated by the EnablePerkTree MSU setting.
::ModNachzehrerCurse.Hooks.hook("scripts/skills/backgrounds/legend_preserver_background", function(q) {
	q.create = @(__original) function() {
		__original();
		if (!::ModNachzehrerCurse.Mod.ModSettings.getSetting("EnablePerkTree").getValue()) {
			::logInfo("[mod_nachzehrer_curse] EnablePerkTree disabled, skipping Preserver perk tree integration");
			return;
		}
		::logInfo("[mod_nachzehrer_curse] Adding Nachzehrer Curse perk to Preserver background");
		this.m.CustomPerkTree[0].push(::Legends.Perk.ModNachzehrerCurse);
	};
});
