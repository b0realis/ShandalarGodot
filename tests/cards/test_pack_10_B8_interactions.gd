extends GameTest
## Pack 10 (the Urza block), batch B8: the B8 artifacts against older cards
## (docs/adding-card-packs.md, INVENTORY risks) — Memory Jar's end-step
## discard is an effect's discard that an opponent's ability causes
## (Megrim from Pack 9, Metrognome, Library of Leng); Lifeline returns what
## a sacrifice outlet ate; Urza's Armor against Pestilence; Scrapheap with
## Claws of Gix. Packs 9 and 10 are enabled together.

func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func _on_library_top(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.LIBRARY
	g.players[pid].library.append(inst)
	return inst

func _named(pid: int, card_name: String) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if i.data.card_name == card_name: out.append(i)
	return out

func _jar_through_the_end_step(pid: int) -> void:
	var jar := put_battlefield(pid, "Memory Jar")
	assert_ok(g.activate_ability(pid, jar, 0))
	resolve_stack()
	advance_to_step(Mtg.Step.END)
	resolve_stack()


func test_memory_jar_and_megrim_punish_the_opponents_seven_discards() -> void:
	put_battlefield(0, "Megrim")
	_jar_through_the_end_step(0)
	assert_eq(g.players[1].life, 6, "seven discards an opponent made: 7 x 2")
	assert_eq(g.players[0].life, 20, "your own discards are not an opponent's")

func test_memory_jar_makes_the_opponents_drawn_metrognome_into_gnomes() -> void:
	_on_library_top(1, "Metrognome")
	_on_library_top(0, "Metrognome")
	_jar_through_the_end_step(0)
	assert_eq(_named(1, "Gnome").size(), 4, "discarded by the Jar's controller's delayed trigger")
	assert_eq(_named(0, "Gnome").size(), 0, "the Jar's controller caused its own discard")

func test_memory_jar_discard_is_an_effect_library_of_leng_may_keep() -> void:
	put_battlefield(1, "Library of Leng")
	var bolt := _on_library_top(1, "Lightning Bolt")
	var kept := give_hand(1, "Giant Growth")
	_jar_through_the_end_step(0)
	assert_eq(bolt.zone, Mtg.Zone.LIBRARY, "a spell goes back on top (the Library's hint)")
	assert_eq(g.players[1].library[-1], bolt)
	assert_eq(kept.zone, Mtg.Zone.HAND, "and the exiled hand comes back")
	assert_eq(g.players[1].graveyard.size(), 6, "the six Forests")

func test_lifeline_returns_the_creature_a_claws_of_gix_ate() -> void:
	put_battlefield(0, "Lifeline")
	var claws := put_battlefield(0, "Claws of Gix")
	var bears := put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Hill Giant")
	g.set_agent(0, BearsFirst.new())
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.activate_ability(0, claws, 0))
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[0].life, 21)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "back at the next end step")

## Names the Grizzly Bears whenever they are offered.
class BearsFirst extends DecisionAgent:
	func answer_card(_g: MtgGame, _pid: int, candidates: Array[CardInstance], _prompt: String) -> CardInstance:
		for c in candidates:
			if c.data.card_name == "Grizzly Bears": return c
		return null if candidates.is_empty() else candidates[0]

func test_urzas_armor_shrugs_off_pestilence() -> void:
	put_battlefield(0, "Urza's Armor")
	var pest := put_battlefield(1, "Pestilence")
	put_battlefield(1, "Hill Giant")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(1, pest, 0))
	resolve_stack()
	assert_eq(g.players[0].life, 20, "1 - 1")
	assert_eq(g.players[1].life, 19)

func test_scrapheap_and_claws_of_gix_turn_an_artifact_into_two_life() -> void:
	put_battlefield(0, "Scrapheap")
	var claws := put_battlefield(0, "Claws of Gix")
	add_mana(0, Mtg.ManaColor.C, 1)
	# Whichever artifact the Claws eat — itself or the Scrapheap, which
	# hears its own trip — it goes to your graveyard from the battlefield.
	assert_ok(g.activate_ability(0, claws, 0))
	resolve_stack()
	assert_eq(g.players[0].life, 22, "1 from the Claws, 1 from the Scrapheap")
