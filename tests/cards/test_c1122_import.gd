extends GameTest
## A GAME CARD AS A DRAFT ([CardImport]): the spec that builds the same
## card as far as the vocabulary reaches — exact where every clause is one
## the tables write, an honest part where one is not, and never a crash or
## a broken spec over the whole pool.


## The clauses of a rules text as the two sides are compared: sentences
## and keyword parts, normalised, sorted.
func _clauses(text: String, name: String) -> Array:
	var out: Array = []
	for line in text.split("\n"):
		for sentence in CardImport._sentences(CardImport._strip_reminders(line)):
			var parts: Array = [sentence]
			# A line of keywords ("Flying, first strike") is its keywords.
			if not sentence.contains(":") and not sentence.contains("\"") and Array(sentence.split(",")).all(
					func(part: String) -> bool: return part.strip_edges().split(" ").size() <= 3):
				parts = Array(sentence.split(","))
			for part in parts:
				var said := CardImport.norm(String(part), name)
				if said != "":
					out.append(said)
	out.sort()
	return out


func _draft(card_name: String) -> Dictionary:
	var data := CardRegistry.get_card(card_name)
	assert_true(CardImport.can_start(data), card_name + " can start a draft")
	var result := CardImport.from_card(data)
	assert_eq(CardImport.problems_of(result["spec"]), [] as Array[String], card_name)
	return result


func _exact(card_name: String) -> Dictionary:
	var result := _draft(card_name)
	var data := CardRegistry.get_card(card_name)
	assert_eq(result["dropped"], [] as Array[String], card_name + ": nothing dropped")
	assert_eq(result["notes"], [] as Array[String], card_name + ": nothing approximated")
	assert_true(result["exact"], card_name + " is exact")
	assert_eq(CardImport.quality(data), 100, card_name)
	var spec: Dictionary = result["spec"]
	assert_eq(_clauses(CommunityCard.rules_text(spec), String(spec["name"])), _clauses(data.oracle_text, card_name),
		card_name + ": the text it writes is the card's")
	var built := CommunityCard.build(spec)
	assert_eq([built.card_name, built.cost.text if not data.is_land() else "", built.types, built.power, built.toughness],
		[data.card_name, data.cost.text if not data.is_land() else "", data.types, data.power, data.toughness], card_name)
	for key in ["flavor", "set_name", "artist"]:
		assert_eq(String(spec[key]), "", key)
	assert_false(spec.has("look"), "no picture is copied")
	return result


func test_cards_the_vocabulary_says_whole_are_exact() -> void:
	for card_name in ["Grizzly Bears", "Serra Angel", "Lightning Bolt", "Counterspell", "Llanowar Elves",
			"Giant Growth", "Disenchant", "Prodigal Sorcerer", "Juggernaut", "Holy Strength", "Hill Giant",
			"White Knight", "Shatter", "Stream of Life"]:
		if CardRegistry.has_card(card_name):
			_exact(card_name)
	var angel: Dictionary = _exact("Serra Angel")["spec"]
	assert_eq(angel["keywords"], ["flying", "vigilance"])
	assert_eq([angel["cost"], angel["power"], angel["toughness"], angel["types"]], ["{3}{W}{W}", 4, 4, ["creature"]])
	var bolt: Dictionary = _exact("Lightning Bolt")["spec"]
	assert_eq(bolt["abilities"], [{"kind": "spell", "effects": [{"effect": "damage", "target": "any", "amount": 3}]}])
	var elves: Dictionary = _exact("Llanowar Elves")["spec"]
	assert_eq(elves["abilities"], [{"kind": "mana", "color": "green", "amount": 1}])
	var tim: Dictionary = _exact("Prodigal Sorcerer")["spec"]
	assert_eq(tim["abilities"][0]["tap"], true)
	assert_eq(tim["abilities"][0]["effects"], [{"effect": "damage", "target": "any", "amount": 1}])
	var jug: Dictionary = _exact("Juggernaut")["spec"]
	assert_eq(jug["keywords"], ["must_attack"])
	assert_eq(jug["rules"], {"no_walls": true})
	var strength: Dictionary = _exact("Holy Strength")["spec"]
	assert_eq(strength["abilities"], [{"kind": "enchant", "enchant": "creature", "power": 1, "toughness": 2}])


func test_a_land_a_legend_and_a_you_may_arrival() -> void:
	var forest := _draft("Forest")
	assert_eq(forest["spec"]["types"], ["land"])
	assert_eq(forest["spec"]["subtypes"], ["forest"])
	assert_eq(forest["spec"]["cost"], "")
	assert_eq(forest["dropped"], [] as Array[String])
	assert_false(forest["exact"], "its basic supertype is said, not kept")
	assert_true(String(forest["notes"][0]).contains("supertype"))
	assert_true(CommunityCard.build(forest["spec"]).mana_abilities.size() == 1, "a Forest taps for green")
	if CardRegistry.has_card("Gravedigger"):
		var digger: Dictionary = _exact("Gravedigger")["spec"]
		assert_eq(digger["abilities"], [{"kind": "trigger", "when": "enters", "choice": "may",
			"effects": [{"effect": "raise", "target": "creature_card"}]}])


func test_a_clause_the_vocabulary_lacks_is_dropped_in_the_cards_words() -> void:
	# One sentence of a spell kept, its rider listed.
	var wrath := _draft("Wrath of God")
	assert_eq(wrath["kept"], ["Destroy all creatures."])
	assert_eq(wrath["dropped"], ["They can't be regenerated."])
	assert_false(wrath["exact"])
	assert_eq(wrath["spec"]["abilities"], [{"kind": "spell", "effects": [{"effect": "destroy_all", "target": "creatures"}]}])
	var data := CardRegistry.get_card("Wrath of God")
	assert_true(CardImport.quality(data) > 0 and CardImport.quality(data) < 100)
	# A keyword kept, a trigger the tables do not write dropped whole.
	var specter := _draft("Hypnotic Specter")
	assert_eq(specter["kept"], ["Flying"])
	assert_eq(specter["dropped"].size(), 1)
	assert_true(String(specter["dropped"][0]).begins_with("Whenever this creature deals damage to an opponent"))
	assert_eq(specter["spec"]["keywords"], ["flying"])
	assert_eq(specter["spec"]["abilities"], [])
	# Nothing kept: the frame alone.
	var mine := _draft("Howling Mine")
	assert_eq(mine["kept"], [] as Array[String])
	assert_eq(mine["dropped"].size(), 1)
	assert_eq(CardImport.quality(CardRegistry.get_card("Howling Mine")), 0)
	assert_eq(mine["spec"]["types"], ["artifact"])
	assert_eq(mine["spec"]["cost"], "{2}")


func test_what_no_draft_can_be() -> void:
	assert_false(CardImport.can_start(null))
	assert_false(CardImport.can_start(CardData.new("", "", Mtg.CardType.CREATURE)))
	var ante := CardData.new("Ash Wager", "{B}", Mtg.CardType.SORCERY).oracle("Each player antes a card.\nAnte one more.")
	assert_true(CardImport.can_start(CardData.new("Ash Wager", "{B}", Mtg.CardType.SORCERY).oracle("Draw a card.")))
	ante.oracle("Remove Ash Wager from your deck before playing if you're not playing for ante.")
	assert_false(CardImport.can_start(ante), "an ante card")
	# A block that would make the card no card is taken out and said.
	var odd := CardData.new("Ash Oddity", "{1}{U}", Mtg.CardType.SORCERY).oracle("Counter target spell.")
	var result := CardImport.from_card(odd)
	assert_eq(CommunityCard.problems(result["spec"]), [CardImport.NEEDS_EFFECT] as Array[String],
		"the one problem a draft may have: a spell with no effect yet")
	assert_eq(result["dropped"], ["Counter target spell."])
	assert_true(String(result["notes"][0]).contains("a sorcery cannot counter"))
	assert_true(String(result["notes"][1]).contains("no spell effect yet"))
	assert_false(result["exact"])
	# A name with signs a card's name may not hold is written plain.
	var named := CardImport.from_card(CardData.new("Junún Efreet", "{1}{B}{B}", Mtg.CardType.CREATURE).pt(3, 3))
	assert_eq(named["spec"]["name"], "Junun Efreet")
	assert_false(named["exact"])


func test_synthetic_cards_of_many_shapes_come_back_as_they_were() -> void:
	# A card the generator wrote is read back whole: every clause kept.
	var specs := [
		{"types": ["creature"], "power": 2, "toughness": 2, "keywords": ["flying", "first_strike"], "protection": ["red"],
			"landwalk": ["swamp"], "rules": {"echo": "{2}{R}", "rampage": 2, "shroud": true},
			"abilities": [
				{"kind": "trigger", "when": "dies", "effects": [{"effect": "draw", "amount": 2}, {"effect": "gain_life", "amount": 3}]},
				{"kind": "activated", "cost": "{1}{R}", "tap": true, "sacrifice": true, "timing": "your_turn",
					"effects": [{"effect": "damage", "amount": 2, "target": "creature", "only": "white"}]},
				{"kind": "trigger", "when": "enters", "choice": "may",
					"effects": [{"effect": "damage", "amount": 2, "target": "any"}]},
				{"kind": "trigger", "when": "attacks", "choice": "up_to",
					"effects": [{"effect": "tap", "target": "creature"}]},
				{"kind": "static", "what": "lord", "subtype": "goblin", "power": 1, "toughness": 1, "keywords": ["haste"]},
				{"kind": "mana", "color": "any", "amount": 1}]},
		{"types": ["sorcery"], "cost": "{X}{B}", "abilities": [{"kind": "spell", "effects": [
			{"effect": "discard_random", "x": true, "target": "opponent"},
			{"effect": "token", "amount": 2, "power": 1, "toughness": 1, "color": "black", "subtype": "rat", "ends": "sacrifice"},
			{"effect": "lose_life", "amount": 1, "target": "opponent", "per": "swamp_you"}]}]},
		{"types": ["instant"], "cost": "{1}{G}", "abilities": [{"kind": "modal", "modes": [
			{"effects": [{"effect": "pump", "power": 3, "toughness": 3, "target": "creature", "keywords": ["trample"]}]},
			{"effects": [{"effect": "destroy", "target": "artifact_or_enchantment"}]}]}]},
		{"types": ["enchantment"], "cost": "{G}", "abilities": [
			{"kind": "enchant", "enchant": "creature", "power": 2, "toughness": 0, "keywords": ["trample"]},
			{"kind": "activated", "cost": "", "tap": true, "enchanted": true,
				"effects": [{"effect": "damage", "amount": 1, "target": "any"}]},
			{"kind": "trigger", "when": "attacks", "enchanted": true, "effects": [{"effect": "gain_life", "amount": 2}]},
			{"kind": "trigger", "when": "to_graveyard", "effects": [{"effect": "return_self"}]}]},
		{"types": ["artifact"], "cost": "{3}", "abilities": [
			{"kind": "static", "what": "cost_more", "spell_type": "any", "spell_color": "black", "amount": 2, "who": "opponents"},
			{"kind": "static", "what": "attack_tax", "amount": 2},
			{"kind": "trigger", "when": "each_draw", "effects": [{"effect": "draw", "amount": 1, "target": "that_player"}]}]},
	]
	for n in specs.size():
		var spec: Dictionary = {"format": CommunityCard.FORMAT, "version": 1, "name": "Ash Mirror", "cost": "{1}{R}",
			"rarity": "common"}
		spec.merge(specs[n], true)
		assert_eq(CommunityCard.problems(spec), [] as Array[String], "shape %d is a card" % n)
		var result := CardImport.from_card(CommunityCard.build(spec))
		assert_eq(result["dropped"], [] as Array[String], "shape %d" % n)
		assert_eq(CommunityCard.rules_text(result["spec"]).split("\n"), CommunityCard.rules_text(spec).split("\n"),
			"shape %d reads the same" % n)
		assert_eq(CommunityCard.problems(result["spec"]), [] as Array[String])


func test_the_whole_pool_gives_a_whole_spec_and_quality_agrees() -> void:
	var names := CardRegistry.all_names()
	var started := Time.get_ticks_msec()
	var exact := 0
	var partial := 0
	var frame := 0
	var refused := 0
	var broken: Array = []
	var disagree: Array = []
	var kinds := {}
	for card_name in names:
		var data := CardRegistry.get_card(card_name)
		if not CardImport.can_start(data):
			refused += 1
			continue
		var result := CardImport.from_card(data)
		if not CardImport.problems_of(result["spec"]).is_empty():
			broken.append(card_name)
		# A spell with no effect kept says so; nothing else is ever wrong.
		if CommunityCard.problems(result["spec"]).size() > 0 and not (result["notes"] as Array).any(
				func(note: String) -> bool: return note.contains("no spell effect yet")):
			broken.append(card_name)
		var q := CardImport.quality_of(result)
		if bool(result["exact"]):
			exact += 1
		elif (result["kept"] as Array).is_empty() and not (result["dropped"] as Array).is_empty():
			frame += 1
		else:
			partial += 1
		if (q == 100) != bool(result["exact"]) or (q == 0) != ((result["kept"] as Array).is_empty()
				and not (result["dropped"] as Array).is_empty()):
			disagree.append(card_name)
		for clause in result["dropped"]:
			var said := CardImport.norm(String(clause), card_name)
			var kind := "other"
			if said.contains(": "):
				kind = "activated: " + " ".join(said.get_slice(": ", 1).split(" ").slice(0, 2))
			elif said.begins_with("when") or said.begins_with("at the beginning"):
				kind = "trigger: " + said.get_slice(",", 0)
			else:
				kind = " ".join(said.split(" ").slice(0, 3))
			kinds[kind] = int(kinds.get(kind, 0)) + 1
	var took := Time.get_ticks_msec() - started
	var top := kinds.keys()
	top.sort_custom(func(a: String, b: String) -> bool: return int(kinds[a]) > int(kinds[b]))
	print("IMPORT pool=%d exact=%d partial=%d frame=%d refused=%d ms=%d" % [names.size(), exact, partial, frame,
		refused, took])
	for kind in top.slice(0, 40):
		print("IMPORT dropped %4d  %s" % [int(kinds[kind]), kind])
	assert_eq(broken, [], "every draft passes the checks")
	assert_eq(disagree, [], "quality agrees with exact, partial and frame-only")
	assert_gt(exact, 0)
	assert_lt(took, 60000, "the whole pool in under a minute")
