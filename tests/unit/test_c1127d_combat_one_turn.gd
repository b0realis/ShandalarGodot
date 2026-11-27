extends GameTest
## ROUND 4 OF THE PLAYER REPORT 2026-11-26, the computer's combat
## (engine/ai/combat_reads.gd), the two items 0.70.14 left:
##  1. Corpse Dance, whose cast before our combat an older reading owns
##     (tempest_spells.gd `corpse_dance`), is given the two things that
##     reading left out — it is not cast into a blocker that stops its
##     creature cold, and it is cast into their declared attack when the
##     block is worth it (with its buyback when the mana is there);
##  2. an ABILITY that makes a creature for one turn (Zirilan of the Claw,
##     Balduvian Dead, Echo Chamber, Hornet Cannon, Sneak Attack) is
##     activated when the body can be used — before our attack, or as a
##     blocker in theirs — and at no moment the body vanishes unused.
## Each beside the gate's null arm ([member AiProfile.forecasts_tactics]
## off: the pilot as it was) or an unaffected control.

const COMBAT_READS := preload("res://engine/ai/combat_reads.gd")
const SWAMPS3 := ["Swamp", "Swamp", "Swamp"]
const SWAMPS5 := ["Swamp", "Swamp", "Swamp", "Swamp", "Swamp"]
const MOUNTAINS := ["Mountain", "Mountain", "Mountain", "Mountain", "Mountain"]
const DECK := ["Mountain", "Mountain", "Mountain", "Mountain", "Mountain", "Mountain", "Mountain",
	"Mountain", "Mountain", "Mountain"]


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _rungs() -> Array:
	var out := [AiProfile.apprentice(), AiProfile.magician(), AiProfile.sorcerer(), AiProfile.wizard()]
	for p in out: p.mistake_chance = 0.0
	return out


## The rungs that pay a card of the graveyard as a cost at all
## ([member AiProfile.plays_engines], an older gate).
func _engine_rungs() -> Array:
	return _rungs().filter(func(p: AiProfile) -> bool: return p.plays_engines)


func _null(base: AiProfile = null) -> AiProfile:
	var p := base if base != null else AiProfile.wizard()
	p.mistake_chance = 0.0
	p.forecasts_tactics = false
	return p


func _zone(pid: int, card_name: String, zone: int) -> CardInstance:
	var inst := give_hand(pid, card_name)
	g.players[pid].hand.erase(inst)
	if zone == Mtg.Zone.GRAVEYARD: g.players[pid].graveyard.append(inst)
	else: g.players[pid].library.append(inst)
	inst.zone = zone
	return inst


## One turn of the game with the pilot in seat 0. [param s]: field, grave,
## library, hand (ours); theirs (on the table), attack (theirs, declared
## on their turn); life. Ours from [param step], or theirs whole. What
## the pilot did, step by step, what attacked and blocked, and the end.
func _play(p: AiProfile, s: Dictionary, step: int, their_turn := false) -> Dictionary:
	before_each()
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	g.players[0].life = int(s.get("life", 20))
	for n in s.get("field", []): put_battlefield(0, n)
	for n in s.get("grave", []): _zone(0, n, Mtg.Zone.GRAVEYARD)
	for n in s.get("library", []): _zone(0, n, Mtg.Zone.LIBRARY)
	if s.has("thin"):   # the last [code]thin[/code] cards of the library are all of it
		while g.players[0].library.size() > int(s["thin"]): g.players[0].library.pop_front()
	var ids: Array = []
	if their_turn:
		advance_to_step(Mtg.Step.MAIN1)
		advance_to_next_turn()
	for n in s.get("theirs", []): put_battlefield(1, n)
	for n in s.get("attack", []): ids.append(put_battlefield(1, n).id)
	for n in s.get("hand", []): give_hand(0, n)
	if not their_turn: advance_to_step(step)
	var out := {"did": [], "attacked": [], "blocks": [], "dead": 0}
	var turn := g.turn_number
	var guard := 0
	while g.turn_number == turn and not g.game_over and guard < 300:
		guard += 1
		if g.awaiting_attackers:
			if g.active_player == 0:
				ai.act(g)
				for id in g.combat.attackers.keys(): out["attacked"].append(g.find_instance(id).data.card_name)
				out["attacked"].sort()
			else:
				assert_ok(g.declare_attackers(1, ids))
		elif g.awaiting_blockers:
			if g.active_player == 0: g.declare_blockers(1, {})
			else:
				ai.act(g)
				for b in g.combat.blocks:
					out["blocks"].append("%s>%s" % [g.find_instance(b).data.card_name,
						g.find_instance(int(g.combat.blocks[b])).data.card_name])
				out["blocks"].sort()
		elif g.priority_player == 0:
			var at := Mtg.step_name(g.current_step())
			var line := ai.act(g)
			if line == "": g.pass_priority(0)
			elif line != "pass" and line != "played a land": out["did"].append("%s: %s" % [at, line])
		else:
			g.pass_priority(g.priority_player)
	for id in ids:
		if g.find_instance(id) == null or g.find_instance(id).zone != Mtg.Zone.BATTLEFIELD: out["dead"] += 1
	out["life"] = g.players[0].life
	out["their_life"] = g.players[1].life
	out["hand"] = g.players[0].hand.map(func(c: CardInstance) -> String: return c.data.card_name)
	out["exile"] = g.players[0].exile.map(func(c: CardInstance) -> String: return c.data.card_name)
	return out


func _did(out: Dictionary, what: String) -> String:
	for line in out["did"]:
		if String(line).contains(what): return String(line).get_slice(":", 0)
	return ""


const MAIN_1 := "First Main"
const ATTACKERS := "Declare Attackers"


# ------------------------------------------------------- 1. Corpse Dance --

func test_the_step_names_this_file_reads() -> void:
	assert_eq(Mtg.step_name(Mtg.Step.MAIN1), MAIN_1)
	assert_eq(Mtg.step_name(Mtg.Step.DECLARE_ATTACKERS), ATTACKERS)


func test_the_dance_is_read_as_a_maker_another_reading_owns() -> void:
	var made: Dictionary = COMBAT_READS.made_for_a_turn(CardRegistry.get_card("Corpse Dance"))
	assert_true(made.has("returns") and made.has("owned") and bool(made["haste"]))
	assert_true(COMBAT_READS.made_for_a_turn(CardRegistry.get_card("Shallow Grave")).has("returns"))
	assert_true(COMBAT_READS.made_for_a_turn(CardRegistry.get_card("Waylay")).has("token"))
	for other in ["Tidal Wave", "Broken Visage", "Soulshriek", "Raise Dead", "Giant Growth", "Animate Dead",
			"Disturbed Burial", "Capsize"]:
		assert_true(COMBAT_READS.made_for_a_turn(CardRegistry.get_card(other)).is_empty(), other)


## THE OLDER RULE, PROVED: before our combat, for a body that attacks.
func test_the_dance_is_cast_before_combat_and_attacks() -> void:
	for p in _rungs():
		for theirs in [[], ["Grizzly Bears"]]:
			var did := _play(p, {"field": SWAMPS3, "grave": ["Hill Giant"], "hand": ["Corpse Dance"], "theirs": theirs}, Mtg.Step.MAIN1)
			assert_eq(_did(did, "Corpse Dance"), MAIN_1, "%s into %s: %s" % [p.profile_name, theirs, did])
			assert_eq(did["attacked"], ["Hill Giant"], p.profile_name)
			assert_eq(did["exile"], ["Hill Giant"], p.profile_name + ": exiled at the end step")


func test_the_dance_is_not_cast_for_nothing_in_our_turn() -> void:
	for p in _rungs():
		assert_eq(_did(_play(p, {"field": SWAMPS5, "grave": ["Hill Giant"], "hand": ["Corpse Dance"]}, Mtg.Step.MAIN2), "Corpse Dance"), "",
			p.profile_name + ": after combat")
		assert_eq(_did(_play(p, {"field": SWAMPS5, "hand": ["Corpse Dance"]}, Mtg.Step.MAIN1), "Corpse Dance"), "",
			p.profile_name + ": an empty graveyard")
		assert_eq(_did(_play(p, {"field": SWAMPS5, "grave": ["Wall of Stone"], "hand": ["Corpse Dance"]}, Mtg.Step.MAIN1), "Corpse Dance"), "",
			p.profile_name + ": a defender")
		assert_eq(_did(_play(p, {"field": SWAMPS5, "grave": ["Mons's Goblin Raiders"], "hand": ["Corpse Dance"]}, Mtg.Step.MAIN1), "Corpse Dance"), "",
			p.profile_name + ": a 1/1 is no attack")


## NEW: the blocker that stops the body cold (the older rule cast into it).
func test_the_dance_is_not_cast_into_a_cold_stop() -> void:
	var board := {"field": SWAMPS5, "grave": ["Hill Giant"], "hand": ["Corpse Dance"], "theirs": ["Wall of Stone"]}
	for p in _rungs():
		assert_eq(_did(_play(p, board, Mtg.Step.MAIN1), "Corpse Dance"), "", p.profile_name)
	assert_eq(_did(_play(_null(), board, Mtg.Step.MAIN1), "Corpse Dance"), MAIN_1, "gate off: the pilot as it was")


## The buyback is paid when the mana is there (the pilot's older rule).
func test_the_dance_pays_its_buyback_when_it_can() -> void:
	for p in _rungs():
		var rich := _play(p, {"field": SWAMPS5, "grave": ["Hill Giant"], "hand": ["Corpse Dance"]}, Mtg.Step.MAIN1)
		assert_eq(rich["hand"], ["Corpse Dance"], "%s, five lands: %s" % [p.profile_name, rich])
		assert_eq(rich["attacked"], ["Hill Giant"], p.profile_name)
		var poor := _play(p, {"field": SWAMPS3, "grave": ["Hill Giant"], "hand": ["Corpse Dance"]}, Mtg.Step.MAIN1)
		assert_eq(poor["hand"], [], "%s, three lands" % p.profile_name)


## NEW: their declared attack, and a block worth the card.
func test_the_dance_ambushes_a_declared_attack() -> void:
	for p in _rungs():
		var did := _play(p, {"field": SWAMPS3, "grave": ["Hill Giant"], "hand": ["Corpse Dance"], "attack": ["Grizzly Bears"]}, 0, true)
		assert_eq(_did(did, "Corpse Dance"), ATTACKERS, "%s: %s" % [p.profile_name, did])
		assert_eq(did["blocks"], ["Hill Giant>Grizzly Bears"], p.profile_name)
		assert_eq([did["dead"], did["life"]], [1, 20], p.profile_name)
		# ...and with the buyback's mana on the table the card comes back.
		did = _play(p, {"field": SWAMPS5, "grave": ["Hill Giant"], "hand": ["Corpse Dance"], "attack": ["Grizzly Bears"]}, 0, true)
		assert_eq(_did(did, "Corpse Dance"), ATTACKERS, "%s: %s" % [p.profile_name, did])
		assert_eq([did["dead"], did["hand"]], [1, ["Corpse Dance"]], "%s: %s" % [p.profile_name, did])
	var was := _play(_null(), {"field": SWAMPS3, "grave": ["Hill Giant"], "hand": ["Corpse Dance"], "attack": ["Grizzly Bears"]}, 0, true)
	assert_eq(_did(was, "Corpse Dance"), "", "gate off")


func test_the_dance_keeps_us_alive() -> void:
	for p in _rungs():
		var did := _play(p, {"field": SWAMPS3, "grave": ["Wall of Stone"], "hand": ["Corpse Dance"], "attack": ["Craw Wurm"], "life": 6}, 0, true)
		assert_eq(_did(did, "Corpse Dance"), ATTACKERS, "%s: %s" % [p.profile_name, did])
		assert_eq(did["life"], 6, p.profile_name)


func test_the_dance_stays_in_hand_when_the_block_buys_nothing() -> void:
	for p in _rungs():
		for attack in [[], ["Scryb Sprites"]]:
			var did := _play(p, {"field": SWAMPS5, "grave": ["Hill Giant"], "hand": ["Corpse Dance"], "attack": attack}, 0, true)
			assert_eq(_did(did, "Corpse Dance"), "", "%s against %s: %s" % [p.profile_name, attack, did])
		# A bad card on top: a 1/1 before a Craw Wurm at twenty.
		var did := _play(p, {"field": SWAMPS3, "grave": ["Mons's Goblin Raiders"], "hand": ["Corpse Dance"], "attack": ["Craw Wurm"]}, 0, true)
		assert_eq(_did(did, "Corpse Dance"), "", "%s: %s" % [p.profile_name, did])


# ------------------------------- 2. the ability that makes a one-turn body --

func _line_of(card: String, index := 0) -> String:
	return CardRegistry.get_card(card).activated_abilities[index].text


func test_the_shape_is_read_off_the_ability_s_line() -> void:
	for card in ["Zirilan of the Claw", "Echo Chamber", "Balduvian Dead", "Hornet Cannon", "Sneak Attack",
			"Apprentice Necromancer"]:
		assert_true(COMBAT_READS.one_turn_line(_line_of(card)), "%s: %s" % [card, _line_of(card)])
	for card in ["Dark Maze", "Varchild's Crusader", "Barbarian Guides", "Rod of Ruin", "The Hive",
			"Elvish Piper", "Kjeldoran Outpost", "Thawing Glaciers", "Mishra's Factory"]:
		var data := CardRegistry.get_card(card)
		for index in data.activated_abilities.size():
			assert_false(COMBAT_READS.one_turn_line(_line_of(card, index)), "%s: %s" % [card, _line_of(card, index)])


## THE SWEEP: every card of the pool with such an ability.
func test_the_pool_has_these_and_no_other() -> void:
	var found: Array = []
	for card_name in CardRegistry.all_names():
		var data := CardRegistry.get_card(card_name)
		for ability in data.activated_abilities:
			if COMBAT_READS.one_turn_line(ability.text) and not found.has(card_name): found.append(card_name)
	found.sort()
	assert_eq(found, ["Apprentice Necromancer", "Balduvian Dead", "Echo Chamber", "Hornet Cannon", "Sneak Attack",
		"Zirilan of the Claw"])


func _zirilan(extra := {}) -> Dictionary:
	var s := {"field": MOUNTAINS + ["Zirilan of the Claw"], "library": DECK + ["Shivan Dragon"]}
	s.merge(extra, true)
	return s


func test_zirilan_calls_a_dragon_before_our_attack() -> void:
	for p in _rungs():
		for theirs in [[], ["Hill Giant"]]:
			var did := _play(p, _zirilan({"theirs": theirs}), Mtg.Step.MAIN1)
			assert_eq(_did(did, "Zirilan"), MAIN_1, "%s into %s: %s" % [p.profile_name, theirs, did])
			assert_eq(did["attacked"], ["Shivan Dragon"], p.profile_name)
			assert_eq(did["exile"], ["Shivan Dragon"], p.profile_name)
	var was := _play(_null(), _zirilan(), Mtg.Step.MAIN1)
	assert_eq([_did(was, "Zirilan"), was["attacked"]], ["", ["Zirilan of the Claw"]], "gate off: never activated")


func test_zirilan_calls_no_dragon_for_nothing() -> void:
	for p in _rungs():
		assert_eq(_did(_play(p, _zirilan(), Mtg.Step.MAIN2), "Zirilan"), "", p.profile_name + ": after combat")
		assert_eq(_did(_play(p, _zirilan(), 0, true), "Zirilan"), "", p.profile_name + ": their turn, no attack")
		assert_eq(_did(_play(p, _zirilan({"library": DECK}), Mtg.Step.MAIN1), "Zirilan"), "",
			p.profile_name + ": no Dragon in the library")
		# A Dragon that is stopped cold: a flier with first strike before a 2/2 Whelp.
		assert_eq(_did(_play(p, _zirilan({"library": DECK + ["Dragon Whelp"], "theirs": ["Serra Angel"]}), Mtg.Step.MAIN1),
			"Zirilan"), "", p.profile_name + ": into a flier that stops it cold")
		# A library that is the clock.
		assert_eq(_did(_play(p, _zirilan({"thin": 5}), Mtg.Step.MAIN1),
			"Zirilan"), "", p.profile_name + ": a thin library")


func test_zirilan_calls_a_blocker_into_their_attack() -> void:
	for p in _rungs():
		# A Craw Wurm at six life: Zirilan in its way dies for it, the
		# Dragon for one turn kills it and costs nothing that stays.
		var did := _play(p, _zirilan({"attack": ["Craw Wurm"], "life": 6}), 0, true)
		assert_eq(_did(did, "Zirilan"), ATTACKERS, "%s: %s" % [p.profile_name, did])
		assert_false(g.game_over, p.profile_name)
		assert_true(did["blocks"].has("Shivan Dragon>Craw Wurm"), "%s: %s" % [p.profile_name, did])
		assert_eq([did["dead"], did["life"]], [1, 6], p.profile_name)
		# Two of them: the tap takes Zirilan out of the other's way, and nothing is called.
		did = _play(p, _zirilan({"attack": ["Craw Wurm", "Craw Wurm"], "life": 6}), 0, true)
		assert_eq(_did(did, "Zirilan"), "", "%s: %s" % [p.profile_name, did])
	assert_eq(_did(_play(_null(), _zirilan({"attack": ["Craw Wurm"], "life": 6}), 0, true), "Zirilan"), "", "gate off")


func _dead(extra := {}) -> Dictionary:
	var s := {"field": MOUNTAINS + ["Balduvian Dead"], "grave": ["Grizzly Bears"]}
	s.merge(extra, true)
	return s


func test_the_graveborn_is_made_for_an_attack() -> void:
	for p in _engine_rungs():
		var did := _play(p, _dead(), Mtg.Step.MAIN1)
		assert_eq(_did(did, "Balduvian Dead"), MAIN_1, "%s: %s" % [p.profile_name, did])
		assert_true(did["attacked"].has("Graveborn"), p.profile_name)
		# NEW: not into a wall that stops it cold, not after combat.
		did = _play(p, _dead({"theirs": ["Wall of Stone"]}), Mtg.Step.MAIN1)
		assert_eq(_did(did, "Balduvian Dead"), "", "%s into a Wall: %s" % [p.profile_name, did])
		assert_eq(_did(_play(p, _dead(), Mtg.Step.MAIN2), "Balduvian Dead"), "", p.profile_name + ": after combat")
		var was := _play(_null(p), _dead({"theirs": ["Wall of Stone"]}), Mtg.Step.MAIN1)
		assert_eq(_did(was, "Balduvian Dead"), MAIN_1 if p.forecasts_tactics else "", p.profile_name)


func test_the_graveborn_is_made_as_a_blocker() -> void:
	for p in _engine_rungs():
		# Two Hill Giants: our 2/3 holds one, a 3/1 for one turn kills the other.
		var did := _play(p, _dead({"attack": ["Hill Giant", "Hill Giant"]}), 0, true)
		assert_eq(_did(did, "Balduvian Dead"), ATTACKERS, "%s: %s" % [p.profile_name, did])
		assert_true(did["blocks"].has("Graveborn>Hill Giant"), "%s: %s" % [p.profile_name, did])
		assert_gt(did["dead"], 0, p.profile_name)
		# No attack, a flier it cannot block: nothing is made.
		for attack in [[], ["Scryb Sprites"]]:
			did = _play(p, _dead({"attack": attack}), 0, true)
			assert_eq(_did(did, "Balduvian Dead"), "", "%s against %s: %s" % [p.profile_name, attack, did])


func test_the_chamber_echoes_only_a_body_that_attacks() -> void:
	for p in _rungs():
		var did := _play(p, {"field": MOUNTAINS + ["Echo Chamber"], "theirs": ["Craw Wurm"]}, Mtg.Step.MAIN1)
		assert_eq(_did(did, "Echo Chamber"), MAIN_1, "%s: %s" % [p.profile_name, did])
		assert_eq(did["attacked"], ["Craw Wurm"], p.profile_name)
		# NEW: the copy of a defender attacks nothing.
		did = _play(p, {"field": MOUNTAINS + ["Echo Chamber"], "theirs": ["Wall of Stone"]}, Mtg.Step.MAIN1)
		assert_eq(_did(did, "Echo Chamber"), "", "%s: %s" % [p.profile_name, did])
		# A sorcery-speed ability is no blocker: their attack asks nothing of it.
		did = _play(p, {"field": MOUNTAINS + ["Echo Chamber"], "attack": ["Craw Wurm"], "life": 6}, 0, true)
		assert_eq(_did(did, "Echo Chamber"), "", "%s: %s" % [p.profile_name, did])


func test_the_hornet_blocks_when_the_block_is_the_game() -> void:
	for p in _rungs():
		var did := _play(p, {"field": MOUNTAINS + ["Hornet Cannon"], "attack": ["Hill Giant"], "life": 3}, 0, true)
		assert_eq(_did(did, "Hornet Cannon"), ATTACKERS, "%s: %s" % [p.profile_name, did])
		assert_eq(did["life"], 3, p.profile_name)
		# ...and not at their end step, for a Hornet that is destroyed there.
		did = _play(p, {"field": MOUNTAINS + ["Hornet Cannon"]}, 0, true)
		assert_eq(_did(did, "Hornet Cannon"), "", "%s: %s" % [p.profile_name, did])
