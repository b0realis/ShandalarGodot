extends GutTest
## THE VALIDATOR ([CardBalance]): a community card set beside the game's
## own cards by mana value — a usual card is said to fit, a 99/99 for one
## mana, a one-mana bolt for 10 and a hulking cost are flagged, a tiny
## creature for seven is called weak. Suggestions only: nothing refuses.
## Then by color: a creature beside the creatures of its color, and an
## effect rare in its color told plainly — never for a fair, ordinary card.


func _spec(extra: Dictionary) -> Dictionary:
	var spec := {"format": CommunityCard.FORMAT, "version": 1, "name": "Balance Test",
		"cost": "{1}{G}", "types": ["creature"], "power": 2, "toughness": 2, "rarity": "common",
		"abilities": []}
	spec.merge(extra, true)
	assert_eq(CommunityCard.problems(spec), [] as Array[String], "a whole card")
	return spec


func _level(rows: Array[Dictionary], topic: String) -> String:
	for row in rows:
		if String(row["topic"]) == topic:
			return String(row["level"])
	return ""


func test_the_game_s_cards_are_counted() -> void:
	var c := CardBalance.corpus()
	assert_gt(int(c["cards"]), 100, "the pool's cards")
	assert_true((c["size"] as Dictionary).has(2), "two-mana creatures")
	assert_gt(int(c["most_power"]["value"]), 5)
	assert_true(CardBalance.corpus() == c, "counted once per pool")


func test_a_bear_fits_and_a_giant_for_one_mana_does_not() -> void:
	var rows := CardBalance.advice(_spec({}))
	assert_eq(rows[0]["topic"], "Summary")
	assert_eq(rows[0]["level"], CardBalance.OK, str(rows))
	assert_eq(_level(rows, "Size"), CardBalance.OK)
	rows = CardBalance.advice(_spec({"cost": "{G}", "power": 99, "toughness": 99}))
	assert_eq(rows[0]["level"], CardBalance.VERY_HIGH)
	assert_eq(_level(rows, "Size"), CardBalance.VERY_HIGH)
	assert_eq(_level(rows, "Power"), CardBalance.VERY_HIGH)
	assert_eq(_level(rows, "Toughness"), CardBalance.VERY_HIGH)
	rows = CardBalance.advice(_spec({"cost": "{6}{G}", "power": 1, "toughness": 1}))
	assert_eq(_level(rows, "Size"), CardBalance.LOW, "a 1/1 for seven is weak")


func test_a_big_bolt_a_free_spell_and_a_huge_cost_are_flagged() -> void:
	var bolt := _spec({"cost": "{R}", "types": ["instant"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "damage", "amount": 10, "target": "any"}]}]})
	assert_eq(_level(CardBalance.advice(bolt), "Damage"), CardBalance.VERY_HIGH)
	var fair := _spec({"cost": "{R}", "types": ["instant"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "damage", "amount": 2, "target": "any"}]}]})
	assert_eq(_level(CardBalance.advice(fair), "Damage"), CardBalance.OK)
	var free := _spec({"cost": "{0}", "types": ["sorcery"], "abilities": [{"kind": "spell",
		"effects": [{"effect": "draw", "amount": 3}]}]})
	var rows := CardBalance.advice(free)
	assert_eq(_level(rows, "Mana cost"), CardBalance.HIGH)
	assert_eq(_level(rows, "Cards drawn"), CardBalance.VERY_HIGH)
	var vast := _spec({"cost": "{16}", "power": 5, "toughness": 5})
	assert_eq(_level(CardBalance.advice(vast), "Mana cost"), CardBalance.VERY_HIGH)


func test_too_much_mana_and_a_busy_line_are_flagged() -> void:
	var elf := _spec({"cost": "{G}", "power": 1, "toughness": 1, "abilities": [
		{"kind": "mana", "color": "green", "amount": 3}]})
	assert_eq(_level(CardBalance.advice(elf), "Mana"), CardBalance.HIGH, "beyond 9 in 10 of the game's")
	assert_eq(_level(CardBalance.advice(_spec({"cost": "{1}{G}", "power": 1, "toughness": 1, "abilities": [
		{"kind": "mana", "color": "green", "amount": 1}]})), "Mana"), CardBalance.OK, "a mana elf")
	var busy := _spec({"cost": "{B}", "types": ["sorcery"], "abilities": [{"kind": "spell", "effects": [
		{"effect": "draw", "amount": 1}, {"effect": "gain_life", "amount": 1},
		{"effect": "discard", "amount": 1, "target": "opponent"}, {"effect": "mill", "amount": 1, "target": "player"}]}]})
	var level := _level(CardBalance.advice(busy), "Effects")
	assert_true(level in [CardBalance.HIGH, CardBalance.VERY_HIGH], "four things for one mana: %s" % level)


func _thumbs(rows: Array[Dictionary]) -> Array[Dictionary]:
	return rows.filter(func(row: Dictionary) -> bool: return String(row["topic"]) == CardBalance.THUMB_TOPIC)


func test_the_rules_of_thumb_catch_evident_errors_and_leave_fair_cards_be() -> void:
	assert_true(_thumbs(CardBalance.advice(_spec({}))).is_empty(), "a bear")
	assert_true(_thumbs(CardBalance.advice(_spec({"cost": "{3}{W}{W}", "power": 4, "toughness": 4,
		"keywords": ["flying", "vigilance"]}))).is_empty(), "an angel")
	assert_true(_thumbs(CardBalance.advice(_spec({"cost": "{R}", "types": ["instant"], "abilities": [
		{"kind": "spell", "effects": [{"effect": "damage", "amount": 3, "target": "any"}]}]}))).is_empty(), "a bolt")
	var giant := _thumbs(CardBalance.advice(_spec({"cost": "{R}", "power": 40, "toughness": 40,
		"keywords": ["flying", "trample", "haste", "first_strike"]})))
	assert_gte(giant.size(), 4, "size, power, toughness and keywords")
	assert_true(giant.all(func(row: Dictionary) -> bool: return row["level"] == CardBalance.VERY_HIGH))
	var fireball := _thumbs(CardBalance.advice(_spec({"cost": "{R}", "types": ["instant"], "abilities": [
		{"kind": "spell", "effects": [{"effect": "damage", "amount": 6, "target": "any"}]}]})))
	assert_eq(fireball.size(), 1)
	assert_string_contains(String(fireball[0]["text"]), "Goblin Grenade")
	var tower := _thumbs(CardBalance.advice(_spec({"cost": "", "types": ["land"], "abilities": [
		{"kind": "mana", "color": "colorless", "amount": 3}]})))
	assert_eq(tower[0]["level"], CardBalance.VERY_HIGH, "a land tapping for 3")
	var echoed := _thumbs(CardBalance.advice(_spec({"cost": "{2}{G}", "power": 4, "toughness": 4,
		"rules": {"echo": "{2}{G}"}})))
	assert_true(echoed.is_empty(), "echo pays for a 4/4 for three")


# ------------------------------------------------------------- by color --

func _spell(cost: String, type: String, effects: Array) -> Dictionary:
	return _spec({"cost": cost, "types": [type], "abilities": [{"kind": "spell", "effects": effects}]})


## The rows that compare the card with its own color.
func _color_rows(rows: Array[Dictionary]) -> Array[Dictionary]:
	return rows.filter(func(row: Dictionary) -> bool:
		return String(row["topic"]) == CardBalance.PIE_TOPIC or String(row["topic"]).ends_with(" by color"))


func test_the_game_s_cards_are_counted_by_color() -> void:
	var c := CardBalance.corpus()
	var by_color: Dictionary = c["by_color"]
	var cards := 0
	for key in ["W", "U", "B", "R", "G", "C", "M"]:
		cards += int(by_color[key]["cards"])
	assert_eq(cards, int(c["cards"]), "every nonland card on one color's shelf")
	assert_gt(int(by_color["G"]["creatures"]), 30, "green creatures")
	assert_eq(c["pie_home"]["damage"]["color"], "R", "direct damage is at home in red")
	assert_eq(c["pie_home"]["counter"]["color"], "U", "counterspells in blue")
	assert_eq(c["pie_home"]["prevent"]["color"], "W", "preventing damage in white")
	var flagged: Dictionary = c["color_flagged"]
	assert_eq(int(flagged["cards"]), int(c["cards"]), "every nonland card read for the color lines")
	assert_lt(int(flagged["any"]) * 20, int(flagged["cards"]),
		"fewer than 1 in 20 of the game's own cards get a color line: %s" % flagged)


func test_fair_ordinary_cards_get_no_color_warnings() -> void:
	var cards := {
		"a green 2/2 for two": _spec({}),
		"a green 2/2 for three": _spec({"cost": "{2}{G}"}),
		"a green 3/3 for three": _spec({"cost": "{2}{G}", "power": 3, "toughness": 3}),
		"a green 3/3 trampler for four": _spec({"cost": "{3}{G}", "power": 3, "toughness": 3, "keywords": ["trample"]}),
		"a white 2/2 flier for four": _spec({"cost": "{2}{W}{W}", "keywords": ["flying"]}),
		"a white 4/4 flier with vigilance for five": _spec({"cost": "{3}{W}{W}", "power": 4, "toughness": 4,
			"keywords": ["flying", "vigilance"]}),
		"a red 2/2 for three": _spec({"cost": "{2}{R}"}),
		"a black 2/2 for three": _spec({"cost": "{2}{B}"}),
		"a blue pinger": _spec({"cost": "{2}{U}", "power": 1, "toughness": 1, "abilities": [
			{"kind": "activated", "tap": true, "effects": [{"effect": "damage", "amount": 1, "target": "any"}]}]}),
		"a mana elf": _spec({"cost": "{G}", "power": 1, "toughness": 1, "abilities": [
			{"kind": "mana", "color": "green", "amount": 1}]}),
		"a red bolt for two": _spell("{1}{R}", "instant", [{"effect": "damage", "amount": 3, "target": "any"}]),
		"a blue draw two for three": _spell("{2}{U}", "sorcery", [{"effect": "draw", "amount": 2}]),
		"a blue counterspell": _spell("{U}{U}", "instant", [{"effect": "counter", "target": "spell"}]),
		"a black kill spell": _spell("{1}{B}{B}", "instant", [{"effect": "destroy", "target": "creature_nonblack"}]),
		"a black drain": _spell("{2}{B}", "sorcery", [{"effect": "drain", "amount": 2, "target": "opponent"}]),
		"a black discard": _spell("{1}{B}", "sorcery", [{"effect": "discard", "amount": 2, "target": "opponent"}]),
		"a white life gain": _spell("{1}{W}", "instant", [{"effect": "gain_life", "amount": 4}]),
		"a white disenchant": _spell("{1}{W}", "instant", [{"effect": "destroy", "target": "artifact_or_enchantment"}]),
		"a white armageddon": _spell("{3}{W}", "sorcery", [{"effect": "destroy_all", "target": "lands"}]),
		"a red shatter": _spell("{1}{R}", "instant", [{"effect": "destroy", "target": "artifact"}]),
		"a green growth": _spell("{G}", "instant", [{"effect": "pump", "power": 3, "toughness": 3, "target": "creature"}]),
		"a green fog": _spell("{G}", "instant", [{"effect": "fog"}]),
	}
	for what in cards:
		var rows := CardBalance.advice(cards[what])
		var warned := _color_rows(rows).filter(func(row: Dictionary) -> bool: return row["level"] != CardBalance.OK)
		assert_eq(warned, [] as Array[Dictionary], what)
		assert_false(String(rows[0]["text"]).contains("color"), what + ": the summary")


## advice() on a doctored copy of the corpus ([param doctor] changes it);
## the real one is put back after.
func _advice_with(spec: Dictionary, doctor: Callable) -> Array[Dictionary]:
	var real := CardBalance.corpus()
	var fake: Dictionary = real.duplicate(true)
	fake["doctored"] = true
	doctor.call(fake)
	CardBalance._corpus = fake
	var rows := CardBalance.advice(spec)
	CardBalance._corpus = real
	return rows


## Makes [param effect] at home in [param home] (3 in 10 of its cards) and
## 2 in 100 of each color in [param rare] — far apart enough to be told.
func _doctor(effect: String, home: String, rare: Array) -> Callable:
	return func(fake: Dictionary) -> void:
		var by_color: Dictionary = fake["by_color"]
		fake["pie_home"][effect] = {"color": home, "share": 0.3, "count": 100}
		for col in rare:
			by_color[col]["effects"][effect] = int(round(int(by_color[col]["cards"]) * 0.02))


func test_an_effect_rare_in_the_card_s_color_is_told_plainly() -> void:
	var bolt := _spell("{1}{W}", "instant", [{"effect": "damage", "amount": 3, "target": "any"}])
	var rows := _advice_with(bolt, _doctor("damage", "R", ["W"]))
	var hints := rows.filter(func(row: Dictionary) -> bool: return row["topic"] == CardBalance.PIE_TOPIC)
	assert_eq(hints.size(), 1, str(rows))
	assert_eq(hints[0]["level"], CardBalance.LOW)
	assert_string_contains(String(hints[0]["text"]), "Few white cards deal direct damage (2% of them; 30% of red cards)")
	assert_string_contains(String(rows[0]["text"]), "rare in its color")
	assert_eq(rows[0]["level"], CardBalance.OK, "a color hint leaves the summary's level be")
	# A gold card: rare in both its colors is told; at home in one is not.
	var shield := [{"effect": "prevent", "amount": 3, "target": "any"}]
	hints = _advice_with(_spell("{1}{U}{B}", "instant", shield), _doctor("prevent", "W", ["U", "B"])).filter(
		func(row: Dictionary) -> bool: return row["topic"] == CardBalance.PIE_TOPIC)
	assert_eq(hints.size(), 1, "prevention in blue and black")
	assert_string_contains(String(hints[0]["text"]), "Few blue or black cards prevent damage")
	assert_eq(_color_rows(_advice_with(_spell("{1}{W}{B}", "instant", shield), _doctor("prevent", "W", ["U", "B"]))),
		[] as Array[Dictionary], "prevention is at home in white")
	assert_false(CardBalance.corpus().has("doctored"), "the real corpus is back")


func test_color_hints_are_low_or_high_by_the_corpus_numbers() -> void:
	# A made-up corpus: 1 in 5 of the red cards deal direct damage.
	var group := func(n: int, damage: int) -> Dictionary:
		return {"cards": n, "creatures": 0, "effects": {"damage": damage}, "keywords": {}}
	var c := {"by_color": {"R": group.call(200, 40), "G": group.call(200, 0), "W": group.call(200, 3),
		"U": group.call(200, 6), "B": group.call(1000, 1)}}
	var home := {"color": "R", "share": 0.2, "count": 40}
	var levels := {}
	for col in ["G", "W", "U", "B", "R"]:
		var rows: Array[Dictionary] = []
		CardBalance._pie_row(rows, c, home, [col] as Array[String], "effects", "cards", "damage", "deal direct damage")
		levels[col] = String(rows[0]["level"]) if not rows.is_empty() else ""
	assert_eq(levels, {"G": CardBalance.HIGH, "W": CardBalance.LOW, "U": "", "B": CardBalance.HIGH, "R": ""},
		"none and 0.1% are almost none, 1.5% few, 3% and the home color nothing")
	var rows: Array[Dictionary] = []
	CardBalance._pie_row(rows, c, {"color": "R", "share": 0.2, "count": CardBalance.PIE_EVIDENCE - 1},
		["G"] as Array[String], "effects", "cards", "damage", "deal direct damage")
	assert_true(rows.is_empty(), "too few cards prove nothing")


func test_a_creature_is_set_beside_its_color_only_where_the_game_calls_it_unusual() -> void:
	assert_eq(_level(CardBalance.advice(_spec({"cost": "{2}{G}"})), "Size by color"), "", "a usual bear says nothing")
	var big := CardBalance.advice(_spec({"cost": "{2}{G}", "power": 4, "toughness": 4}))
	assert_ne(_level(big, "Size"), CardBalance.OK, str(big))
	assert_eq(_level(big, "Size by color"), CardBalance.HIGH)
	var tiny := CardBalance.advice(_spec({"cost": "{2}{G}", "power": 0, "toughness": 1}))
	assert_eq(_level(tiny, "Size"), CardBalance.LOW)
	assert_true(_level(tiny, "Size by color") in [CardBalance.OK, CardBalance.LOW], str(tiny))
	var giant := CardBalance.advice(_spec({"cost": "{2}{G}", "power": 40, "toughness": 40,
		"keywords": ["flying", "trample", "haste"]}))
	assert_false(_color_rows(giant).is_empty())
	assert_true(_color_rows(giant).all(func(row: Dictionary) -> bool: return row["level"] != CardBalance.VERY_HIGH),
		"never very high by color")
	# Too few creatures of the color and cost: nothing is said.
	assert_eq(_level(CardBalance.advice(_spec({"cost": "{1}", "power": 3, "toughness": 3})), "Size by color"), "",
		"a colorless one-drop")
	assert_eq(_level(CardBalance.advice(_spec({"cost": "{W}{U}", "power": 4, "toughness": 4})), "Size by color"), "",
		"a gold two-drop")


func test_counters_it_enters_with_count_in_its_size() -> void:
	var spike := CardBalance.advice(_spec({"power": 0, "toughness": 0, "rules": {"enters_counters": 2}}))
	assert_eq(_level(spike, "Size"), CardBalance.OK, "a 0/0 with two +1/+1 counters is a 2/2: %s" % str(spike))
	assert_eq(CardBalance._body(CommunityCard.build(_spec({"power": 1, "toughness": 1, "rules": {"enters_counters": 3}}))),
		Vector2i(4, 4))
	var beast := CardData.new("Test Clockwork", "{6}", Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE).pt(0, 4) \
		.with_enters_counters("+1/+0", 7)
	assert_eq(CardBalance._body(beast), Vector2i(7, 4), "+1/+0 counters count in power")
	var star := CardData.new("Test Star", "{1}{G}", Mtg.CardType.CREATURE).pt(0, 1) \
		.oracle("Test Star's power is equal to the number of creature cards in all graveyards.")
	assert_true(CardBalance._is_star(star), "a */1+* creature is left out of the size tables")
	assert_true(CardBalance._is_star(CardData.new("Test Zero", "{3}{G}", Mtg.CardType.CREATURE).pt(0, 0)), "a 0/0")
	assert_false(CardBalance._is_star(CardData.new("Test Bear", "{1}{G}", Mtg.CardType.CREATURE).pt(2, 2)), "a 2/2")


func test_an_upkeep_cost_is_a_drawback_like_echo() -> void:
	assert_eq(CardBalance._drawbacks({}, {"upkeep_cost": "{G}{G}"}), 1)
	var echo := _thumbs(CardBalance.advice(_spec({"cost": "{2}{G}", "power": 4, "toughness": 4,
		"rules": {"echo": "{2}{G}"}})))
	var upkeep := _thumbs(CardBalance.advice(_spec({"cost": "{2}{G}", "power": 4, "toughness": 4,
		"rules": {"upkeep_cost": "{2}{G}"}})))
	assert_eq(upkeep.size(), echo.size(), "an upkeep cost pays for size as echo does")


func test_the_card_s_name_and_reminder_text_are_not_what_it_does() -> void:
	var ping := [{"kind": "trigger", "when": "enters", "effects": [{"effect": "damage", "amount": 1, "target": "any"}]}]
	var levels := func(rows: Array[Dictionary]) -> Array:
		return rows.map(func(row: Dictionary) -> String: return "%s=%s" % [row["topic"], row["level"]])
	assert_eq(levels.call(CardBalance.advice(_spec({"name": "Search Party Exile", "cost": "{1}{R}", "abilities": ping}))),
		levels.call(CardBalance.advice(_spec({"name": "Brave Scout", "cost": "{1}{R}", "abilities": ping}))),
		"the name changes no verdict")
	var brand := CardData.new("Test Brand", "{R}", Mtg.CardType.INSTANT) \
		.oracle("Gain control of all permanents you own.\nCycling {2} ({2}, Discard this card: Draw a card.)")
	assert_false(CardBalance._pie_effects(CardBalance._rules_of(brand)).has("draw"), "a reminder draws no card")
	assert_eq(CardBalance._rules_of(brand), "Gain control of all permanents you own.\nCycling {2}")
	var exile := CardData.new("Exile", "{2}{W}", Mtg.CardType.INSTANT).oracle("Exile target attacking creature.")
	assert_true(CardBalance._pie_effects(CardBalance._rules_of(exile)).has("exile"), "a verb for a name is kept")
	var dual := CardBalance.advice(_spec({"name": "Forest Isle", "cost": "", "types": ["land"],
		"subtypes": ["forest", "island"]}))
	assert_eq(_level(dual, "Mana"), "", "its land types' reminder is no ability")


func test_discards_counters_and_sacrifices_are_part_of_a_price() -> void:
	assert_eq(int(CardBalance._ability("Discard a card: Draw a card.")["price"]), 1)
	assert_eq(int(CardBalance._ability("{1}, Sacrifice a creature: CARDNAME deals 2 damage to any target.")["price"]), 2)
	assert_eq(int(CardBalance._ability("Remove two +1/+1 counters from CARDNAME: Draw a card.")["price"]), 1)
	assert_eq(int(CardBalance._ability("{T}, Discard two cards, Pay 4 life: Draw three cards.")["price"]), 4)
	assert_eq(int(CardBalance._ability("{T}, Sacrifice CARDNAME, Sacrifice a land: Add {R}{R}.")["price"]), 3)


func test_the_round_5_balance_fixes() -> void:
	var anthem := CardBalance.advice(_spec({"name": "Bal Anthem", "cost": "{W}", "types": ["enchantment"],
		"abilities": [{"kind": "static", "what": "anthem", "power": 5, "toughness": 5}]}))
	assert_true(anthem.any(func(r: Dictionary) -> bool: return String(r["level"]) in [CardBalance.HIGH, CardBalance.VERY_HIGH]),
		"a +5/+5 anthem for one mana is measured")
	var wall := CardBalance.advice(_spec({"name": "Bal Wall", "cost": "{G}", "types": ["creature"], "power": 0,
		"toughness": 3, "keywords": ["defender", "reach"]}))
	assert_false(String(wall[0]["level"]) == CardBalance.VERY_HIGH, "a one-mana wall with reach is no alarm")


func test_every_row_but_the_summary_carries_the_card_s_own_number_apart() -> void:
	var giant := {"format": CommunityCard.FORMAT, "version": 1, "name": "Zyx Table Giant",
		"cost": "{3}{G}", "types": ["creature"], "power": 9, "toughness": 9,
		"keywords": ["trample", "vigilance", "reach", "first_strike"], "abilities": []}
	var rows := CardBalance.advice(giant)
	assert_eq(String(rows[0]["topic"]), "Summary")
	assert_false(rows[0].has("yours"))
	for row in rows.slice(1):
		assert_true(row.has("yours"), String(row["text"]))
		var words := CardBalance.game_words(row)
		if String(row["topic"]) != CardBalance.PIE_TOPIC:
			assert_false(words.contains("yours"), words)
		assert_false(words.contains("; ."), words)
	var size := rows.filter(func(r: Dictionary) -> bool: return String(r["topic"]) == "Size")
	assert_eq(String(size[0]["yours"]), "9/9 (18)")
	var thumb := rows.filter(func(r: Dictionary) -> bool:
		return String(r["topic"]) == CardBalance.THUMB_TOPIC and String(r["text"]).begins_with("power + toughness"))
	assert_string_contains(CardBalance.game_words(thumb[0]), "(here ")
	assert_false(CardBalance.game_words(thumb[0]).contains("; yours"))

