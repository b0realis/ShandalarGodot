extends GutTest
## THE VALIDATOR, second pass ([CardBalance]): nothing on a card is passed
## over in silence — every word of the vocabulary is measured against the
## game's cards or named in a "Not compared" row, and a card with such a
## row (or a High one) is never said to simply fit. Mass destruction,
## extra turns, tokens, mana at any price, life, discard, mill, searches,
## control, cost reductions, pumps, keyword piles, curses and triggers are
## weighed; fair classic cards are left in peace; the numbers quoted are
## the pool's own; one power number and a whole set at once.


func _spec(extra: Dictionary) -> Dictionary:
	var spec := {"format": CommunityCard.FORMAT, "version": 1, "name": "Balance Test",
		"cost": "{1}{G}", "types": ["creature"], "power": 2, "toughness": 2, "rarity": "common",
		"abilities": []}
	spec.merge(extra, true)
	if not (spec["types"] as Array).has("creature"):
		spec.erase("power")
		spec.erase("toughness")
	assert_eq(CommunityCard.problems(spec), [] as Array[String], "a whole card: %s" % spec.get("name"))
	return spec


func _spell(cost: String, type: String, effects: Array, extra := {}) -> Dictionary:
	var spec := {"cost": cost, "types": [type], "abilities": [{"kind": "spell", "effects": effects}]}
	spec.merge(extra, true)
	return _spec(spec)


func _rows(spec: Dictionary) -> Array[Dictionary]:
	return CardBalance.advice(spec)


func _strong(rows: Array[Dictionary]) -> Array[Dictionary]:
	return rows.slice(1).filter(func(row: Dictionary) -> bool:
		return String(row["level"]) in [CardBalance.HIGH, CardBalance.VERY_HIGH])


func _topic(rows: Array[Dictionary], topic: String) -> Dictionary:
	for row in rows:
		if String(row["topic"]) == topic:
			return row
	return {}


func _told(rows: Array[Dictionary]) -> String:
	var out := ""
	for row in rows:
		out += "\n  %s | %s | %s | %s" % [row["level"], row["topic"], row.get("yours", ""), row["text"]]
	return out


## Flagged: a High (or worse) row of [param topic], and no green summary.
func _assert_flagged(spec: Dictionary, topic: String, what: String) -> void:
	var rows := _rows(spec)
	var hit := _strong(rows).filter(func(row: Dictionary) -> bool: return String(row["topic"]) == topic)
	assert_false(hit.is_empty(), "%s: a High row \"%s\"%s" % [what, topic, _told(rows)])
	assert_ne(String(rows[0]["level"]), CardBalance.OK, what + ": never \"fits\"")
	assert_false(String(rows[0]["text"]).begins_with("Fits the game's cards."), what)


# ------------------------------------------------- coverage is structural --

func test_every_word_of_the_vocabulary_is_measured_or_named() -> void:
	var cover := CardBalance.coverage()
	assert_gt(cover.size(), 80, "effects, triggers, statics, rules, keywords, …")
	for key: String in cover:
		assert_ne(String(cover[key]), "", "%s has neither a measure nor a \"Not compared\" label" % key)
	# Every table of the vocabulary is walked — a new one must be put in
	# VOCABULARY (and be covered) or in NOT_VOCABULARY, on purpose.
	var constants: Dictionary = (load("res://engine/community/community_card.gd") as Script).get_script_constant_map()
	for constant: String in constants:
		if constant.begins_with("_"):
			continue
		if constants[constant] is Dictionary or constants[constant] is Array:
			assert_true(constant in CardBalance.VOCABULARY or constant in CardBalance.NOT_VOCABULARY,
				"CommunityCard.%s is a table this check neither walks nor sets aside" % constant)
	for table: String in CardBalance.VOCABULARY:
		assert_true(constants.has(table), table)
		for id: Variant in constants[table]:
			assert_true(cover.has("%s/%s" % [table, id]), "%s/%s is walked" % [table, id])


func test_every_effect_is_read_with_every_target_and_field_it_may_have() -> void:
	for id: String in CommunityCard.EFFECTS:
		var info: Dictionary = CommunityCard.EFFECTS[id]
		for field: String in info:
			assert_true(field in CardBalance.EFFECT_FIELDS, "effect \"%s\" has a new field \"%s\" — read it or set it aside" % [id, field])
		var kind := "activated" if id in CommunityCard.ACTIVATED_ONLY else "spell"
		for target: Variant in info.get("targets", [""]):
			var e := CommunityCard.effect_defaults(id, kind)
			if String(target) != "":
				e["target"] = target
			var text := CardBalance._own_text({"abilities": [{"kind": kind, "cost": "{1}", "effects": [e]}]},
				["artifact"] if kind == "activated" else ["sorcery"])
			assert_true(CardBalance._how_read(text) != "" or CardBalance._NOT_COMPARED.has("EFFECTS/" + id),
				"\"%s\" (%s, %s) reads as nothing" % [text, id, target])
	for id: String in CardBalance._M:
		assert_eq((CardBalance._M[id] as Array).size(), 4, id)
	for entry: Array in CardBalance._READS:
		assert_true(CardBalance._M.has(entry[0]), "the reading \"%s\" has a measure" % entry[0])


func test_what_was_set_beside_nothing_is_said_and_never_fits() -> void:
	# An amount of X is not compared: said so, and the banner is not green.
	var fireball := _rows(_spell("{X}{R}", "sorcery", [{"effect": "damage", "x": true, "target": "any"}]))
	var unread := fireball.filter(func(row: Dictionary) -> bool: return row["level"] == CardBalance.NOT_COMPARED)
	assert_eq(unread.size(), 2, "the summary and the row: %s" % _told(fireball))
	assert_eq(String(fireball[0]["level"]), CardBalance.NOT_COMPARED)
	assert_string_contains(String(fireball[0]["text"]), "Not compared")
	assert_string_contains(String(unread[1]["topic"]), "Deal damage")
	assert_string_contains(String(unread[1]["text"]), "X")
	assert_eq(String(CardBalance.LEVEL_WORDS[CardBalance.NOT_COMPARED]), "Not compared")
	# A vocabulary word this check has never heard of is named, not dropped.
	var odd: Array[Dictionary] = []
	CardBalance._coverage_rows(odd, {"types": ["sorcery"], "abilities": [
		{"kind": "spell", "effects": [{"effect": "zz_unknown"}]}, {"kind": "zz_kind"},
		{"kind": "trigger", "when": "zz_when", "effects": []}], "rules": {"zz_rule": true}})
	assert_eq(odd.size(), 4, str(odd))
	assert_true(odd.all(func(row: Dictionary) -> bool: return row["level"] == CardBalance.NOT_COMPARED))
	# An effect none of the pool's cards has: the measure itself says so.
	var real := CardBalance.corpus()
	var fake: Dictionary = real.duplicate(true)
	(fake["m"]["spell"] as Dictionary).erase("extra_turn")
	CardBalance._corpus = fake
	var walk := _rows(_spell("{3}{U}{U}", "sorcery", [{"effect": "extra_turn"}]))
	CardBalance._corpus = real
	assert_eq(String(_topic(walk, "Extra turn").get("level", "")), CardBalance.NOT_COMPARED, _told(walk))
	assert_ne(String(walk[0]["level"]), CardBalance.OK)


# ------------------------------------------------------- the worst offenders --

func test_what_used_to_pass_unread_is_now_weighed() -> void:
	_assert_flagged(_spell("{W}", "sorcery", [{"effect": "destroy_all", "target": "creatures"}]),
		"Mass destruction", "a Wrath of God for {W}")
	_assert_flagged(_spell("{R}", "sorcery", [{"effect": "extra_turn"}]), "Extra turn", "a Time Walk for {R}")
	var doom := _rows(_spell("{0}", "sorcery", [{"effect": "destroy_all", "target": "lands"}, {"effect": "extra_turn"}]))
	assert_gte(_strong(doom).size(), 2, "all lands and a turn for nothing: %s" % _told(doom))
	_assert_flagged(_spell("{G}", "sorcery", [{"effect": "token", "amount": 5, "power": 5, "toughness": 5,
		"color": "green", "subtype": "beast", "keywords": ["flying", "haste"]}]), "Tokens", "five 5/5 tokens for {G}")
	_assert_flagged(_spell("{B}", "instant", [{"effect": "add_mana", "amount": 5, "color": "black"}]),
		"Mana, once", "a Dark Ritual for five")
	_assert_flagged(_spell("{B}", "sorcery", [{"effect": "drain", "amount": 20, "target": "opponent"}]),
		"Life lost", "a drain for 20")
	_assert_flagged(_spell("{B}", "sorcery", [{"effect": "lose_life", "amount": 20, "target": "opponent"}]),
		"Life lost", "lose 20 life")
	var mind := _spell("{1}{B}", "sorcery", [{"effect": "discard", "amount": 7, "target": "opponent"},
		{"effect": "mill", "amount": 20, "target": "opponent"}])
	_assert_flagged(mind, "Discard", "discard seven")
	_assert_flagged(mind, "Mill", "mill twenty")
	_assert_flagged(_spell("{B}", "sorcery", [{"effect": "search", "amount": 3, "target": "a_card", "where": "library"}]),
		"Search", "a tutor for three")
	_assert_flagged(_spec({"cost": "{U}", "types": ["enchantment"], "abilities": [
		{"kind": "enchant", "enchant": "creature", "control": true}]}), "Control", "a Control Magic for {U}")
	_assert_flagged(_spec({"cost": "{1}", "types": ["artifact"], "abilities": [{"kind": "activated", "cost": "{0}",
		"tap": true, "effects": [{"effect": "pump", "power": 10, "toughness": 10, "target": "creature"}]}]}),
		"Pump", "a {0}, {T} +10/+10")
	_assert_flagged(_spec({"cost": "{0}", "types": ["artifact"], "abilities": [{"kind": "static", "what": "cost_less",
		"spell_type": "creature", "amount": 3}]}), "Cost reduction", "costs {3} less for nothing")
	_assert_flagged(_spec({"cost": "{1}{W}", "protection": ["white", "blue", "black", "red", "green"],
		"landwalk": ["plains", "island", "swamp", "mountain", "forest"], "rules": {"rampage": 5}}),
		"Keywords", "five protections, five landwalks and rampage")


func test_a_trigger_is_measured_like_a_spell_or_an_ability() -> void:
	var bomb := _spec({"cost": "{R}", "power": 1, "toughness": 1, "abilities": [{"kind": "trigger", "when": "enters",
		"effects": [{"effect": "damage", "amount": 20, "target": "any"}, {"effect": "draw", "amount": 7}]}]})
	_assert_flagged(bomb, "Damage", "enters: 20 damage")
	_assert_flagged(bomb, "Cards drawn", "enters: draw seven")
	assert_string_contains(String(_topic(_rows(bomb), "Damage")["text"]), "happens once")
	var engine := _spec({"cost": "{1}{W}", "types": ["enchantment"], "abilities": [{"kind": "trigger", "when": "upkeep",
		"effects": [{"effect": "draw", "amount": 7}, {"effect": "gain_life", "amount": 20}]}]})
	_assert_flagged(engine, "Cards drawn", "upkeep: draw seven")
	_assert_flagged(engine, "Life", "upkeep: gain 20")
	assert_string_contains(String(_topic(_rows(engine), "Life")["text"]), "again and again")
	# A fair one is left be: a 2/2 for three that draws a card as it enters.
	var fair := _rows(_spec({"cost": "{2}{U}", "abilities": [{"kind": "trigger", "when": "enters",
		"effects": [{"effect": "draw", "amount": 1}]}]}))
	assert_eq(_strong(fair), [] as Array[Dictionary], _told(fair))
	assert_eq(String(_topic(fair, "Cards drawn").get("level", "")), CardBalance.OK, _told(fair))


func test_mana_is_weighed_at_any_price() -> void:
	# A Black Lotus copy is read (it used to get the cost line alone).
	var lotus := _rows(_spec({"cost": "{0}", "types": ["artifact"], "abilities": [
		{"kind": "mana", "color": "any", "amount": 3, "sacrifice": true}]}))
	assert_eq(String(_topic(lotus, "Mana, once").get("yours", "")), "+3", _told(lotus))
	var petal := _rows(_spec({"cost": "{0}", "types": ["artifact"], "abilities": [
		{"kind": "mana", "color": "any", "amount": 1, "sacrifice": true}]}))
	assert_eq(_strong(petal), [] as Array[Dictionary], "a Lotus Petal: %s" % _told(petal))
	_assert_flagged(_spec({"cost": "{G}", "power": 1, "toughness": 1, "abilities": [
		{"kind": "mana", "cost": "{1}", "color": "green", "amount": 3}]}), CardBalance.THUMB_TOPIC, "{1}, {T}: three mana on a one-drop")
	var land := _spec({"cost": "", "types": ["land"], "abilities": [
		{"kind": "mana", "cost": "{1}", "color": "colorless", "amount": 3}]})
	_assert_flagged(land, CardBalance.THUMB_TOPIC, "a land with {1}, {T}: add three")
	assert_eq(String(_topic(_rows(land), "Mana")["yours"]), "2", "three made, one paid")
	assert_eq(CardBalance._mana_of("{1}, {T}, Sacrifice a creature", "Add {G}{G}{G}.", false),
		{"made": 3, "net": 1, "once": false}, "extra costs come off")
	assert_eq(int(CardBalance._mana_made("Add {G} for each Elf on the battlefield.")), 0, "not a number")


func test_pain_on_a_mana_ability_is_a_drawback_not_damage() -> void:
	var rows := _rows(_spec({"cost": "{1}{R}", "types": ["artifact"], "abilities": [
		{"kind": "mana", "cost": "{1}", "color": "red", "amount": 2, "pain": 2}]}))
	assert_eq(_topic(rows, "Damage"), {}, "its own pain is no damage dealt: %s" % _told(rows))
	assert_true(CardBalance._read("CARDNAME deals 2 damage to you.").is_empty())
	assert_eq(int(CardBalance._read("CARDNAME deals 2 damage to any target.")["damage"]), 2)
	assert_true(CardBalance._self_harm("CARDNAME deals 2 damage to you"))
	# On a land the pain pays for the second mana.
	assert_eq(CardBalance._land_drawbacks("CARDNAME enters the battlefield tapped.\n{T}: Add {R}{R}. CARDNAME deals 1 damage to you."), 2)


func test_curses_and_mixed_bonuses_are_read() -> void:
	_assert_flagged(_spec({"cost": "{B}", "types": ["enchantment"], "abilities": [{"kind": "static", "what": "opponents",
		"power": -5, "toughness": -5}]}), "Weakening", "opponents' creatures get -5/-5")
	_assert_flagged(_spec({"cost": "{B}", "types": ["enchantment"], "abilities": [
		{"kind": "enchant", "enchant": "creature", "power": -9, "toughness": -9}]}), "Aura, weakening", "an Aura of -9/-9")
	var mixed := _rows(_spec({"cost": "{W}", "types": ["enchantment"], "abilities": [{"kind": "static", "what": "anthem",
		"power": 6, "toughness": -1}]}))
	assert_false(_strong(mixed).is_empty(), "an anthem of +6/-1: %s" % _told(mixed))
	assert_eq(CardBalance._read_static("Creatures you control get +6/-1."), {"anthem": 6})
	assert_eq(CardBalance._read_static("Creatures your opponents control get -2/-1."), {"weaken": 3})
	assert_eq(CardBalance._read_static("All creatures get -1/-1."), {"weaken": 2})
	assert_eq(CardBalance._read_static("Enchanted creature gets +2/-1 and has flying."), {"aura": 3, "aura_minus": 1})
	assert_true(CardBalance._read_static("Creatures your opponents control get +1/+1.").is_empty(), "a gift to them")
	assert_true(CardBalance._static_drawback("Creatures your opponents control get +1/+1."))


func test_a_name_cannot_blind_the_reader() -> void:
	_assert_flagged(_spec({"name": "T", "cost": "", "types": ["land"], "abilities": [
		{"kind": "mana", "color": "colorless", "amount": 3}]}), CardBalance.THUMB_TOPIC, "a land named T tapping for three")
	_assert_flagged(_spec({"name": "Enchanted", "cost": "{G}", "types": ["enchantment"],
		"abilities": [{"kind": "enchant", "enchant": "creature", "power": 9, "toughness": 9}]}), "Aura",
		"an Aura named Enchanted")
	# One of the game's own: the name is masked by whole words only.
	var t := CardData.new("T", "", Mtg.CardType.LAND).oracle("{T}: Add {C}{C}{C}.\nSacrifice T: Draw a card.")
	assert_eq(CardBalance._rules_of(t), "{T}: Add {C}{C}{C}.\nSacrifice CARDNAME: Draw a card.")
	var ant := CardData.new("Ant", "{G}", Mtg.CardType.CREATURE).oracle("Ant gets +1/+1 as long as you control an Antelope. Giant Ant.")
	assert_eq(CardBalance._rules_of(ant), "CARDNAME gets +1/+1 as long as you control an Antelope. Giant CARDNAME.")


# ---------------------------------------------------------- fair real cards --

const FAIR := ["Serra Angel", "Ornithopter", "Mox Emerald", "Grizzly Bears", "Lightning Bolt", "Counterspell",
	"Wrath of God", "Juzám Djinn", "Llanowar Elves", "Terror", "Disenchant", "Swords to Plowshares", "Dark Ritual",
	"Giant Growth", "Air Elemental", "Prodigal Sorcerer", "Armageddon", "Control Magic", "Sengir Vampire",
	"Hypnotic Specter", "Shivan Dragon", "White Knight", "Sol Ring", "Birds of Paradise"]


func test_fair_classic_cards_get_no_high_row() -> void:
	var I := "instant"
	var specs := {
		"Serra Angel": _spec({"cost": "{3}{W}{W}", "power": 4, "toughness": 4, "keywords": ["flying", "vigilance"]}),
		"Ornithopter": _spec({"cost": "{0}", "types": ["artifact", "creature"], "power": 0, "toughness": 2,
			"keywords": ["flying"]}),
		"a Mox": _spec({"cost": "{0}", "types": ["artifact"], "abilities": [{"kind": "mana", "color": "green", "amount": 1}]}),
		"Lotus Petal": _spec({"cost": "{0}", "types": ["artifact"], "abilities": [
			{"kind": "mana", "color": "any", "amount": 1, "sacrifice": true}]}),
		"a vanilla bear": _spec({}),
		"Lightning Bolt": _spell("{R}", I, [{"effect": "damage", "amount": 3, "target": "any"}]),
		"Counterspell": _spell("{U}{U}", I, [{"effect": "counter", "target": "spell"}]),
		"Wrath of God": _spell("{2}{W}{W}", "sorcery", [{"effect": "destroy_all", "target": "creatures"}]),
	}
	for what: String in specs:
		var rows := _rows(specs[what])
		assert_eq(_strong(rows), [] as Array[Dictionary], "%s%s" % [what, _told(rows)])
		assert_false(String(rows[0]["level"]) in [CardBalance.HIGH, CardBalance.VERY_HIGH], what)
	# And the game's own cards, read from their rules text as the pool is
	# counted (a Juzám Djinn's upkeep damage is a drawback read there).
	for card_name: String in FAIR:
		var data := CardRegistry.get_card(card_name)
		if data == null:
			continue
		var rows := CardBalance.card_advice(data)
		assert_eq(_strong(rows), [] as Array[Dictionary], "%s%s" % [card_name, _told(rows)])
	var juzam := CardData.new("Test Djinn", "{2}{B}{B}", Mtg.CardType.CREATURE).pt(5, 5) \
		.oracle("At the beginning of your upkeep, Test Djinn deals 1 damage to you.")
	assert_eq(CardBalance._drawbacks_in(juzam, CardBalance._rules_of(juzam)), 2, "the game prices upkeep pain at two mana")
	assert_eq(_strong(CardBalance.card_advice(juzam)), [] as Array[Dictionary])


func test_the_under_costed_ones_still_get_one() -> void:
	var I := "instant"
	_assert_flagged(_spec({"cost": "{1}{W}", "power": 4, "toughness": 4, "keywords": ["flying", "vigilance"]}),
		"Size", "a Serra Angel for two")
	_assert_flagged(_spec({"cost": "{0}", "types": ["artifact", "creature"], "power": 3, "toughness": 3,
		"keywords": ["flying"]}), "Size", "a 3/3 flier for nothing")
	_assert_flagged(_spec({"cost": "{0}", "types": ["artifact"], "abilities": [
		{"kind": "mana", "color": "green", "amount": 3}]}), "Mana", "a Mox for three")
	_assert_flagged(_spec({"cost": "{0}", "types": ["artifact"], "abilities": [
		{"kind": "mana", "color": "any", "amount": 3, "sacrifice": true}, {"kind": "mana", "color": "any", "amount": 3}]}),
		"Mana", "a Lotus that stays")
	_assert_flagged(_spell("{R}", I, [{"effect": "damage", "amount": 6, "target": "any"}]), "Damage", "a Bolt for six")
	_assert_flagged(_spell("{0}", I, [{"effect": "counter", "target": "spell"}]), "Counterspell", "a free Counterspell")
	_assert_flagged(_spell("{W}", "sorcery", [{"effect": "destroy_all", "target": "creatures"}]), "Mass destruction",
		"a Wrath for one")
	_assert_flagged(_spec({"cost": "{B}", "power": 5, "toughness": 5}), "Size", "a 5/5 for {B}")
	# An over-costed one is weak, not strong.
	var dear := _rows(_spec({"cost": "{6}{G}", "power": 1, "toughness": 1}))
	assert_eq(String(_topic(dear, "Size")["level"]), CardBalance.LOW)
	assert_eq(_strong(dear), [] as Array[Dictionary], _told(dear))


func test_few_of_the_game_s_own_cards_are_called_strong() -> void:
	var strong := 0
	var total := 0
	for card_name in CardRegistry.all_names():
		var data := CardRegistry.get_card(card_name)
		if data == null or CardRegistry.community_names().has(card_name):
			continue
		total += 1
		if String(CardBalance.card_advice(data)[0]["level"]) in [CardBalance.HIGH, CardBalance.VERY_HIGH]:
			strong += 1
	gut.p("High or worse: %d of the pool's %d cards" % [strong, total])
	assert_lt(strong * 12, total, "fewer than 1 in 12 of the game's own cards (it was 1 in 8): %d of %d" % [strong, total])


# ------------------------------------------------------------ color hints --

func _hints(rows: Array[Dictionary]) -> Array[Dictionary]:
	return rows.filter(func(row: Dictionary) -> bool: return String(row["topic"]) == CardBalance.PIE_TOPIC)


func test_color_hints_of_1993_to_99() -> void:
	var home: Dictionary = CardBalance.corpus()["pie_home"]["counter"]
	assert_eq(String(home["color"]), "U")
	for cost: String in ["{1}{G}", "{1}{W}", "{1}{B}", "{1}{R}"]:
		var rows := _rows(_spell(cost, "instant", [{"effect": "counter", "target": "spell"}]))
		var hints := _hints(rows)
		assert_eq(hints.size(), 1, "a counterspell for %s is off its color: %s" % [cost, _told(rows)])
		if hints.is_empty():
			continue
		assert_eq(String(hints[0]["level"]), CardBalance.RARE)
		assert_eq(String(hints[0]["yours"]), "", "the sentence says what; the Yours column stays empty")
		assert_string_contains(String(hints[0]["text"]), "counter spells")
		if int(home["count"]) < CardBalance.PIE_EVIDENCE:
			assert_string_contains(String(hints[0]["text"]), "small sample", "honest about a thin pool")
		assert_string_contains(String(rows[0]["text"]), "rare in its color")
	assert_eq(String(CardBalance.LEVEL_WORDS[CardBalance.RARE]), "Rare in color")
	var at_home := {
		"a blue counterspell": _spell("{U}{U}", "instant", [{"effect": "counter", "target": "spell"}]),
		"a green answer to fliers": _spell("{2}{G}", "sorcery", [{"effect": "destroy", "target": "creature_flying"}]),
		"a green sweep of fliers": _spell("{2}{G}{G}", "sorcery", [{"effect": "destroy_all", "target": "creatures_flying"}]),
		"a white archer": _spec({"cost": "{1}{W}", "power": 1, "toughness": 2, "abilities": [{"kind": "activated",
			"tap": true, "effects": [{"effect": "damage", "amount": 1, "target": "creature_attacking"}]}]}),
		"an artifact that destroys creatures": _spec({"cost": "{4}", "types": ["artifact"], "abilities": [
			{"kind": "activated", "cost": "{1}", "tap": true, "effects": [{"effect": "destroy_all", "target": "creatures"}]}]}),
		"an artifact that draws": _spec({"cost": "{4}", "types": ["artifact"], "abilities": [
			{"kind": "activated", "cost": "{4}", "tap": true, "effects": [{"effect": "draw", "amount": 1}]}]}),
	}
	for what: String in at_home:
		assert_eq(_hints(_rows(at_home[what])), [] as Array[Dictionary], what)
	# The narrow answers are counted on neither side.
	assert_false(CardBalance._pie_effects("Destroy target creature with flying.").has("kill"))
	assert_false(CardBalance._pie_effects("CARDNAME deals 1 damage to target attacking creature.").has("damage"))
	assert_true(CardBalance._pie_effects("Destroy target creature.").has("kill"))
	assert_false(CardBalance._pie_effects("Counter target red spell.").has("counter"), "a color hoser is no counterspell")
	assert_true(CardBalance._pie_effects("Counter target spell unless its controller pays {1}.").has("counter"))


func test_a_thin_pool_tells_only_what_is_plain() -> void:
	var group := func(n: int, damage: int) -> Dictionary:
		return {"cards": n, "creatures": 0, "effects": {"damage": damage}, "keywords": {}}
	var c := {"by_color": {"R": group.call(100, 8), "G": group.call(100, 0), "W": group.call(100, 2)}}
	var thin := {"color": "R", "share": 0.08, "count": 8}
	var rows: Array[Dictionary] = []
	CardBalance._pie_row(rows, c, thin, ["G"] as Array[String], "effects", "cards", "damage", "deal direct damage")
	assert_eq(rows.size(), 1, "none of the green cards: told even with eight red ones")
	assert_string_contains(String(rows[0]["text"]), "Only 8 red cards do in this pool")
	rows.clear()
	CardBalance._pie_row(rows, c, thin, ["W"] as Array[String], "effects", "cards", "damage", "deal direct damage")
	assert_true(rows.is_empty(), "\"few\" needs the full evidence")


# -------------------------------------------------- the pool's own numbers --

func test_rules_of_thumb_quote_the_pool_in_use_and_end_with_advice() -> void:
	var c := CardBalance.corpus()
	var all := int(c["all"])
	assert_gt(all, int(c["cards"]), "lands counted too")
	var giant := _rows(_spec({"cost": "{R}", "power": 40, "toughness": 40}))
	var thumbs := giant.filter(func(row: Dictionary) -> bool: return String(row["topic"]) == CardBalance.THUMB_TOPIC)
	assert_gte(thumbs.size(), 3, _told(giant))
	for row in thumbs:
		var text := String(row["text"])
		assert_string_contains(text, "of the game's %d cards" % all)
		assert_eq(text.left(1), text.left(1).to_upper(), "starts with a capital: " + text)
		assert_true(text.contains("Raise the cost to ") or text.contains("Lower "), "ends with advice: " + text)
	var size := thumbs.filter(func(row: Dictionary) -> bool: return String(row["text"]).begins_with("Power + toughness"))
	assert_string_contains(String(size[0]["text"]), "Raise the cost to 40 or shrink it to 3 in all.")
	# Counted, not quoted: the cards named are past the line in this pool.
	for id: String in c["thumb"]:
		var stat: Dictionary = c["thumb"][id]
		assert_gte(int(stat["past"]), (stat["names"] as Array).size(), id)
		for card_name: String in stat["names"]:
			assert_not_null(CardRegistry.get_card(card_name), card_name)
	# A doctored pool changes what is said.
	var fake: Dictionary = c.duplicate(true)
	fake["all"] = 123
	fake["thumb"]["size_far"] = {"past": 0, "names": []}
	CardBalance._corpus = fake
	var said := _told(_rows(_spec({"cost": "{R}", "power": 40, "toughness": 40})))
	CardBalance._corpus = c
	assert_string_contains(said, "None of the game's 123 cards is past that line.")


# ------------------------------------------------------------------ polish --

func test_plain_words() -> void:
	var one := _rows(_spell("{1}{U}", "sorcery", [{"effect": "draw", "amount": 1}]))
	assert_string_contains(String(_topic(one, "Cards drawn")["text"]), "1 card is usual")
	var bird := _rows(_spec({"cost": "{0}", "types": ["artifact", "creature"], "power": 0, "toughness": 2, "keywords": ["flying"]}))
	assert_false(_told(bird).contains("0 keywords or fewer"), _told(bird))
	var x := _rows(_spell("{X}", "sorcery", [{"effect": "damage", "x": true, "target": "any"}]))
	assert_string_contains(String(_topic(x, "Mana cost")["text"]), "X")
	assert_false(_told(x).contains("A cost of 0 is usual"))
	var free := _rows(_spell("{0}", "sorcery", [{"effect": "damage", "amount": 9, "target": "any"}]))
	assert_false(_told(free).contains("0-mana spells or cheaper deals"), _told(free))


func test_a_creature_with_no_toughness_dies_on_arrival() -> void:
	var dead := _rows(_spec({"power": 0, "toughness": 0}))
	assert_string_contains(String(_topic(dead, "Size")["text"]), "dies on arrival")
	var spike := _rows(_spec({"power": 0, "toughness": 0, "rules": {"enters_counters": 2}}))
	assert_false(_told(spike).contains("dies on arrival"), "a 0/0 with two counters is a 2/2")


func test_a_land_s_drawbacks_are_counted_before_its_second_mana() -> void:
	var plain := _rows(_spec({"cost": "", "types": ["land"], "abilities": [
		{"kind": "mana", "color": "red", "amount": 2}]}))
	assert_false(_strong(plain).is_empty(), "two mana for nothing: %s" % _told(plain))
	var paid := _rows(_spec({"cost": "", "types": ["land"], "rules": {"enters_tapped": true}, "abilities": [
		{"kind": "mana", "color": "red", "amount": 2, "pain": 1}]}))
	assert_eq(_strong(paid), [] as Array[Dictionary], "pain and enters tapped pay for it: %s" % _told(paid))
	assert_eq(String(_topic(paid, "Mana")["yours"]), "0", "two made, two drawbacks")


func test_a_modal_spell_is_its_biggest_mode() -> void:
	var charm := _rows(_spec({"cost": "{1}{R}", "types": ["instant"], "abilities": [{"kind": "modal", "modes": [
		{"effects": [{"effect": "damage", "amount": 2, "target": "any"}]},
		{"effects": [{"effect": "damage", "amount": 3, "target": "creature"}]}]}]}))
	assert_eq(String(_topic(charm, "Damage")["yours"]), "3", "not 5: %s" % _told(charm))


func test_drawbacks_are_scaled_by_what_they_cost() -> void:
	var of := func(spec: Dictionary) -> int:
		var masked := spec.duplicate()
		masked["name"] = "CARDNAME"
		var data := CommunityCard.build(masked)
		return CardBalance._drawbacks_in(data, CardBalance._rules_of(data))
	assert_eq(of.call(_spec({"rules": {"extra_life": 1}})), 0, "1 life buys nothing")
	assert_eq(of.call(_spec({"rules": {"extra_life": 2}})), 1)
	assert_eq(of.call(_spec({"rules": {"extra_life": 9}})), 2)
	assert_eq(of.call(_spec({"rules": {"echo": "{G}"}})), 1)
	assert_eq(of.call(_spec({"rules": {"echo": "{2}{G}{G}"}})), 2)
	assert_eq(of.call(_spec({"rules": {"upkeep_cost": "{1}"}})), 1)
	assert_eq(of.call(_spec({"rules": {"upkeep_cost": "{2}{G}"}})), 2)
	assert_eq(of.call(_spec({"rules": {"cant_block": true}, "keywords": ["defender"]})), 2)
	# So "pay 1 life" no longer buys +2 size.
	var cheat := _rows(_spec({"cost": "{1}{B}", "power": 3, "toughness": 3, "rules": {"extra_life": 1}}))
	var honest := _rows(_spec({"cost": "{1}{B}", "power": 3, "toughness": 3}))
	assert_eq(String(_topic(cheat, "Size")["level"]), String(_topic(honest, "Size")["level"]))


# --------------------------------------------------- one number, whole sets --

func test_power_is_0_to_100_and_never_falls_for_a_stronger_card() -> void:
	var ladders := {
		"a bigger body": [_spec({"power": 1, "toughness": 1}), _spec({}), _spec({"power": 3, "toughness": 3}),
			_spec({"power": 5, "toughness": 5}), _spec({"power": 9, "toughness": 9})],
		"one more keyword": [_spec({"cost": "{3}{W}"}), _spec({"cost": "{3}{W}", "keywords": ["flying"]}),
			_spec({"cost": "{3}{W}", "keywords": ["flying", "vigilance"]}),
			_spec({"cost": "{3}{W}", "keywords": ["flying", "vigilance", "first_strike"]})],
		"a cheaper body": [_spec({"cost": "{5}{G}", "power": 4, "toughness": 4}), _spec({"cost": "{3}{G}", "power": 4, "toughness": 4}),
			_spec({"cost": "{2}{G}", "power": 4, "toughness": 4}), _spec({"cost": "{G}", "power": 4, "toughness": 4})],
		"more damage": [_spell("{1}{R}", "instant", [{"effect": "damage", "amount": 1, "target": "any"}]),
			_spell("{1}{R}", "instant", [{"effect": "damage", "amount": 3, "target": "any"}]),
			_spell("{1}{R}", "instant", [{"effect": "damage", "amount": 5, "target": "any"}]),
			_spell("{1}{R}", "instant", [{"effect": "damage", "amount": 12, "target": "any"}])],
		"more cards": [_spell("{2}{U}", "sorcery", [{"effect": "draw", "amount": 1}]),
			_spell("{2}{U}", "sorcery", [{"effect": "draw", "amount": 2}]),
			_spell("{2}{U}", "sorcery", [{"effect": "draw", "amount": 3}, {"effect": "gain_life", "amount": 3}])],
		"a drawback less": [_spec({"cost": "{2}{G}", "power": 4, "toughness": 4, "rules": {"echo": "{2}{G}"}}),
			_spec({"cost": "{2}{G}", "power": 4, "toughness": 4})],
		"a cheaper sweep": [_spell("{4}{W}{W}", "sorcery", [{"effect": "destroy_all", "target": "creatures"}]),
			_spell("{2}{W}{W}", "sorcery", [{"effect": "destroy_all", "target": "creatures"}]),
			_spell("{W}", "sorcery", [{"effect": "destroy_all", "target": "creatures"}])],
		"more mana": [_spec({"cost": "{2}", "types": ["artifact"], "abilities": [{"kind": "mana", "color": "colorless", "amount": 1}]}),
			_spec({"cost": "{2}", "types": ["artifact"], "abilities": [{"kind": "mana", "color": "colorless", "amount": 2}]}),
			_spec({"cost": "{2}", "types": ["artifact"], "abilities": [{"kind": "mana", "color": "colorless", "amount": 3}]})],
	}
	for what: String in ladders:
		var last := -1
		var seen: Array[int] = []
		for spec: Dictionary in ladders[what]:
			var p := CardBalance.power(spec)
			seen.append(p)
			assert_between(p, 0, 100, what)
			assert_gte(p, last, "%s: %s" % [what, seen])
			last = p
		assert_gt(seen[-1], seen[0], "%s: the strongest scores more than the weakest: %s" % [what, seen])
	assert_between(CardBalance.power(_spec({})), 30, 70, "a bear is a usual card")
	assert_gt(CardBalance.power(_spec({"cost": "{G}", "power": 9, "toughness": 9})), 85, "beyond every card")
	assert_eq(CardBalance.power_of([] as Array[Dictionary]), 0, "nothing measured")


func test_a_whole_set_is_told_worst_first_with_its_own_remarks() -> void:
	var named := func(card_name: String, spec: Dictionary) -> Dictionary:
		spec["name"] = card_name
		return spec
	var specs: Array = [
		named.call("Set Bear", _spec({})),
		named.call("Set Giant", _spec({"cost": "{G}", "power": 9, "toughness": 9, "rarity": "rare"})),
		named.call("Set Bolt", _spell("{R}", "instant", [{"effect": "damage", "amount": 3, "target": "any"}])),
		named.call("Set Fireball", _spell("{X}{R}", "sorcery", [{"effect": "damage", "x": true, "target": "any"}], {"rarity": "uncommon"})),
		{"name": "Set Broken", "types": ["creature"]},
		"not a card",
	]
	var lines := CardBalance.set_advice(specs)
	var cards := lines.filter(func(line: Dictionary) -> bool: return line["kind"] == "card")
	var remarks := lines.filter(func(line: Dictionary) -> bool: return line["kind"] == "set")
	assert_eq(cards.map(func(line: Dictionary) -> String: return line["name"]),
		["Set Broken", "Set Giant", "Set Fireball", "Set Bear", "Set Bolt"], "worst first: %s" % str(cards))
	assert_eq(String(cards[0]["level"]), "invalid")
	assert_eq(int(cards[0]["power"]), -1)
	assert_eq(String(cards[1]["level"]), CardBalance.VERY_HIGH)
	assert_gt(int(cards[1]["power"]), 85)
	assert_eq(String(cards[2]["level"]), CardBalance.NOT_COMPARED)
	assert_eq(String(cards[3]["text"]), "Fits the game's cards.")
	for line in lines:
		for key: String in ["kind", "name", "level", "power", "topic", "text"]:
			assert_true(line.has(key), "%s in %s" % [key, line])
	assert_eq(remarks.map(func(line: Dictionary) -> String: return line["topic"]), ["Colors", "Rarities", "Types", "Curve"])
	assert_string_contains(String(remarks[0]["text"]), "2 red")
	assert_string_contains(String(remarks[0]["text"]), "2 green")
	assert_string_contains(String(remarks[1]["text"]), "2 common, 1 uncommon, 1 rare")
	assert_string_contains(String(remarks[3]["text"]), "3 at 1")
	assert_eq(CardBalance.set_advice([]), [] as Array[Dictionary], "an empty set says nothing")
	# Ten cards with a hole in the curve and a color missing: said.
	var many: Array = []
	for i in 10:
		many.append(named.call("Set Card %d" % i, _spec({"cost": "{3}{G}" if i % 2 == 0 else "{W}"})))
	var told := CardBalance.set_advice(many).filter(func(line: Dictionary) -> bool: return line["kind"] == "set")
	assert_string_contains(String(told[0]["text"]), "No blue or black or red cards.")
	assert_eq(String(told[1]["level"]), CardBalance.LOW, "no uncommons, no rares")
	assert_string_contains(String(told[3]["text"]), "Nothing costs 2 or 3 or 5.")


func test_the_table_is_quick_once_the_pool_is_counted() -> void:
	var spec := _spec({"cost": "{2}{R}", "power": 2, "toughness": 2, "keywords": ["haste"], "abilities": [
		{"kind": "trigger", "when": "enters", "effects": [{"effect": "damage", "amount": 2, "target": "any"}]},
		{"kind": "activated", "cost": "{R}", "effects": [{"effect": "pump", "power": 1, "toughness": 0, "target": "self"}]}]})
	CardBalance.advice(spec)
	var start := Time.get_ticks_usec()
	for i in 50:
		CardBalance.advice(spec)
	var each := (Time.get_ticks_usec() - start) / 50.0
	gut.p("advice(): %.2f ms a card" % (each / 1000.0))
	assert_lt(each, 20000.0, "far under a frame's worth even on a loaded machine: %.0f us" % each)
