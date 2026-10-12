extends GameTest
## DARK RITUAL INTO NOTHING (robustness campaign 2026-10-12, b5-4;
## [member AiProfile.forecasts_tactics]).
##
## [method AiPlayer._ritual_has_a_use] answered "yes" whenever the Ritual's
## mana made some card in hand castable and worth aiming — and a held
## instant counts: a Terror kept for the opponent's turn licensed the
## Ritual, then the main-phase ranking held that very Terror, and the three
## black mana burned (16 of 86 resolved Rituals in the Lab). The licence now
## asks the ranking's own waits too — the held instant, the reserve's 1.5x
## rule, the counter gate, the one-ply veto — so the Ritual is cast only for
## a card the ranking would then cast. And when mana is floating under a
## mana-burn rule and nothing else ranks, a held instant that the floating
## mana pays for is cast rather than let the pool burn. Gate off: the old
## readings. The opponent's hidden hand never moves the answer.


func _burned(seat: int) -> Array:
	var burned := [0]
	g.event_occurred.connect(func(e: GameEvent) -> void:
		if e.type == Mtg.EventType.MANA_BURN and int(e.data.get("player", -1)) == seat:
			burned[0] += int(e.data.get("amount", 0)))
	return burned


## Our first main phase until the AI passes, then out of it (so a pool left
## floating burns under the mana-burn presets).
func _main_then_leave(ai: AiPlayer) -> Array:
	var lines: Array = []
	var turn := g.turn_number
	for k in 30:
		if g.game_over or g.turn_number != turn or g.current_step() != Mtg.Step.MAIN1:
			break
		if g.priority_player == 0:
			var did := ai.act(g)
			lines.append(did)
			if did == "" or did == "pass":
				break
		else:
			g.pass_priority(g.priority_player)
		resolve_stack()
	var guard := 0
	while g.current_step() == Mtg.Step.MAIN1 and not g.game_over and guard < 20:
		_advance_once()
		guard += 1
	return lines


func _pilot(profile: AiProfile, on := true) -> AiPlayer:
	profile.mistake_chance = 0.0
	profile.forecasts_tactics = on
	var ai := AiPlayer.new(0, profile)
	g.set_agent(0, ai)
	return ai


## The Lab's turn 7 (blue_skies v black_red_raiders, seed 61181): three
## Swamps, Drudge Skeletons, Dark Ritual, Terror, Fireball and two
## Lightning Bolts — and no red source. Their two Merfolk are tapped.
func _raiders(preset: String, on := true, their_hand: Array = []) -> Dictionary:
	before_each()
	g.rules.set_preset(preset)
	var ai := _pilot(AiProfile.wizard(), on)
	g.players[0].life = 18
	g.players[1].life = 19
	for i in 3: put_battlefield(0, "Swamp")
	var ritual: CardInstance = null
	for n in ["Drudge Skeletons", "Dark Ritual", "Terror", "Fireball", "Lightning Bolt", "Lightning Bolt"]:
		var c := give_hand(0, n)
		if n == "Dark Ritual": ritual = c
	put_battlefield(1, "Island")
	put_battlefield(1, "Island")
	var m1 := put_battlefield(1, "Merfolk of the Pearl Trident")
	var m2 := put_battlefield(1, "Merfolk of the Pearl Trident")
	for n in their_hand: give_hand(1, n)
	advance_to_step(Mtg.Step.MAIN1)
	m1.tapped = true
	m2.tapped = true
	var burned := _burned(0)
	var lines := _main_then_leave(ai)
	return {"lines": lines, "burned": burned[0], "ritual": ritual.zone}


func test_a_held_terror_does_not_license_the_ritual() -> void:
	for preset in ["fifth", "modern_mana_burn"]:
		var r := _raiders(preset)
		assert_eq(int(r["burned"]), 0, "%s: no Ritual mana burns (%s)" % [preset, r["lines"]])
		assert_eq(int(r["ritual"]), Mtg.Zone.HAND, "%s: the Ritual stays in hand" % preset)


func test_the_null_arm_keeps_the_old_licence() -> void:
	# Gate off, the old reading (the Ritual is worth the card it makes
	# castable by printed worth) — pinned so the null arm is the null.
	var r := _raiders("fifth", false)
	assert_eq(int(r["ritual"]), Mtg.Zone.GRAVEYARD, "gate off: the Ritual is cast (%s)" % [r["lines"]])


func test_their_hidden_hand_does_not_move_the_ritual() -> void:
	var seen: Array = []
	for their_hand in [[], ["Counterspell", "Phantom Monster"], ["Mahamoti Djinn", "Braingeyser", "Psionic Blast"]]:
		seen.append(_raiders("fifth", true, their_hand)["lines"])
	assert_eq(seen[1], seen[0], "a hidden counter changed the play")
	assert_eq(seen[2], seen[0], "a hidden hand changed the play")


func test_the_magician_keeps_terror_for_their_dragon() -> void:
	# modern_mana_burn, seed 61133 turn 12: Swamp + Ritual with Shivan
	# Dragon, Terror and a Bolt in hand, five lands; their Shivan Dragon
	# across the table. The Dragon would tap the Terror's mana out — the
	# reserve's own rule — so the Ritual buys nothing.
	g.rules.set_preset("modern_mana_burn")
	var ai := _pilot(AiProfile.magician())
	for n in ["Mountain", "Mountain", "Mountain", "Swamp", "Swamp"]:
		put_battlefield(0, n)
	put_battlefield(0, "Scathe Zombies")
	for n in ["Dark Ritual", "Terror", "Shivan Dragon", "Lightning Bolt"]:
		give_hand(0, n)
	for i in 6: put_battlefield(1, "Mountain")
	put_battlefield(1, "Icy Manipulator")
	put_battlefield(1, "Shivan Dragon", true)
	advance_to_step(Mtg.Step.MAIN1)
	var burned := _burned(0)
	var lines := _main_then_leave(ai)
	assert_eq(burned[0], 0, "no Ritual mana burns (%s)" % [lines])


func test_a_ritual_that_really_enables_a_cast_is_still_cast() -> void:
	# Three Swamps, Dark Ritual and Sengir Vampire: the Ritual's {B}{B}{B}
	# and two Swamps are the Vampire's five.
	for preset in ["fifth", "modern_mana_burn"]:
		before_each()
		g.rules.set_preset(preset)
		var p := AiProfile.wizard()
		p.develops_late = false
		var ai := _pilot(p)
		for i in 3: put_battlefield(0, "Swamp")
		var ritual := give_hand(0, "Dark Ritual")
		var vampire := give_hand(0, "Sengir Vampire")
		advance_to_step(Mtg.Step.MAIN1)
		var burned := _burned(0)
		var lines := _main_then_leave(ai)
		assert_eq(ritual.zone, Mtg.Zone.GRAVEYARD, "%s: the Ritual is cast (%s)" % [preset, lines])
		assert_eq(vampire.zone, Mtg.Zone.BATTLEFIELD, "%s: and the Vampire with it" % preset)
		assert_eq(burned[0], 0, "%s: nothing burns" % preset)


## {B}{B}{B} floating in our first main phase (a Ritual resolved, then the
## plan it was cast for went away), a Terror in hand, their Bears on the
## table and nothing else to cast.
func _floating(preset: String, on := true) -> Dictionary:
	before_each()
	g.rules.set_preset(preset)
	var p := AiProfile.wizard()
	p.develops_late = false
	var ai := _pilot(p, on)
	var terror := give_hand(0, "Terror")
	var bears := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 3)
	var burned := _burned(0)
	var lines := _main_then_leave(ai)
	return {"lines": lines, "burned": burned[0], "terror": terror.zone, "bears": bears.zone}


func test_floating_mana_casts_the_held_instant_rather_than_burn() -> void:
	for preset in ["fifth", "modern_mana_burn"]:
		var on := _floating(preset)
		assert_eq(int(on["terror"]), Mtg.Zone.GRAVEYARD, "%s: the Terror is cast (%s)" % [preset, on["lines"]])
		assert_eq(int(on["bears"]), Mtg.Zone.GRAVEYARD, "%s: at their Bears" % preset)
		assert_eq(int(on["burned"]), 1, "%s: only the {B} the Terror does not need burns" % preset)
		var off := _floating(preset, false)
		assert_eq(int(off["terror"]), Mtg.Zone.HAND, "%s, gate off: the old hold (%s)" % [preset, off["lines"]])


func test_without_mana_burn_the_instant_keeps_its_moment() -> void:
	# Under the modern rules the pool empties for nothing: no life is lost
	# and the Terror waits for their turn as before.
	var r := _floating("modern")
	assert_eq(int(r["terror"]), Mtg.Zone.HAND, "modern: the Terror waits (%s)" % [r["lines"]])
	assert_eq(int(r["burned"]), 0)
