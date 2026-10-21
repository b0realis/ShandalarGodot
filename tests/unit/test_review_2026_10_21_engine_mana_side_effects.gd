extends GameTest
## Whole-project review of 2026-10-21, engine-4 — WHAT A MANA ABILITY'S
## SIDE EFFECT WRITES IS UNMADE WITH THE REST OF A SEARCH.
##
## What was wrong: a mana ability never uses the stack (CR 605.3a), so it
## never passes MtgGame._rec_resolution, which is what records a card
## script's hand-written state for the search journal. MtgGame.tap_for_mana
## ran `ability.side_effect` with nothing recorded, and Gem Bazaar's "then
## choose a random color" writes the land's memory by hand: a search that
## tapped it (the 0.50.39 combo walk does, with an untapper on the board)
## put back the tap and the random stream but not the new colour. The real
## Bazaar then showed — and made — a different colour without having been
## tapped. tap_for_mana now records what a side effect can change (the
## source whole, and the per-turn tables a resolution's are recorded for)
## before running it, for every card rather than for the Bazaar alone.
## The owner's ruling on the review: "All!".

const CardCombos := preload("res://engine/ai/card_combos.gd")


func before_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, true)


func after_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)


# ------------------------------------------------------------- Gem Bazaar --

func test_a_searched_gem_bazaar_tap_leaves_its_colour_alone() -> void:
	var bazaar := put_battlefield(0, "Gem Bazaar")
	resolve_stack()   # its own "comes into play" roll
	bazaar.memory["color"] = Mtg.ManaColor.R
	g.recalculate()
	var changed := 0
	for i in 8:
		var mark := g.make_mark()
		assert_ok(g.tap_for_mana(0, bazaar))
		g.unmake_to(mark)
		g.end_search()
		if int(bazaar.memory.get("color", -1)) != Mtg.ManaColor.R:
			changed += 1
		bazaar.memory["color"] = Mtg.ManaColor.R
	assert_false(bazaar.tapped, "the tap itself is unmade")
	assert_eq(changed, 0, "the reroll is unmade too")


func test_the_combo_walk_leaves_a_gem_bazaar_its_colour() -> void:
	# The real AI search: the combo walk adds lands' mana abilities to its
	# moves when an untapper is on the board (Ley Druid: "{T}: Untap target
	# land") and taps them under make_mark / unmake_to.
	var bazaar := put_battlefield(0, "Gem Bazaar")
	put_battlefield(0, "Ley Druid")
	resolve_stack()
	var drifted := 0
	for colour in [Mtg.ManaColor.R, Mtg.ManaColor.G, Mtg.ManaColor.U, Mtg.ManaColor.B]:
		bazaar.memory["color"] = colour
		g.recalculate()
		CardCombos.find_loop(g, 0, {}, 200)
		if int(bazaar.memory.get("color", -1)) != colour:
			drifted += 1
	assert_false(bazaar.tapped, "the walk's taps are unmade")
	assert_eq(drifted, 0, "the walk must not change the Bazaar's colour")


func test_a_real_tap_still_rerolls_the_colour() -> void:
	# The fix records; it must not stop the reroll the card prints.
	var bazaar := put_battlefield(0, "Gem Bazaar")
	resolve_stack()
	var rolled := {}
	for i in 12:
		bazaar.memory["color"] = Mtg.ManaColor.R
		bazaar.tapped = false
		g.recalculate()
		assert_ok(g.tap_for_mana(0, bazaar))
		rolled[int(bazaar.memory.get("color", -1))] = true
	assert_gt(rolled.size(), 1, "twelve real taps roll more than one colour")


# ------------------------------------------- every side effect in the pool --

## Every mutable field, as [GameSnapshot] defines "mutable" — the differ
## tests/ai/test_undo_log.gd pins the journal with, in brief.
func _capture() -> Array:
	var snap := GameSnapshot.take(g)
	var out: Array = []
	for i in snap._objects.size():
		var obj: Object = snap._objects[i]
		var props: Array = snap._props[i]
		var values: Array = snap._values[i]
		var k := 0
		for group in [props[0], props[1]]:
			for name in group:
				if name != &"undo_log" and name != &"journal":
					out.append([obj, name, _deep(values[k])])
				k += 1
	out.append([g.rng, &"state", g.rng.state])
	snap.restore()
	return out


static func _deep(value: Variant) -> Variant:
	var t := typeof(value)
	if t == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	if t == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	if t >= TYPE_PACKED_BYTE_ARRAY:
		return value.duplicate()
	return value


func _drift(before: Array) -> Array:
	var bad: Array = []
	for row in before:
		var obj: Object = row[0]
		var name: StringName = row[1]
		if not _same(obj.get(name), row[2]):
			bad.append("%s.%s" % [obj.get_script().get_global_name(), name])
	return bad


static func _same(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	if ta != typeof(b):
		return false
	if ta == TYPE_ARRAY:
		var aa := a as Array
		var bb := b as Array
		if aa.size() != bb.size():
			return false
		for i in aa.size():
			if not _same(aa[i], bb[i]):
				return false
		return true
	if ta == TYPE_DICTIONARY:
		var ad := a as Dictionary
		var bd := b as Dictionary
		if ad.size() != bd.size():
			return false
		for k in ad:
			if not bd.has(k) or not _same(ad[k], bd[k]):
				return false
		return true
	return a == b


func test_every_mana_side_effect_in_the_pool_round_trips() -> void:
	# Not the Bazaar alone: every card whose mana ability has a side effect
	# (pain, "doesn't untap", depletion and mining counters, a delayed draw,
	# a delayed sacrifice or control change, a return at the next untap) is
	# tapped under a mark and unmade, and the game must be exactly what it
	# was. Three Forests stand by for the costs some of them ask.
	var tried: Array[String] = []
	for card_name in CardRegistry.all_names():
		var data := CardRegistry.get_card(String(card_name))
		if data == null:
			continue
		for index in data.mana_abilities.size():
			if not data.mana_abilities[index].side_effect.is_valid():
				continue
			before_each()
			for n in 3:
				put_battlefield(0, "Forest")
			var inst := put_battlefield(0, String(card_name))
			resolve_stack()
			if inst.zone != Mtg.Zone.BATTLEFIELD:
				gut.p("%s: did not stay on the battlefield, not tried" % card_name)
				continue
			inst.summoning_sick = false
			inst.tapped = false   # the lands that enter tapped (Caldera Lake)
			g.recalculate()
			add_mana(0, Mtg.ManaColor.C, 2)
			var before := _capture()
			var mark := g.make_mark()
			var why := g.tap_for_mana(0, inst, index)
			if why != "":
				g.unmake_to(mark)
				g.end_search()
				gut.p("%s #%d: refused ('%s'), not tried" % [card_name, index, why])
				continue
			g.unmake_to(mark)
			assert_eq(_drift(before), [], "%s #%d: the search left state behind" % [card_name, index])
			g.end_search()
			if not tried.has(String(card_name)):
				tried.append(String(card_name))
	gut.p("tried: %s" % ", ".join(PackedStringArray(tried)))
	assert_true(tried.has("Gem Bazaar"), "the finding's own card is among them")
	assert_gt(tried.size(), 5, "the sweep reaches the pool's side effects")
