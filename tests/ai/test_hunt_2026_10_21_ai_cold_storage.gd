extends GameTest
## COLD STORAGE AND THE SWEEPER THAT DOES NOT KILL (bug hunt 2026-10-21, ai).
##
## Cold Storage — "{3}: Exile target creature you control" — stores the
## creature THEIR removal on the stack is aimed at ([method
## TempestTactics.stash_save]). A sweeper counted as aimed at every
## creature of ours as soon as its scope reached our side, whatever it
## destroyed and however much it dealt: with Cold Storage, Serra Angel and
## three Plains, the Wizard stored the Angel in response to a Pyroclasm
## (2 damage to a 4/4) and to a Shatterstorm — which spares the Angel and
## destroys the Storage, so the Angel stayed in exile for good.
##
## The pilot's own death rule decides now ([method AiPlayer._sweep_kills]),
## and a Storage the same sweep destroys stores nothing. A Wrath of God is
## still answered (the control).

const TT := preload("res://engine/ai/tempest_tactics.gd")


func before_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, id in ["pack-3", "pack-9"])


func after_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func after_each() -> void:
	g = null


## Their [param spell] on the stack in their main phase; our Cold Storage,
## Serra Angel and three Plains (and [param extra], when named); seat 0
## holds priority. What [method TempestTactics.stash_save] does.
func _answer(spell_name: String, extra := "") -> String:
	before_each()
	put_battlefield(0, "Cold Storage")
	put_battlefield(0, "Serra Angel")
	for n in 3: put_battlefield(0, "Plains")
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	var guard := 0
	while not (g.active_player == 1 and Mtg.is_main_step(g.current_step())) and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)
	var spell := give_hand(1, spell_name)
	for colour in [Mtg.ManaColor.W, Mtg.ManaColor.R, Mtg.ManaColor.G, Mtg.ManaColor.C]:
		add_mana(1, colour, 4)
	assert_ok(g.cast_spell(1, spell, []))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	return TT.stash_save(g, ai)


func test_shatterstorm_is_not_answered() -> void:
	assert_eq(_answer("Shatterstorm"), "", "it spares the Angel and takes the Storage")


func test_a_pyroclasm_the_angel_survives_is_not_answered() -> void:
	assert_eq(_answer("Pyroclasm"), "", "two damage to a 4/4")


func test_tranquility_is_not_answered() -> void:
	assert_eq(_answer("Tranquility"), "", "it destroys enchantments")


## THE CONTROL: a Wrath of God kills the Angel and spares the Storage.
func test_a_wrath_is_still_answered() -> void:
	assert_string_contains(_answer("Wrath of God"), "Serra Angel into storage")
