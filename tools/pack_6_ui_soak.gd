extends "res://tools/duel_soak.gd"
## Portal choice/targeting smoke test through the real human/demo UI driver.
## Same arguments as duel_soak.gd; requires an isolated test profile and Pack 6.
const SPECS := [
	["Island", ["Cloud Pirates", "Cloud Spirit", "Phantom Warrior", "Time Ebb", "Man-o'-War", "Omen", "Mystic Denial", "Theft of Dreams", "Touch of Brilliance"]],
	["Mountain", ["Goblin Bully", "Raging Goblin", "Hulking Goblin", "Hill Giant", "Volcanic Hammer", "Spitting Earth", "Fire Imp", "Forked Lightning", "Blaze"]],
]
func _configure_decks(config: DuelConfig, _first: String, _second: String) -> void:
	if not OS.has_feature("shandalar_test"):
		push_error("Portal UI soak requires the isolated shandalar_test profile")
		quit(3)
		return
	Settings.set_value("enabled_card_packs", ["pack-6"], false)
	root.get_node("CardPacks")._configure_registry()
	CardRegistry.ensure_loaded()
	if not CardRegistry.has_card("Phantom Warrior"):
		push_error("Portal UI soak requires Pack-6-Portal.zip")
		quit(3)
		return
	config.decks = []
	config.player_names = []
	config.printings = [{}, {}]
	for seat in 2:
		var spec: Array = SPECS[(_index + seat) % SPECS.size()]
		var deck: Array[String] = []
		for n in 24: deck.append(spec[0])
		for name in spec[1]:
			for n in 4: deck.append(name)
		config.decks.append(deck)
		config.printings[seat][spec[0]] = "por:203" if spec[0] == "Island" else "por:211"
		config.player_names.append("Portal " + spec[0])
