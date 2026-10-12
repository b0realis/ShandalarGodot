extends GameTest
## THE KAROO PAYS WHERE IT FITS (robustness campaign 2026-10-12, b5-7).
##
## [method ManaPlanner.plan_from] planned over the plain sources first and
## reached for a source that makes two different mana at once — a Karoo's
## {C}{G} — only when they could not pay. So the Karoo was always the LAST
## source spent in a turn, and the last cost of a turn is usually the
## smallest: Jungle Troll paid with Forest, Mountain and Forest, then the
## Mwonvuli Ooze's {G} from the Jungle Basin, and its {C} burned (the P8
## Karoo deck burned 147 points in 400 Lab games, 65 of the burns right
## after a cast). A coupled source whose whole output the cost absorbs —
## nothing left over — is now spent there, and the single sources stay for
## the next cost. A cost it does not fit exactly plans as before.


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _burned(seat: int) -> Array:
	var burned := [0]
	g.event_occurred.connect(func(e: GameEvent) -> void:
		if e.type == Mtg.EventType.MANA_BURN and int(e.data.get("player", -1)) == seat:
			burned[0] += int(e.data.get("amount", 0)))
	return burned


## An untapped Jungle Basin ({T}: Add {C}{G}) for seat 0.
func _basin() -> CardInstance:
	var forest := put_battlefield(0, "Forest")
	var basin := put_battlefield(0, "Jungle Basin")
	resolve_stack()   # the Basin returns the Forest
	if forest.zone == Mtg.Zone.HAND:
		g.discard_cards(0, [forest])
	basin.tapped = false
	return basin


func _taps(plan: Array) -> Array:
	var names: Array = []
	for step in plan:
		if step[0] != null:
			names.append((step[0] as CardInstance).data.card_name)
	names.sort()
	return names


func test_a_two_mana_cost_takes_the_karoo_whole() -> void:
	var basin := _basin()
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	var plan := ManaPlanner.plan(g, 0, ManaCost.parse("{1}{G}"), 0)
	assert_eq(_taps(plan), ["Jungle Basin"], "the Basin's {C}{G} is {1}{G} exactly")
	assert_eq(ManaPlanner.plan(g, 0, ManaCost.parse("{G}"), 0).size(), 1)
	assert_eq(_taps(ManaPlanner.plan(g, 0, ManaCost.parse("{G}"), 0)), ["Forest"],
		"a one-mana cost does not take the Basin: its {C} would be left over")
	assert_eq(basin.zone, Mtg.Zone.BATTLEFIELD)


func test_a_cost_the_karoo_does_not_fit_plans_as_before() -> void:
	_basin()
	put_battlefield(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	# {G}{G}: the Basin makes one {G}; Forest + Basin is {G}{G}{C} — the
	# conversion fallback's answer, unchanged.
	var plan := ManaPlanner.plan(g, 0, ManaCost.parse("{G}{G}"), 0)
	assert_false(plan.is_empty(), "still payable")


func test_troll_and_ooze_burn_nothing() -> void:
	# The Lab's turn (p8_charms v p8_karoo, seed 81033): Forest, Forest,
	# Mountain and a Jungle Basin; Jungle Troll ({1}{R}{G}) and Mwonvuli
	# Ooze ({G}) cast in the same main phase.
	for preset in ["modern_mana_burn", "fifth"]:
		before_each()
		g.rules.set_preset(preset)
		var p := AiProfile.wizard()
		p.mistake_chance = 0.0
		p.develops_late = false
		var ai := AiPlayer.new(0, p)
		g.set_agent(0, ai)
		_basin()
		put_battlefield(0, "Forest")
		put_battlefield(0, "Forest")
		put_battlefield(0, "Mountain")
		var troll := give_hand(0, "Jungle Troll")
		var ooze := give_hand(0, "Mwonvuli Ooze")
		advance_to_step(Mtg.Step.MAIN1)
		var burned := _burned(0)
		var lines: Array = []
		for k in 8:
			if g.current_step() != Mtg.Step.MAIN1 or g.priority_player != 0:
				break
			var did := ai.act(g)
			lines.append(did)
			resolve_stack()
			if did == "pass" or did == "":
				break
		var guard := 0
		while g.current_step() == Mtg.Step.MAIN1 and guard < 20:
			_advance_once()
			guard += 1
		assert_eq(troll.zone, Mtg.Zone.BATTLEFIELD, "%s: %s" % [preset, lines])
		assert_eq(ooze.zone, Mtg.Zone.BATTLEFIELD, "%s: %s" % [preset, lines])
		assert_eq(burned[0], 0, "%s: both paid exactly (%s)" % [preset, lines])
