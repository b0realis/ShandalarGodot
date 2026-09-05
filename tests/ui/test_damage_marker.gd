extends GutTest
## THE DAMAGE MARKER — `docs/duel-todo.md` §6.20b, the UI half of §6.8.
##
## `Duel.hlp` says the same sentence in three topics, and every one of them
## is a list of what a target may BE: *"When you're prompted, click on any
## valid target — a card, A DAMAGE MARKER, or whatever."* (**Using Land**,
## **Spells**, **Effects**.) The manual says what one looks like (p.119):
## *"a damage marker — a yellow 'card' on or near the target of that
## damage"*, and the original's own prompt for clicking one calls it a
## card too — `@CIRCLE_OF_PROTECTION`, `Program/prompts.txt:185`:
## **`Select damage card.`**
##
## Before this widget the duel screen could only auto-take a LONE waiting
## packet (§3.3's gesture) and gave up entirely on two or more, so a Circle
## of Protection fell back to its colour shield exactly when the choice
## mattered most. That is the regression these tests exist to make
## impossible; `docs/ROADMAP.md`'s "No damage-MARKER widget" row is closed
## by them.


var screen: DuelScreen
## The seat under test. The duel screen tosses a coin in `_new_game`, so
## which seat opens with priority differs run to run — reading it back is
## what keeps these deterministic (the lesson `test_auto_target.gd`
## records).
var me := 0
var foe := 1


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	me = screen.game.priority_player
	foe = screen.game.opponent_of(me)


# ------------------------------------------------------------- the board --

func _summon(pid: int, card_name: String) -> CardInstance:
	var g: MtgGame = screen.game
	var data := CardRegistry.get_card(card_name)
	assert_not_null(data, card_name)
	var inst := CardInstance.new(data, g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, pid)
	g.recalculate()
	return inst


## Turn the RULES FORK on. The duel screen's hotseat default seats a
## [HumanAgent] at both ends and every human seat asks for the window, so
## the fork is the only gate left to open.
func _arm() -> void:
	screen.game.rules.damage_prevention_window = true


## Deal [param amount] from a fresh [param card_name] of the opponent's at
## our own seat, and leave it WAITING. With the window armed the packet is
## queued rather than landed, which is the whole of `deal_damage`'s new
## first half (§6.8 slice 1).
func _incoming(card_name: String, amount: int) -> DamagePacket:
	var source := _summon(foe, card_name)
	screen.game.deal_damage(source, TargetRef.player(me), amount)
	return screen.game.damage_pending.back()


## Reach the next priority, which is where `_open_priority` actually OPENS
## the window over whatever is waiting.
func _reach_the_window() -> void:
	var g: MtgGame = screen.game
	for _i in 2:
		if g.awaiting_damage_prevention:
			break
		g.pass_priority(g.priority_player)
	screen._refresh()


func _markers() -> Array[DamageMarker]:
	return screen._damage_markers.markers()


# ------------------------------------------------------- the marker itself --

func test_a_marker_is_exactly_one_card_size_and_never_rescaled() -> void:
	# The one-card-size rule is about what the TABLE looks like, not about
	# which class drew it: a marker sits between cards, so it is a card's
	# size or it breaks the rule in the only way the rule is about.
	var packet := DamagePacket.new()
	packet.amount = 3
	packet.target = TargetRef.player(0)
	var marker := DamageMarker.new(packet)
	autofree(marker)
	assert_eq(marker.size, MiniCard.SIZE, "one card size")
	assert_eq(marker.custom_minimum_size, MiniCard.SIZE)
	assert_eq(marker.scale, Vector2.ONE, "never rescaled")
	assert_eq(marker.rotation, 0.0, "and never turned — only a tap turns")


func test_a_marker_names_its_source_and_its_remaining_amount() -> void:
	# The two things that tell two packets apart, which is the entire
	# decision the 1997 window exists to put to the player.
	_arm()
	var packet := _incoming("Hill Giant", 3)
	var marker := DamageMarker.new(packet, screen.game)
	autofree(marker)
	assert_eq(marker.source_name(), "Hill Giant")
	assert_eq(marker._amount_label.text, "3")
	# "You may use the Circle on the same damage more than once", so a
	# partly-answered packet has to show what is LEFT to answer.
	packet.prevent(2)
	marker.refresh()
	assert_eq(marker._amount_label.text, "1", "what is still coming")


func test_the_marker_carries_the_1997_cue_cards() -> void:
	# `@CUECARD_SMALLCARD` (`UIStrings.txt:732`) declares TEN states and
	# two of them are about damage. `Damage: %d` is the one [MiniCard]
	# already draws on a wounded creature; `Damage to player` is the one
	# `docs/duel-todo.md` §2.10 assigned to the life register — which
	# cannot be right, because `@CUECARD_LIFE` (`:678`) declares its eight
	# entries and that is not among them. It belongs to the marker.
	var to_player := DamagePacket.new()
	to_player.amount = 4
	to_player.target = TargetRef.player(1)
	var one := DamageMarker.new(to_player)
	autofree(one)
	assert_eq(one.cue_card(), "Damage to player")
	assert_eq(one.cue_card(), DamageMarker.CUE_PLAYER)
	assert_false(MiniCard.STATE_CUE.values().has("Damage to player"),
		"the small card cannot answer it; the marker can")
	_arm()
	var bear := _summon(me, "Grizzly Bears")
	var gun := _summon(foe, "Hill Giant")
	screen.game.deal_damage(gun, TargetRef.card(bear), 2)
	var two := DamageMarker.new(screen.game.damage_pending.back(), screen.game)
	autofree(two)
	assert_eq(two.cue_card(), "Damage: 2")
	assert_eq(two.victim_name(), "Grizzly Bears")


# ------------------------------------------------------------- the layer --

func test_no_markers_while_no_damage_waits() -> void:
	# The modern default, and the whole rest of the game: nothing is ever
	# queued, so there is nothing yellow on the table.
	screen._refresh()
	assert_eq(_markers().size(), 0)


func test_one_marker_per_waiting_packet_and_they_read_apart() -> void:
	_arm()
	_summon(me, "Circle of Protection: Red")
	_incoming("Hill Giant", 3)
	_incoming("Goblin Balloon Brigade", 1)
	_reach_the_window()
	assert_true(screen.game.awaiting_damage_prevention, "the window is open")
	var markers := _markers()
	assert_eq(markers.size(), 2, "one marker per packet")
	var seen := PackedStringArray()
	for marker in markers:
		seen.append("%s %s" % [marker.source_name(), marker._amount_label.text])
	assert_true(seen.has("Hill Giant 3"), str(seen))
	assert_true(seen.has("Goblin Balloon Brigade 1"), str(seen))


func test_the_markers_clear_when_the_window_closes() -> void:
	_arm()
	_summon(me, "Circle of Protection: Red")
	_incoming("Hill Giant", 3)
	_incoming("Goblin Balloon Brigade", 1)
	_reach_the_window()
	assert_eq(_markers().size(), 2)
	var life: int = screen.game.players[me].life
	var g: MtgGame = screen.game
	while g.awaiting_damage_prevention or g.awaiting_regeneration:
		g.end_damage_prevention(g.priority_player)   # @PROMPT_ENDHEALING
	screen._refresh()
	assert_eq(_markers().size(), 0, "the table is clear again")
	assert_eq(g.players[me].life, life - 4, "and both packets landed at once")


func test_a_marker_hangs_off_the_seat_its_damage_is_aimed_at() -> void:
	# Manual p.119: *"on or near the target of that damage"*. A player's
	# damage anchors on the life register — the same anchor the arrows use
	# and the one `Duel.hlp` tells the player to click for a player target.
	_arm()
	_summon(me, "Circle of Protection: Red")
	_incoming("Hill Giant", 3)
	_reach_the_window()
	await get_tree().process_frame
	var marker: DamageMarker = _markers()[0]
	assert_true(marker.visible, "a marker with an anchor is drawn")
	var register := TargetArrows.anchor_rect(screen._life_buttons[me])
	var here := marker.get_global_rect()
	assert_lt(absf(here.get_center().x - register.get_center().x),
		MiniCard.SIZE.x, "over its own life register, not the far side")


# --------------------------------------------------------- the click path --

## Activate the Circle of Protection on the board, which is what opens a
## [constant TargetSpec.Kind.DAMAGE] slot.
func _use_the_circle(circle: CardInstance) -> void:
	screen.game.players[me].mana_pool.add(Mtg.ManaColor.C, 1)
	screen._ability_menu.set_meta("instance_id", circle.id)
	screen._on_ability_chosen(circle.cur_mana_abilities.size())


func test_two_packets_open_targeting_instead_of_giving_up() -> void:
	# THE WHOLE POINT. This used to take NO target and fall back to the
	# colour shield, which is a different card (`docs/ROADMAP.md`).
	_arm()
	var circle := _summon(me, "Circle of Protection: Red")
	var big := _incoming("Hill Giant", 3)
	_incoming("Goblin Balloon Brigade", 1)
	_reach_the_window()
	_use_the_circle(circle)
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING,
		"with a choice to make, the player makes it")
	assert_eq(screen._prompt_label.text, "Select damage card.",
		"@CIRCLE_OF_PROTECTION, prompts.txt:185")
	# Both markers are lit as legal choices — both sources are red.
	for marker in _markers():
		assert_eq(marker.highlight(), MiniCard.Highlight.TARGET_LEGAL,
			marker.source_name())
	# ...and clicking one names exactly that packet.
	for marker in _markers():
		if marker.packet == big:
			marker.pressed.emit()
			break
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL, "the ability was submitted")
	var top: StackItem = screen.game.stack.back()
	assert_eq(top.kind, Mtg.StackKind.ABILITY)
	assert_eq(top.targets.size(), 1)
	assert_true(top.targets[0].is_damage, "damage, not a card")
	assert_eq(top.targets[0].packet_id, big.id, "the one that was clicked")


func test_the_chosen_marker_wears_the_chosen_frame() -> void:
	# A marker is a target like any other, so it uses the SAME frame
	# vocabulary a card does (manual p.128's colour code, via
	# [enum MiniCard.Highlight]).
	_arm()
	var circle := _summon(me, "Circle of Protection: Red")
	_incoming("Hill Giant", 3)
	_incoming("Goblin Balloon Brigade", 1)
	_reach_the_window()
	_use_the_circle(circle)
	# Deselect nothing, just report what a legal-but-unchosen marker wears
	# and what an untargetable one would: green is only for a chosen ref,
	# which this slot closes the instant it is picked (max 1).
	assert_eq(_markers()[0].highlight(), MiniCard.Highlight.TARGET_LEGAL)
	screen._on_cancel()
	screen._refresh()
	assert_eq(_markers()[0].highlight(), MiniCard.Highlight.OPTIONAL,
		"nothing is being aimed: the marker is just a thing you may act on")


func test_only_the_packets_this_circle_can_answer_light_up() -> void:
	# A Circle of Protection: Red is offered nothing by a GREEN packet —
	# that marker stays unlit and the click is refused with the original's
	# own word (§6.10). TWO red packets, because with only one the lone-
	# target gesture would take it before the player saw the table: the
	# filter is applied to the CANDIDATE LIST, not merely to the click.
	_arm()
	var circle := _summon(me, "Circle of Protection: Red")
	_incoming("Hill Giant", 3)                 # red
	_incoming("Goblin Balloon Brigade", 1)     # red
	var green := _incoming("Craw Wurm", 6)
	_reach_the_window()
	_use_the_circle(circle)
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	for marker in _markers():
		if marker.packet == green:
			assert_eq(marker.target_state(), MiniCard.State.CANT_TARGET,
				"the green packet wears the original's circle-slash")
		else:
			assert_eq(marker.highlight(), MiniCard.Highlight.TARGET_LEGAL,
				marker.source_name())
			assert_eq(marker.target_state(), -1, marker.source_name())
	for marker in _markers():
		if marker.packet == green:
			marker.pressed.emit()
			break
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING, "still aiming")
	assert_true(screen._prompt_label.text.begins_with("Illegal target"),
		screen._prompt_label.text)


func test_the_lone_packet_is_still_taken_without_aiming() -> void:
	# §3.3's gesture, kept: one legal packet is not a decision.
	_arm()
	var circle := _summon(me, "Circle of Protection: Red")
	var only := _incoming("Hill Giant", 3)
	_reach_the_window()
	_use_the_circle(circle)
	assert_ne(screen.mode, DuelScreen.Mode.TARGETING,
		"the only sensible target needs no aiming")
	var top: StackItem = screen.game.stack.back()
	assert_eq(top.targets.size(), 1)
	assert_eq(top.targets[0].packet_id, only.id)


func test_with_no_window_the_circle_still_puts_up_its_shield() -> void:
	# The MODERN default: no packets exist, the OPTIONAL damage slot goes
	# untaken, and the card is the one it has always been.
	var circle := _summon(me, "Circle of Protection: Red")
	_use_the_circle(circle)
	assert_ne(screen.mode, DuelScreen.Mode.TARGETING)
	var top: StackItem = screen.game.stack.back()
	assert_eq(top.targets.size(), 0, "nothing to point at, so nothing named")
