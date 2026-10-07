extends GameTest
## THE SCRIPT'S OWN SET (whole-game campaign 2026-10-07, w3-3;
## [member CardData.script_set], engine/card_registry.gd `script_set_of`).
##
## The Ice Age and Fallen Empires AI modules asked the DISPLAYED set code
## ("ice" / "fem"), and a reprint pack loads the very same script under its
## own code — Fifth Edition's Necropotence is "5ed" — so with Pack 7 (or
## the Mirage block) as the only provider every one of their readings was
## skipped: Hecatomb cast into our own Bears, Necropotence never activated,
## a discard-cost ability never priced. They now ask the folder the script
## ships in. Each decision below is made twice, Pack 3 / Pack 2 as the
## provider and then Pack 7 alone, and must not change.


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _provider(ids: Array) -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	for id in ids: CardPacks.set_enabled(id, true)
	g = MtgGame.new()
	var filler: Array = []
	for _k in 30: filler.append("Forest")
	g.setup(filler, filler, "P0", "P1", 20, 20, 424242)
	g.start(0)
	advance_to_step(Mtg.Step.MAIN1)


func _ai(on := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.mistake_chance = 0.0
	p.develops_late = false
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _play_main(ai: AiPlayer) -> void:
	var turn := g.turn_number
	for _k in 40:
		if g.game_over or g.turn_number != turn or g.current_step() != Mtg.Step.MAIN1: break
		if g.priority_player == ai.pid:
			var did := ai.act(g)
			if did == "" or did == "pass": break
		else:
			g.pass_priority(g.priority_player)
	resolve_stack()


# ------------------------------------------------------------ the registry --

func test_a_reprint_keeps_its_scripts_set() -> void:
	_provider(["pack-7"])
	var necro := CardRegistry.get_card("Necropotence")
	assert_eq(necro.set_code, "5ed", "displayed as Fifth Edition")
	assert_eq(necro.script_set, "ice", "the script ships in cards/sets/ice/")
	var captain := CardRegistry.get_card("Orcish Captain")
	assert_eq(captain.script_set, "fem")
	_provider(["pack-3"])
	assert_eq(CardRegistry.get_card("Necropotence").set_code, "ice")
	assert_eq(CardRegistry.get_card("Necropotence").script_set, "ice")
	# A base-folder card: its folder is its set.
	assert_eq(CardRegistry.get_card("Lightning Bolt").script_set,
		CardRegistry.get_card("Lightning Bolt").set_code)


func test_script_set_of_reads_the_folder() -> void:
	assert_eq(CardRegistry.script_set_of("res://cards/sets/ice/necropotence.gd", "5ed"), "ice")
	assert_eq(CardRegistry.script_set_of("res://cards/sets/fem/orcish_captain.gd", "mir"), "fem")
	assert_eq(CardRegistry.script_set_of("res://cards/optional/pack_1/chaos_orb.gd", "2ed"), "2ed",
		"a script outside the set folders keeps its displayed code")


# ------------------------------------------------------- the same decisions --

## Hecatomb with four Grizzly Bears and five Swamps: the Ice Age reading
## holds it (sixteen points of body for twelve of Swamp damage).
func _hecatomb() -> Dictionary:
	var ai := _ai()
	for _k in 4: put_battlefield(0, "Grizzly Bears")
	for _k in 5: put_battlefield(0, "Swamp")
	put_battlefield(1, "Grizzly Bears")
	var heca := give_hand(0, "Hecatomb")
	_play_main(ai)
	var bears := 0
	for i in g.players[0].battlefield:
		if i.data.card_name == "Grizzly Bears": bears += 1
	return {"zone": heca.zone, "bears": bears}


func test_hecatomb_reads_the_same_whichever_pack_provides_it() -> void:
	_provider(["pack-3"])
	var ice := _hecatomb()
	_provider(["pack-7"])
	var fifth := _hecatomb()
	assert_eq(fifth, ice, "the same Hecatomb decision whichever pack provides it")
	assert_eq(int(ice["bears"]), 4, "our own Bears are not sacrificed to it")


## Necropotence at 20 life, an empty hand, three Swamps.
func _necro() -> int:
	var ai := _ai()
	put_battlefield(0, "Necropotence")
	for _k in 3: put_battlefield(0, "Swamp")
	_play_main(ai)
	var acts := 0
	for line in g.log_lines:
		if String(line).contains("activates Necropotence"): acts += 1
	return acts


func test_necropotence_reads_the_same_whichever_pack_provides_it() -> void:
	_provider(["pack-3"])
	var ice := _necro()
	_provider(["pack-7"])
	var fifth := _necro()
	assert_gt(ice, 0, "the Ice Age reading digs at 20 life")
	assert_eq(fifth, ice, "the same Necropotence use whichever pack provides it")


## Krovikan Sorcerer's "{T}, Discard a nonblack card: Draw a card" — a
## discard cost only the Ice Age / Fallen Empires scorer prices.
func _sorcerer_available() -> bool:
	var ai := _ai()
	var sorcerer := put_battlefield(0, "Krovikan Sorcerer")
	give_hand(0, "Grizzly Bears")
	give_hand(0, "Giant Growth")
	return ai._ability_available(g, sorcerer, 0, true)


func test_a_discard_cost_is_priced_whichever_pack_provides_it() -> void:
	_provider(["pack-3"])
	var ice := _sorcerer_available()
	_provider(["pack-7"])
	var fifth := _sorcerer_available()
	assert_true(ice, "the Ice Age scorer may pay a discard")
	assert_eq(fifth, ice)


func test_the_fallen_empires_reading_follows_its_script() -> void:
	_provider(["pack-2"])
	var ai := _ai()
	var captain := put_battlefield(0, "Orcish Captain")
	put_battlefield(0, "Mountain")
	var fem: Variant = _fem_option(ai, captain)
	_provider(["pack-7"])
	ai = _ai()
	captain = put_battlefield(0, "Orcish Captain")
	put_battlefield(0, "Mountain")
	assert_eq(captain.data.set_code, "5ed")
	var fifth: Variant = _fem_option(ai, captain)
	assert_true(fem is Dictionary, "the Fallen Empires module reads its Orcish Captain")
	assert_true(fifth is Dictionary, "and still reads it when Pack 7 provides the card")


func _fem_option(ai: AiPlayer, s: CardInstance) -> Variant:
	return preload("res://engine/ai/fallen_empires_tactics.gd").option(g, ai, s, 0, "MAIN")
