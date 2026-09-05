extends GameTest
## DAMAGE AS AN OBJECT (docs/duel-todo.md §6.8, slice 1).
##
## `MtgGame.deal_damage` is now two halves — a planning half that builds a
## [DamagePacket] and a landing half that runs it through the prevention
## gates — and every damage event carries its packet out on the
## `DAMAGE_DEALT` event. These tests pin the packet's own arithmetic and
## the two things the split makes visible for the first time: HOW MUCH WAS
## PREVENTED, and which damage is the SAME damage (the merge rule the
## Manabarbs ruling states).
##
## The rest of the suite is this slice's real pin: with no window open the
## two halves run back to back and every existing damage test still passes.


func _packets_from(events: Array) -> Array:
	var out: Array = []
	for e in events:
		if e.type == Mtg.EventType.DAMAGE_DEALT:
			out.append(e.data["packet"])
	return out


func _watch() -> Array:
	var seen: Array = []
	g.event_occurred.connect(func(e: GameEvent) -> void: seen.append(e))
	return seen


# ------------------------------------------------ the packet's own contract --

func test_every_damage_event_carries_its_packet() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	var seen := _watch()
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	var packets := _packets_from(seen)
	assert_eq(packets.size(), 1, "one damage event, one packet")
	var p: DamagePacket = packets[0]
	assert_eq(p.amount, 3)
	assert_eq(p.prevented, 0)
	assert_eq(p.remaining(), 3)
	assert_false(p.is_combat, "a Bolt is not combat damage")
	assert_false(p.from_redirect)
	assert_eq(p.source_id(), bolt.id, "the packet knows its source")
	assert_eq(p.target.instance_id, bear.id)


func test_a_packet_records_how_much_was_prevented() -> void:
	# Nothing in the engine could say this before: deal_damage returned the
	# amount DEALT and threw away the amount stopped. The 1997 window needs
	# the difference, because a partly-prevented packet is still targetable.
	var wurm := put_battlefield(0, "Craw Wurm")   # 6/4
	var salve := give_hand(0, "Healing Salve")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, salve, [TargetRef.player(1)], 0, 1))
	resolve_stack()
	var seen := _watch()
	run_combat([wurm.id])
	var packets := _packets_from(seen)
	assert_eq(packets.size(), 1)
	var p: DamagePacket = packets[0]
	assert_eq(p.amount, 6, "the packet remembers what it WAS")
	assert_eq(p.prevented, 3, "Healing Salve's pool ate three of the six")
	assert_eq(p.remaining(), 3)
	assert_true(p.is_combat)
	assert_eq(g.players[1].life, 17)


func test_packet_ids_are_never_reused() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var one := give_hand(0, "Lightning Bolt")
	var two := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R, 2)
	var seen := _watch()
	assert_ok(g.cast_spell(0, one, [TargetRef.card(bear)]))
	resolve_stack()
	assert_ok(g.cast_spell(0, two, [TargetRef.player(1)]))
	resolve_stack()
	var packets := _packets_from(seen)
	assert_eq(packets.size(), 2)
	assert_ne(packets[0].id, packets[1].id,
		"a TargetRef names damage by id — reusing one would re-point it")


func test_prevent_never_takes_more_than_is_left() -> void:
	# CR 615.4: a prevention effect that offers more than the packet has
	# only spends what it covers. The window leans on this — a 3-point
	# Healing Salve spread over two 1-point packets must have 1 left.
	var p := DamagePacket.new()
	p.amount = 2
	assert_eq(p.prevent(5), 2, "only two points were there to prevent")
	assert_eq(p.remaining(), 0)
	assert_eq(p.prevent(1), 0, "and nothing is left for a second effect")


# ---------------------------------------------------- what is the SAME damage --

func test_two_packets_from_one_source_to_one_victim_are_the_same_damage() -> void:
	# The Manabarbs ruling: "damage ... during a damage prevention step is
	# added to an existing Manabarbs damage packet (if there is one), so a
	# single use of the CoP would target and prevent all of that damage."
	var barbs := put_battlefield(0, "Grizzly Bears")
	var a := DamagePacket.new()
	a.source = barbs
	a.target = TargetRef.player(1)
	a.amount = 1
	var b := DamagePacket.new()
	b.source = barbs
	b.target = TargetRef.player(1)
	b.amount = 2
	assert_true(a.matches(b))
	a.absorb(b)
	assert_eq(a.amount, 3, "one packet of three, not two packets")


func test_different_victims_are_different_damage() -> void:
	var barbs := put_battlefield(0, "Grizzly Bears")
	var bear := put_battlefield(1, "Grizzly Bears")
	var to_player := DamagePacket.new()
	to_player.source = barbs
	to_player.target = TargetRef.player(1)
	var to_bear := DamagePacket.new()
	to_bear.source = barbs
	to_bear.target = TargetRef.card(bear)
	assert_false(to_player.matches(to_bear))
	assert_false(to_bear.matches(to_player))


func test_first_strike_damage_is_not_the_normal_waves_packet() -> void:
	# The two damage-dealing steps each get their own prevention step
	# (Duel.hlp, Combat: "At this point, there is a damage prevention
	# step... At this point, there is ANOTHER damage prevention step"), so
	# a double striker's two hits never merge.
	var knight := put_battlefield(0, "Grizzly Bears")
	var first := DamagePacket.new()
	first.source = knight
	first.target = TargetRef.player(1)
	first.is_combat = true
	var spell := DamagePacket.new()
	spell.source = knight
	spell.target = TargetRef.player(1)
	spell.is_combat = false
	assert_false(first.matches(spell),
		"combat damage and ability damage are different packets")


# ------------------------------------------------------------- the fork itself --

func test_the_window_is_a_declared_fork_defaulting_to_modern() -> void:
	assert_false(g.rules.damage_prevention_window,
		"a fresh engine plays modern Magic: no prevention step")
	var found := false
	for fork in RulesOptions.FORKS:
		if fork["key"] == "damage_prevention_window":
			found = true
			assert_true(bool(fork["fifth_value"]), "1997 HAS the step")
			assert_string_contains(fork["source"], "Duel.hlp")
	assert_true(found, "the window is registered in RulesOptions.FORKS")


func test_no_window_means_nothing_is_ever_pending() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(g.damage_pending.size(), 0,
		"damage_pending is empty outside a window")
