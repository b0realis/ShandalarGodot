extends GameTest
## THE 1997 DAMAGE-PREVENTION WINDOW (docs/duel-todo.md §6.8, slice 2) — a
## RulesOptions fork, so both halves are pinned here: the modern default
## where damage lands the instant it is dealt, and the Fifth Edition step
## where it waits on the table and the players get to answer it.
##
## `Duel.hlp`, topic **Damage Dealing**: *"any damage dealing step during
## which damage is dealt is followed by a damage prevention step, during
## which both players can use effects that prevent and redirect damage.
## also, creatures killed or destroyed during combat can be regenerated."*
## Topic **Combat** supplies the restriction: *"players may use only
## damage prevention fast effects — those that prevent, heal, or redirect
## damage. ... No other kind of fast effects or spells are permitted."*
## Topic **Regeneration** supplies the second window: *"You can use
## regeneration only at the time when a creature is about to go to the
## graveyard."*


## A seat that asks for the window — the human's answer to
## [method DecisionAgent.wants_damage_prevention_window]. Everything else
## about it is the base agent, so nothing else about the duel changes.
class Duelist extends DecisionAgent:
	func wants_damage_prevention_window() -> bool:
		return true


## Turn the fork on and give [param pid] a seat that wants the window.
## BOTH gates, exactly as the engine demands them.
func _arm(pid: int) -> void:
	g.rules.damage_prevention_window = true
	g.set_agent(pid, Duelist.new())


## Both seats leave the open window, which closes it.
func _end_window() -> void:
	assert_ok(g.end_damage_prevention(g.priority_player))
	if g.awaiting_damage_prevention or g.awaiting_regeneration:
		assert_ok(g.end_damage_prevention(g.priority_player))


# ------------------------------------------------------ the window opening --

func test_combat_damage_waits_in_the_window_instead_of_landing() -> void:
	_arm(1)
	var wurm := put_battlefield(0, "Craw Wurm")     # 6/4
	give_hand(1, "Healing Salve")                   # something to do in it
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention, "the step is open")
	assert_eq(g.players[1].life, 20, "the damage has NOT been dealt yet")
	assert_eq(g.damage_pending.size(), 1, "it is waiting as one packet")
	var packet: DamagePacket = g.damage_pending[0]
	assert_eq(packet.amount, 6)
	assert_true(packet.is_combat)
	var request := g.damage_prevention_request()
	assert_eq(request["kind"], "prevention")
	assert_eq(request["prompt"], "Damage prevention")   # @PROMPT_CHECKFEPHASE[0]


func test_ending_the_window_lands_the_damage() -> void:
	_arm(1)
	var wurm := put_battlefield(0, "Craw Wurm")
	give_hand(1, "Healing Salve")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	_end_window()
	assert_false(g.awaiting_damage_prevention)
	assert_eq(g.players[1].life, 14, "six points, at the END of the step")
	assert_eq(g.damage_pending.size(), 0)


func test_no_window_opens_when_the_fork_is_off() -> void:
	# The MODERN default, and the whole rest of the suite's world.
	g.set_agent(1, Duelist.new())     # a seat that WOULD want one
	var wurm := put_battlefield(0, "Craw Wurm")
	give_hand(1, "Healing Salve")
	run_combat([wurm.id])
	assert_false(g.awaiting_damage_prevention)
	assert_eq(g.players[1].life, 14, "damage landed as it was dealt")


func test_no_window_opens_when_no_seat_asked_for_one() -> void:
	# The fork alone is not enough: an AI-only duel must never pause, which
	# is what keeps the Deck Lab and 2300 headless tests untouched.
	g.rules.damage_prevention_window = true
	var wurm := put_battlefield(0, "Craw Wurm")
	give_hand(1, "Healing Salve")
	run_combat([wurm.id])
	assert_false(g.awaiting_damage_prevention)
	assert_eq(g.players[1].life, 14)


func test_a_window_nobody_could_act_in_is_skipped() -> void:
	# Not a shortcut: the window's ONLY legal action is a prevention
	# effect, so a window in which neither seat holds one can only be
	# passed. With no Salve in hand there is nothing to hold it open for.
	_arm(1)
	var wurm := put_battlefield(0, "Craw Wurm")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_false(g.awaiting_damage_prevention, "nothing to do in it")
	assert_eq(g.players[1].life, 14)


func test_a_spell_that_deals_damage_opens_one_too() -> void:
	# `Duel.hlp` is not combat-only: the Circle rulings ("May only be used
	# during damage prevention") assume a window on burn as well.
	_arm(1)
	var bear := put_battlefield(1, "Grizzly Bears")
	give_hand(1, "Healing Salve")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(g.awaiting_damage_prevention)
	assert_eq(bear.damage, 0, "nothing is marked yet")
	_end_window()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "and then it lands, and kills")


# ------------------------------------------------------- the restricted allow --

func test_only_prevention_effects_may_be_used_in_the_window() -> void:
	_arm(1)
	var salve := give_hand(1, "Healing Salve")
	var bolt := give_hand(1, "Lightning Bolt")
	var wurm := put_battlefield(0, "Craw Wurm")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention)
	assert_ok(g.end_damage_prevention(0))      # hand priority to the defender
	add_mana(1, Mtg.ManaColor.R)
	add_mana(1, Mtg.ManaColor.W)
	# "No other kind of fast effects or spells are permitted."
	assert_refused(g.cast_spell(1, bolt, [TargetRef.player(0)]),
		"no other kind of fast effects")
	# Healing Salve's FIRST mode is "target player gains 3 life" — and
	# `Duel.hlp` says of it: "It may only be played in this way OUTSIDE of
	# damage prevention."
	assert_refused(g.cast_spell(1, salve, [TargetRef.player(1)], 0, 0),
		"no other kind of fast effects")
	# Its second mode prevents damage, so it is one of the family.
	assert_ok(g.cast_spell(1, salve, [TargetRef.player(1)], 0, 1))


func test_a_land_cannot_be_played_during_the_window() -> void:
	# A burn spell can open a window in a MAIN phase with an empty stack,
	# which is exactly when a land drop would otherwise be legal.
	_arm(0)
	give_hand(0, "Healing Salve")
	var forest := give_hand(0, "Forest")
	var bear := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_true(g.awaiting_damage_prevention)
	assert_refused(g.play_land(0, forest), "no other kind of fast effects")


# -------------------------------------------------- prevention IN the window --

func test_a_circle_used_in_the_window_stops_damage_already_dealt() -> void:
	# THE POINT OF THE WHOLE ITEM. Without the window a Circle of
	# Protection has to be activated BEFORE the damage; with it, the
	# damage is on the table and the Circle answers it — which is what the
	# 1997 ruling means by "May only be used during damage prevention, as
	# it targets packets of the appropriate damage."
	_arm(1)
	var wurm := put_battlefield(0, "Craw Wurm")          # a GREEN source
	var circle := put_battlefield(1, "Circle of Protection: Green")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention, "the Circle is why it opened")
	assert_ok(g.end_damage_prevention(0))
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(1, circle, 0))
	resolve_stack()
	assert_true(g.awaiting_damage_prevention, "still the same step")
	_end_window()
	assert_eq(g.players[1].life, 20, "the Wurm's damage never landed")


func test_one_circle_answers_a_whole_merged_packet() -> void:
	# The Manabarbs ruling, verbatim: "damage ... during a damage
	# prevention step is added to an existing Manabarbs damage packet (if
	# there is one), so a single use of the CoP would target and prevent
	# all of that damage."
	_arm(0)
	put_battlefield(1, "Manabarbs")
	var circle := put_battlefield(0, "Circle of Protection: Red")
	var a := put_battlefield(0, "Mountain")
	var b := put_battlefield(0, "Mountain")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.tap_for_mana(0, a))
	resolve_stack()                      # the first barb resolves
	assert_true(g.awaiting_damage_prevention)
	assert_eq(g.damage_pending.size(), 1)
	# A mana source is "neither a spell nor an effect" (manual p.95), so
	# tapping the second Mountain inside the window is legal — and its
	# barb joins the packet already sitting there.
	assert_ok(g.tap_for_mana(0, b))
	resolve_stack()
	assert_eq(g.damage_pending.size(), 1, "ONE packet, not two")
	assert_eq(g.damage_pending[0].amount, 2, "of two points")
	assert_ok(g.activate_ability(0, circle, 0))
	resolve_stack()
	_end_window()
	assert_eq(g.players[0].life, 20, "one Circle, both points")


# --------------------------------------------------- the regeneration window --

func test_regeneration_saves_a_creature_that_already_has_lethal_damage() -> void:
	# `Duel.hlp`, topic **Regeneration**: "You can use regeneration only at
	# the time when a creature is about to go to the graveyard." Before
	# this window our regeneration shield had to be bought in ADVANCE.
	_arm(1)
	var wurm := put_battlefield(0, "Craw Wurm")
	var bones := put_battlefield(1, "Drudge Skeletons")   # 1/1
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bones.id: wurm.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	# No prevention effect anywhere, so the FIRST window is skipped and the
	# step goes straight to the one that matters.
	assert_true(g.awaiting_regeneration, "about to go to the graveyard")
	assert_eq(bones.zone, Mtg.Zone.BATTLEFIELD, "not yet, though")
	assert_true(bones.damage >= bones.cur_toughness,
		"the damage HAS landed — lethal damage is what opened this window")
	var request := g.damage_prevention_request()
	assert_eq(request["kind"], "regeneration")
	assert_eq(request["prompt"], "Use Regeneration Effects")  # [11]
	assert_ok(g.end_damage_prevention(0))
	add_mana(1, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(1, bones, 0))
	resolve_stack()
	_end_window()
	assert_eq(bones.zone, Mtg.Zone.BATTLEFIELD, "regenerated in the window")
	assert_eq(bones.damage, 0)
	assert_true(bones.tapped)


func test_declining_the_regeneration_window_lets_it_die() -> void:
	_arm(1)
	var wurm := put_battlefield(0, "Craw Wurm")
	var bones := put_battlefield(1, "Drudge Skeletons")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bones.id: wurm.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_regeneration)
	_end_window()
	assert_eq(bones.zone, Mtg.Zone.GRAVEYARD, "nobody paid")


func test_only_regeneration_effects_may_be_used_in_that_window() -> void:
	_arm(1)
	var wurm := put_battlefield(0, "Craw Wurm")
	var bones := put_battlefield(1, "Drudge Skeletons")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bones.id: wurm.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_regeneration)
	assert_ok(g.end_damage_prevention(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(1, bolt, [TargetRef.player(0)]),
		"only regeneration effects")


# --------------------------------------------------------- what still holds --

func test_drain_life_gains_only_what_actually_landed() -> void:
	# "You gain life equal to the damage dealt this way" is answered when
	# the damage LANDS. With the window in the middle that is later than
	# the spell's own resolution, so the card waits for its packet.
	_arm(1)
	var salve := give_hand(1, "Healing Salve")
	var drain := give_hand(0, "Drain Life")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 5)
	assert_ok(g.cast_spell(0, drain, [TargetRef.player(1)], 3))
	resolve_stack()
	assert_true(g.awaiting_damage_prevention)
	assert_eq(g.players[0].life, 20, "no life gained yet — none was dealt yet")
	assert_ok(g.end_damage_prevention(0))
	add_mana(1, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(1, salve, [TargetRef.player(1)], 0, 1))
	resolve_stack()
	_end_window()
	assert_eq(g.players[1].life, 20, "all three prevented")
	assert_eq(g.players[0].life, 20, "so nothing to drain")


func test_death_ward_can_only_be_cast_on_something_that_is_dying() -> void:
	# `@DEATH_WARD` (Program/prompts.txt:238-239) is `Select creature.` and
	# `Illegal target (not dying).` — a refusal the engine could not even
	# express before the regeneration window, because "dying" is a state
	# only that window can see.
	_arm(1)
	var wurm := put_battlefield(0, "Craw Wurm")
	var bones := put_battlefield(1, "Drudge Skeletons")
	var spare := put_battlefield(1, "Grizzly Bears")
	var ward := give_hand(1, "Death Ward")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bones.id: wurm.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_regeneration)
	assert_ok(g.end_damage_prevention(0))
	add_mana(1, Mtg.ManaColor.W)
	assert_refused(g.cast_spell(1, ward, [TargetRef.card(spare)]),
		"Illegal target (not dying).")
	assert_ok(g.cast_spell(1, ward, [TargetRef.card(bones)]))
	resolve_stack()
	_end_window()
	assert_eq(bones.zone, Mtg.Zone.BATTLEFIELD, "warded at the last moment")


func test_death_ward_still_wards_anything_with_no_window_open() -> void:
	# The modern default: no window, no "dying", and Death Ward is the
	# ordinary pre-emptive shield it has always been.
	var bear := put_battlefield(0, "Grizzly Bears")
	var ward := give_hand(0, "Death Ward")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, ward, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.regeneration_shields, 1)


func test_a_packet_never_survives_the_turn_that_made_it() -> void:
	# THE INVARIANT, whichever path lands it: a packet is answered inside
	# the turn that made it. Cleanup grants no priority — so no window can
	# open over damage dealt there — and cleanup also wipes marked damage,
	# which would erase the victim's damage before the packet ever landed.
	# _flush_stranded_damage is the backstop; _open_priority is the road.
	_arm(0)
	var bear := put_battlefield(1, "Grizzly Bears")   # 2/2
	var rod := put_battlefield(0, "Rod of Ruin")
	plant_damage_packet(rod, TargetRef.card(bear), 2)
	assert_eq(g.damage_pending.size(), 1)
	advance_to_next_turn()
	assert_eq(g.damage_pending.size(), 0, "it landed, it did not vanish")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "two points killed the Bears")
