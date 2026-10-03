extends "res://tools/duel_soak.gd"
## The Mirage block (Pack 8) through the LIVE duel screen: the same DuelScreen
## and the same human-seat fuzzer as the base soak (tools/duel_soak.gd), with
## decks built around phasing, flash (the keyword, the Mirage flash rider and
## Winding Canyons' grant), flanking and Circling Vultures' discard — so the
## phased-out board, the CR 514.3a cleanup window and the new choice flows
## are played whole, by both seats, under either rules profile. Only the
## decks and the in-memory pack selection differ from the base soak.
##
## Requires the real local Pack-8-Mirage-Block.zip and the isolated
## shandalar_test profile (tools/runtime.sh `shandalar_test_profile`); writes
## no player settings and no Elo.
##
##   . tools/runtime.sh; shandalar_find_godot; shandalar_find_timeout
##   shandalar_test_profile
##   xvfb-run -a "$SHANDALAR_TIMEOUT" -k 5 900 "$GODOT" --path . \
##       -s res://tools/pack_8_ui_soak.gd -- --rules modern --count 3 --mode both --pace 0
##   (repeat with --rules fifth)

const SPECS := [
	["Island", 24, [], [
		"Merfolk Raiders", "Teferi's Drake", "Teferi's Imp", "Sandbar Crocodile",
		"Shimmering Efreet", "Knight of the Mists", "Soar", "Mystic Veil",
		"Tolarian Drake"]],
	["Plains", 24, [], [
		"Femeref Knight", "Zhalfirin Knight", "Benalish Knight", "Mtenda Herder",
		"Knight of Valor", "Teferi's Honor Guard", "Ward of Lights", "Parapet",
		"Relic Ward"]],
	["Forest", 22, ["Winding Canyons", "Winding Canyons"], [
		"King Cheetah", "Armor of Thorns", "Spider Climb", "Jolrael's Centaur",
		"Katabatic Winds", "Grizzly Bears", "Giant Growth", "Llanowar Elves",
		"War Mammoth"]],
	["Mountain", 24, [], [
		"Burning Shield Askari", "Searing Spear Askari", "Suq'Ata Lancer",
		"Telim'Tor", "Lightning Reflexes", "Lightning Bolt", "Hill Giant",
		"Gray Ogre", "Bösium Strip"]],
	["Swamp", 24, [], [
		"Cadaverous Knight", "Fallen Askari", "Shadow Rider", "Circling Vultures",
		"Grave Servitude", "Necromancy", "Black Knight", "Terror",
		"Drudge Skeletons"]],
]


func _configure_decks(config: DuelConfig, _first: String, _second: String) -> void:
	if not OS.has_feature("shandalar_test"):
		push_error("Pack 8 UI soak requires the isolated shandalar_test profile")
		quit(3)
		return
	Settings.set_value("enabled_card_packs", ["pack-8"], false)
	root.get_node("CardPacks")._configure_registry()
	CardRegistry.ensure_loaded()
	if not CardRegistry.has_card("Merfolk Raiders"):
		push_error("Pack 8 UI soak requires the real local Pack-8-Mirage-Block.zip")
		quit(3)
		return
	config.decks = []
	config.player_names = []
	config.printings = [{}, {}]
	for seat in 2:
		var spec: Array = SPECS[(_index + seat) % SPECS.size()]
		var deck: Array[String] = []
		for _n in int(spec[1]): deck.append(String(spec[0]))
		for name in spec[2]: deck.append(String(name))
		for name in spec[3]:
			if not CardRegistry.has_card(String(name)):
				push_error("Pack 8 UI soak: no card named %s" % name)
				quit(3)
				return
			for _n in 4: deck.append(String(name))
		config.decks.append(deck)
		config.player_names.append("Mirage " + String(spec[0]))
