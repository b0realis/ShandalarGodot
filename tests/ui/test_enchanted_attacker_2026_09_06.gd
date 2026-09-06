extends GutTest
## THE ATTACK THAT WAS NEVER DECLARED — the playtest defect of 2026-09-06.
##
## *"I had Hurloon Minotaur with The Brute enchantment on it. I attacked
## and no blocker was declared and no other cards in play. My damage did
## not go through to opponent life as it should!"*
##
## The engine deals that damage correctly — every one of the 47 Auras in
## the pool that can sit on a vanilla creature was swept through an
## unblocked attack (only Gaseous Form stops the damage, as printed), and
## whole duels played through this screen with Minotaurs, Brutes and an
## opponent holding nothing but Swamps land every point. The ATTACK was
## never declared.
##
## HOW A CLICK ON AN ENCHANTED CREATURE COULD MISS IT. Since the
## forty-first pass an attachment is drawn as a WHOLE CARD behind its host
## ([constant DuelScreen.AURA_PEEK]) — offset 6px right and 18px UP, so
## the aura's title bar stands proud of the creature's top edge and the
## two read as one stack, which is what the original and s30 both draw.
## That title bar is a live [MiniCard] button wired to
## [method DuelScreen._on_card_clicked]. In [enum DuelScreen.Mode]
## ATTACKERS the click reached [method DuelScreen._toggle_attacker], which
## opens `if not inst.is_creature(): return` — no selection, no Combat
## window, and NOT ONE WORD on the Situation Bar. Done then declared no
## attackers, the engine skipped straight to the end of combat (there are
## no blockers to declare against nobody), and the defender's life never
## moved. Every sentence of the report follows from that.
##
## THE RULE THIS PINS: in the three combat gestures — choose attackers,
## choose blockers, divide damage — a click on an ATTACHED card is a click
## on the creature it is attached to. Outside them it is not: the aura is
## its own object, Disenchant targets it, and The Brute's own
## {R}{R}{R} regeneration is activated by clicking that same band.

var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.stops.clear_all()


func _summon(card_name: String, pid: int) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name),
		g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, pid)
	inst.summoning_sick = false
	return inst


## An aura from [param pid]'s hand, put onto [param host].
func _enchant(card_name: String, host: CardInstance, pid: int) -> CardInstance:
	var g: MtgGame = screen.game
	var aura := CardInstance.new(CardRegistry.get_card(card_name),
		g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[aura.id] = aura
	aura.zone = Mtg.Zone.HAND
	g.players[pid].hand.append(aura)
	g.attach_aura_from_anywhere(aura, host, pid)
	return aura


## OUR turn, the engine waiting on our attack declaration.
func _attackers_moment() -> void:
	var g: MtgGame = screen.game
	g.active_player = 0
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS)
	g.awaiting_attackers = true
	screen.mode = DuelScreen.Mode.ATTACKERS


## THEIR turn, the engine waiting on our blocks.
func _blockers_moment() -> void:
	var g: MtgGame = screen.game
	g.active_player = 1
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_BLOCKERS)
	g.awaiting_blockers = true
	screen.mode = DuelScreen.Mode.BLOCKERS


# ============================================== THE OWNER'S ATTACK --

func test_the_owners_gesture_reaches_the_engine() -> void:
	var g: MtgGame = screen.game
	var minotaur := _summon("Hurloon Minotaur", 0)
	var brute := _enchant("The Brute", minotaur, 0)
	assert_eq(minotaur.cur_power, 3, "2/3 wearing The Brute's +1/+0")
	_attackers_moment()
	# The click lands on the band of the aura standing proud of the host.
	screen._on_card_clicked(brute)
	assert_true(screen._selected_attackers.has(minotaur.id),
		"clicking the aura on your creature declares THE CREATURE")
	screen._on_done()
	assert_true(g.combat.attackers.has(minotaur.id),
		"the engine has the attacker")
	assert_false(g.awaiting_attackers, "the declaration went in")


func test_the_attack_still_deals_its_damage() -> void:
	var g: MtgGame = screen.game
	var minotaur := _summon("Hurloon Minotaur", 0)
	var brute := _enchant("The Brute", minotaur, 0)
	_attackers_moment()
	screen._on_card_clicked(brute)
	screen._on_done()
	# No blockers, then the damage step: CR 510.1c.
	assert_ok_step(g)
	assert_eq(g.players[1].life, 17,
		"3 unblocked damage reached the defender (CR 510.1c)")


func assert_ok_step(g: MtgGame) -> void:
	var guard := 0
	while g.current_step() != Mtg.Step.COMBAT_END and guard < 60:
		if g.awaiting_blockers:
			assert_eq(g.declare_blockers(1, {}), "")
		else:
			assert_eq(g.pass_priority(g.priority_player), "")
		guard += 1
	assert_lt(guard, 60, "combat resolved")


func test_taking_the_attacker_back_through_the_aura() -> void:
	var minotaur := _summon("Hurloon Minotaur", 0)
	var brute := _enchant("The Brute", minotaur, 0)
	_attackers_moment()
	screen._on_card_clicked(minotaur)
	assert_true(screen._selected_attackers.has(minotaur.id))
	screen._on_card_clicked(brute)
	assert_false(screen._selected_attackers.has(minotaur.id),
		"the same band takes it back again (attackers_revocable)")


func test_an_illegal_attacker_is_still_refused_through_its_aura() -> void:
	var minotaur := _summon("Hurloon Minotaur", 0)
	var brute := _enchant("The Brute", minotaur, 0)
	minotaur.tapped = true
	_attackers_moment()
	screen._on_card_clicked(brute)
	assert_false(screen._selected_attackers.has(minotaur.id),
		"a tapped creature is no more attackable through its aura")
	assert_string_contains(screen._prompt_label.text, "Illegal attacker.")


func test_a_click_that_can_declare_nothing_says_so() -> void:
	var mountain := _summon("Mountain", 0)
	_attackers_moment()
	screen._on_card_clicked(mountain)
	assert_string_contains(screen._prompt_label.text, "Illegal attacker.")


# ============================================== AND THE BLOCK SIDE --

func test_blocking_with_an_enchanted_creature_through_its_aura() -> void:
	var g: MtgGame = screen.game
	var djinn := _summon("Hurloon Minotaur", 1)
	g.combat.attackers[djinn.id] = true
	djinn.tapped = true
	var bears := _summon("Grizzly Bears", 0)
	var strength := _enchant("Holy Strength", bears, 0)
	_blockers_moment()
	screen._on_card_clicked(strength)   # pick the blocker up by its aura
	assert_eq(screen._selected_blocker, bears.id,
		"clicking the aura picks up THE CREATURE")
	screen._on_card_clicked(djinn)
	screen._on_done()
	assert_true(g.combat.is_blocking(bears.id, djinn.id),
		"the block reached the engine")


func test_aiming_a_block_at_an_enchanted_attacker_through_its_aura() -> void:
	var g: MtgGame = screen.game
	var minotaur := _summon("Hurloon Minotaur", 1)
	var brute := _enchant("The Brute", minotaur, 1)
	g.combat.attackers[minotaur.id] = true
	minotaur.tapped = true
	var bears := _summon("Grizzly Bears", 0)
	_blockers_moment()
	screen._on_card_clicked(bears)
	screen._on_card_clicked(brute)   # aim at the attacker by its aura band
	screen._on_done()
	assert_true(g.combat.is_blocking(bears.id, minotaur.id),
		"the block was aimed at the creature under the aura")


# ====================================== AND WHAT MUST NOT CHANGE --

func test_outside_combat_the_aura_is_still_its_own_card() -> void:
	# The Brute's {R}{R}{R} regeneration is activated by clicking the aura
	# itself: routing every click to the host would take the card's own
	# ability off the table.
	var minotaur := _summon("Hurloon Minotaur", 0)
	var brute := _enchant("The Brute", minotaur, 0)
	screen.mode = DuelScreen.Mode.NORMAL
	screen.game.active_player = 0
	screen.game._step_index = Mtg.STEP_ORDER.find(Mtg.Step.MAIN1)
	screen._on_card_clicked(brute)
	assert_not_null(screen._ability_menu, "the aura's own ability menu opened")
	assert_eq(int(screen._ability_menu.get_meta("instance_id", -1)), brute.id,
		"the click still operates the aura, not its host")
	assert_false(screen._selected_attackers.has(minotaur.id))


## THE SAME HOLE ON THE ATTACKING SIDE. `CombatState.block_illegality`
## grew a battlefield check on 2026-09-04 because a creature card in the
## defending player's HAND answered "yes, it could block" and the screen
## lifted it into the shield lane. `attack_illegality` had no such check,
## so a creature in the ACTIVE player's hand answered "yes, it could
## attack" and this gesture would put it in the attack lane — where it
## could only ever produce a declaration the engine refused as a whole,
## taking the player's real attackers with it.
func test_a_creature_in_hand_is_not_an_attacker() -> void:
	var g: MtgGame = screen.game
	var in_hand := CardInstance.new(CardRegistry.get_card("Hurloon Minotaur"),
		g._next_instance_id, 0)
	g._next_instance_id += 1
	g._instances[in_hand.id] = in_hand
	in_hand.zone = Mtg.Zone.HAND
	g.players[0].hand.append(in_hand)
	assert_ne(CombatState.attack_illegality(g, in_hand, 1), "",
		"a card in hand is not a creature that can attack (CR 508.1a)")
	_attackers_moment()
	screen._on_card_clicked(in_hand)
	assert_false(screen._selected_attackers.has(in_hand.id),
		"and the attack lane never takes it")


## AND THE THIRD COMBAT GESTURE — the damage division (`docs/duel-todo.md`
## §1.4), where the same picture is clicked for the same reason.
func test_dividing_damage_onto_an_enchanted_blocker_through_its_aura() -> void:
	var g: MtgGame = screen.game
	var ogre := _summon("Hurloon Minotaur", 0)   # 2/3, two points to divide
	var bears := _summon("Grizzly Bears", 1)
	var wall := _summon("Grizzly Bears", 1)
	var strength := _enchant("Holy Strength", bears, 1)
	g.active_player = 0
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS)
	g.awaiting_attackers = true
	assert_eq(g.declare_attackers(0, [ogre.id]), "")
	var to_blocks := 0
	while not g.awaiting_blockers and to_blocks < 40:
		assert_eq(g.pass_priority(g.priority_player), "")
		to_blocks += 1
	assert_eq(g.declare_blockers(1, {bears.id: ogre.id, wall.id: ogre.id}), "")
	var guard := 0
	while not g.awaiting_damage_assignment and guard < 40:
		assert_eq(g.pass_priority(g.priority_player), "")
		guard += 1
	assert_true(g.awaiting_damage_assignment, "the division is ours to make")
	screen._refresh()
	assert_eq(screen.mode, DuelScreen.Mode.DAMAGE)
	screen._on_card_clicked(strength)   # the aura band on the blocker
	assert_eq(int(screen._damage_picks.get(bears.id, 0)), 1,
		"the point went onto the creature under the aura")


# ======================================== ...AND WHEN THERE ARE TWO --
#
# THE SECOND REPORT, the same afternoon: *"I have a Hurr Jackal — it has
# Firebreathing and The Brute enchantments on it. I attack with it, no
# blocker, no other cards in play. My attack does not go through."*
#
# A SECOND aura peeks a second step out, so the band standing proud of the
# creature belongs to the OUTER one and the inner aura shows only a thin
# strip between them. Both are live [MiniCard]s and either can be the one
# the player hits, so both must mean the creature. The whole class is
# swept in `tests/cards/test_auras_2026_09_06.gd` (§1) — every pair and
# every triple in the pool, for the summed body and for the damage it
# deals — and this is the board the report named, through the screen.

func test_the_reported_two_aura_board() -> void:
	var g: MtgGame = screen.game
	var jackal := _summon("Hurr Jackal", 0)
	var breath := _enchant("Firebreathing", jackal, 0)
	var brute := _enchant("The Brute", jackal, 0)
	assert_eq(jackal.cur_power, 2, "1/1 wearing The Brute's +1/+0")
	_attackers_moment()
	# The OUTER band — the one a player's pointer meets first.
	screen._on_card_clicked(brute)
	assert_true(screen._selected_attackers.has(jackal.id),
		"the outer aura's band declares the creature")
	# ...and the INNER one, the strip between the two.
	screen._on_card_clicked(breath)
	assert_false(screen._selected_attackers.has(jackal.id),
		"the inner aura's band is the same creature (take-back)")
	screen._on_card_clicked(breath)
	screen._on_done()
	assert_true(g.combat.attackers.has(jackal.id), "the engine has the attacker")
	assert_ok_step(g)
	assert_eq(g.players[1].life, 18,
		"2 unblocked damage reached the defender (CR 510.1c)")


## A THIRD one on top changes nothing: the outermost band is still the
## creature.
func test_three_auras_deep() -> void:
	var jackal := _summon("Hurr Jackal", 0)
	_enchant("Firebreathing", jackal, 0)
	_enchant("The Brute", jackal, 0)
	var strength := _enchant("Holy Strength", jackal, 0)
	assert_eq(jackal.attachments.size(), 3, "all three are on it")
	assert_eq(jackal.cur_power, 3, "1/1 +1/+0 +1/+2 — cumulative")
	assert_eq(jackal.cur_toughness, 3)
	_attackers_moment()
	screen._on_card_clicked(strength)
	assert_true(screen._selected_attackers.has(jackal.id),
		"the third band is still the creature")


## AND THE REFUSAL STILL SURFACES THROUGH TWO OF THEM. Hurr Jackal has a
## {T} ability of its own, so a Jackal that answered a Drudge Skeletons
## this turn is tapped and cannot attack — and the bar must say so rather
## than swallow the click, which is the whole point of the first fix.
func test_a_tapped_jackal_says_so_through_its_auras() -> void:
	var jackal := _summon("Hurr Jackal", 0)
	_enchant("Firebreathing", jackal, 0)
	var brute := _enchant("The Brute", jackal, 0)
	jackal.tapped = true
	_attackers_moment()
	screen._on_card_clicked(brute)
	assert_false(screen._selected_attackers.has(jackal.id))
	assert_string_contains(screen._prompt_label.text, "Illegal attacker.")
	assert_string_contains(screen._prompt_label.text, "tapped")
