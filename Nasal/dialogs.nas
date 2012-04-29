var Radio = gui.Dialog.new("/sim/gui/dialogs/radios/dialog",
        "Aircraft/Citation-Bravo/Systems/tranceivers.xml");
var ap_settings = gui.Dialog.new("/sim/gui/dialogs/autopilot/dialog",
        "Aircraft/Citation-Bravo/Systems/autopilot-dlg.xml");
var options = gui.Dialog.new("/sim/gui/dialogs/options/dialog",
        "Aircraft/Citation-Bravo/Systems/options.xml");
var mc800 = gui.Dialog.new("/sim/gui/dialogs/mc800/dialog",
        "Aircraft/Citation-Bravo/Systems/mc800dlg.xml");

gui.menuBind("radio", "dialogs.Radio.open()");
gui.menuBind("autopilot-settings", "dialogs.ap_settings.open()");
