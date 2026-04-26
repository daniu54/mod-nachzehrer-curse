// Appearance capture, hiding, and restoration for the nachzehrer transformation.
// Separated here so curse_effect.nut and transformed_effect.nut stay focused on their
// own responsibilities. Exposed as ::ModNachzehrerCurse.AppearanceHelper.
::ModNachzehrerCurse.AppearanceHelper <- {

    // Returns a state snapshot of the actor's appearance fields and equipped item references.
    // The item references are stored as weak refs so they can be used after battle to call
    // updateAppearance() and regenerate Legends layer fields.
    function captureState( _actor )
    {
        local state = {
            AppArmor             = "",
            AppArmorUpgradeFront = "",
            AppArmorUpgradeBack  = "",
            AppAccessory         = "",
            AppHelmet            = "",
            AppHelmetDamage      = "",
            ArmorItem            = null,
            HelmetItem           = null
        };

        try
        {
            local app = _actor.getItems().getAppearance();
            state.AppArmor             = app.Armor;
            state.AppArmorUpgradeFront = app.ArmorUpgradeFront;
            state.AppArmorUpgradeBack  = app.ArmorUpgradeBack;
            state.AppAccessory         = app.Accessory;
            state.AppHelmet            = app.Helmet;
            state.AppHelmetDamage      = app.HelmetDamage;
            ::logInfo("[mod_nachzehrer_curse] AppearanceHelper.captureState: Armor='" + state.AppArmor + "' Helmet='" + state.AppHelmet + "'");
        }
        catch (e) { ::logInfo("[mod_nachzehrer_curse] AppearanceHelper.captureState: appearance read failed: " + e); }

        try
        {
            local armorItem = _actor.getItems().getItemAtSlot(::Const.ItemSlot.Body);
            if (armorItem != null)
                state.ArmorItem = ::MSU.asWeakTableRef(armorItem);
        }
        catch (e) { ::logInfo("[mod_nachzehrer_curse] AppearanceHelper.captureState: armor item capture failed: " + e); }

        try
        {
            local helmetItem = _actor.getItems().getItemAtSlot(::Const.ItemSlot.Head);
            if (helmetItem != null)
                state.HelmetItem = ::MSU.asWeakTableRef(helmetItem);
        }
        catch (e) { ::logInfo("[mod_nachzehrer_curse] AppearanceHelper.captureState: helmet item capture failed: " + e); }

        return state;
    }

    // Calls clearAppearance() on armor and helmet items if they support it (Legends items do),
    // then pushes the cleared state to sprites via updateAppearance(). Without this, Legends
    // armor layer fields (chain, plate, tabbard, cloaks, upgrades) remain visible after
    // hideAllSprites() because the items system tracks them separately from sprite Visible flags.
    function hideEquipment( _actor )
    {
        try
        {
            local armorItem = _actor.getItems().getItemAtSlot(::Const.ItemSlot.Body);
            if (armorItem != null && "clearAppearance" in armorItem)
            {
                armorItem.clearAppearance();
                ::logInfo("[mod_nachzehrer_curse] AppearanceHelper.hideEquipment: armor clearAppearance() called");
            }
        }
        catch (e) { ::logInfo("[mod_nachzehrer_curse] AppearanceHelper.hideEquipment: armor clearAppearance failed: " + e); }

        try
        {
            local helmetItem = _actor.getItems().getItemAtSlot(::Const.ItemSlot.Head);
            if (helmetItem != null && "clearAppearance" in helmetItem)
            {
                helmetItem.clearAppearance();
                ::logInfo("[mod_nachzehrer_curse] AppearanceHelper.hideEquipment: helmet clearAppearance() called");
            }
        }
        catch (e) { ::logInfo("[mod_nachzehrer_curse] AppearanceHelper.hideEquipment: helmet clearAppearance failed: " + e); }

        try
        {
            _actor.getItems().updateAppearance();
            ::logInfo("[mod_nachzehrer_curse] AppearanceHelper.hideEquipment: updateAppearance() called");
        }
        catch (e) { ::logInfo("[mod_nachzehrer_curse] AppearanceHelper.hideEquipment: updateAppearance failed: " + e); }
    }

    // Restores appearance from the captured state. For Legends items the cached item refs
    // are used to call updateAppearance(), which regenerates all layer fields (ArmorLayerChain,
    // HelmetLayerHelm, etc.) from the item's own upgrade data. Vanilla items only set a few
    // top-level fields, which we restore manually as a fallback.
    function restoreState( _actor, _state )
    {
        try
        {
            local app = _actor.getItems().getAppearance();
            app.Armor             = _state.AppArmor;
            app.ArmorUpgradeFront = _state.AppArmorUpgradeFront;
            app.ArmorUpgradeBack  = _state.AppArmorUpgradeBack;
            app.Accessory         = _state.AppAccessory;
            app.Helmet            = _state.AppHelmet;
            app.HelmetDamage      = _state.AppHelmetDamage;
            ::logInfo("[mod_nachzehrer_curse] AppearanceHelper.restoreState: base fields restored (Armor='" + _state.AppArmor + "' Helmet='" + _state.AppHelmet + "')");
        }
        catch (e) { ::logInfo("[mod_nachzehrer_curse] AppearanceHelper.restoreState: base fields restore failed: " + e); }

        // Legends items regenerate all their layer fields from upgrade data when
        // updateAppearance() is called. This is the only way to restore ArmorLayerChain,
        // ArmorLayerPlate, HelmetLayerHelm, etc. — we cannot know those values upfront.
        try
        {
            if (_state.ArmorItem != null && "updateAppearance" in _state.ArmorItem)
            {
                _state.ArmorItem.updateAppearance();
                ::logInfo("[mod_nachzehrer_curse] AppearanceHelper.restoreState: armor updateAppearance() called");
            }
        }
        catch (e) { ::logInfo("[mod_nachzehrer_curse] AppearanceHelper.restoreState: armor updateAppearance failed: " + e); }

        try
        {
            if (_state.HelmetItem != null && "updateAppearance" in _state.HelmetItem)
            {
                _state.HelmetItem.updateAppearance();
                ::logInfo("[mod_nachzehrer_curse] AppearanceHelper.restoreState: helmet updateAppearance() called");
            }
        }
        catch (e) { ::logInfo("[mod_nachzehrer_curse] AppearanceHelper.restoreState: helmet updateAppearance failed: " + e); }

        // Final container sync for vanilla items that have no updateAppearance on the item itself.
        try
        {
            _actor.getItems().updateAppearance();
            ::logInfo("[mod_nachzehrer_curse] AppearanceHelper.restoreState: container updateAppearance() called");
        }
        catch (e) { ::logInfo("[mod_nachzehrer_curse] AppearanceHelper.restoreState: container updateAppearance failed: " + e); }
    }

}
