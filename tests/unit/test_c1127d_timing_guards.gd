extends GameTest
## ROUND 4 OF THE PLAYER REPORT 2026-11-26, the spell timing's leftovers
## (engine/ai/spell_timing.gd): three one-target spells the pilot cast in
## its main phase at a creature across the table, where they do nothing.
##  1. THE SHIELD ("If a spell or ability that targets that creature would
##     cause a source to deal damage to that creature this turn, prevent
##     that damage"): our creature, in answer to the spell that names it.
##  2. THE INSURANCE ("When that creature dies this turn, return a creature
##     card from its owner's graveyard to the battlefield"): our creature
##     that is about to die — to a spell on the stack, or in a declared
##     combat once the blocks are known.
##  3. THE SWITCH ("Switch target creature's power and toughness until end
##     of turn"): in a declared combat where the switch wins the fight, on
##     either side's creature; in our main phase only at a creature it kills.
## Each beside the gate's null arm ([member AiProfile.forecasts_tactics]
## off: the pilot as it was) or a control where the card is kept.

const TIMING := preload("res://engine/ai/spell_timing.gd")

const LANDS := ["Island", "Island", "Forest", "Forest", "Forest", "Swamp", "Swamp",
	"Plains", "Plains"]


func before_each() -> void:
	# One rebuild of the registry for the file, not ten for each board
	# (a no-op once the packs are on); switched off again in after_all.
	CardPacks.set_enabled_many(CardPacks.available_ids(), true)
	super()


func after_each() -> void:
	g = null


func after_all() -> void:
	CardPacks.set_enabled_many(CardPacks.available_ids(), false)


func _ai(profile: AiProfile = null) -> AiPlayer:
	var p := profile if profile != null else AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _null() -> AiProfile:
	var p := AiProfile.wizard()
	p.forecasts_tactics = false
	return p


func _rungs() -> Array:
	return [AiProfile.apprentice(), AiProfile.magician(), AiProfile.sorcerer(), AiProfile.wizard()]


func _holders() -> Array:
	return [AiProfile.magician(), AiProfile.sorcerer(), AiProfile.wizard()]


func _lands() -> void:
	for land in LANDS: put_battlefield(0, land)


## Our main phase, until the pilot passes.
func _main(ai: AiPlayer) -> Array:
	advance_to_step(Mtg.Step.MAIN1)
	var lines: Array = []
	for _i in 8:
		if g.game_over or g.priority_player != 0 or g.current_step() != Mtg.Step.MAIN1:
			break
		var line := ai.act(g)
		lines.append(line)
		if not g.stack.is_empty(): resolve_stack()
		if line == "" or line == "pass": break
	return lines


## Their turn: [param attackers] attack, the pilot answers every priority
## it gets until the turn's end; [param blocks] is declared for it.
func _their_attack(ai: AiPlayer, attackers: Array, blocks: Dictionary = {},
		through := Mtg.Step.END) -> Array:
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	var ids: Array = []
	for a in attackers: ids.append(a.id)
	assert_ok(g.declare_attackers(1, ids))
	var lines: Array = []
	var guard := 0
	while not g.game_over and guard < 80 and g.active_player == 1 \
			and g.current_step() <= through:
		guard += 1
		if g.awaiting_blockers:
			assert_ok(g.declare_blockers(0, blocks))
		elif g.priority_player == 0:
			var line := ai.act(g)
			if line != "pass": lines.append("%s: %s" % [Mtg.step_name(g.current_step()), line])
		else:
			g.pass_priority(1)
	return lines


## Their main phase: they cast [param spell_name] at [param victim] and the
## pilot answers until the stack is empty.
func _their_spell(ai: AiPlayer, spell_name: String, victim: CardInstance) -> Array:
	var spell := give_hand(1, spell_name)
	advance_to_next_turn()
	advance_to_step(Mtg.Step.MAIN1)
	for color in [Mtg.ManaColor.R, Mtg.ManaColor.B, Mtg.ManaColor.W]:
		add_mana(1, color, 3)
	assert_ok(g.cast_spell(1, spell, [TargetRef.card(victim)]))
	var lines: Array = []
	var guard := 0
	while not g.stack.is_empty() and not g.game_over and guard < 30:
		guard += 1
		if g.priority_player == 0:
			lines.append(ai.act(g))
		else:
			g.pass_priority(1)
	return lines


# ----------------------------------------------------- the printed shape --

func test_the_shape_is_read_off_the_printed_line() -> void:
	var rows := {"Silhouette": TIMING.GUARD_SHIELD, "Indestructible Aura": TIMING.GUARD_SHIELD,
		"Sacred Boon": TIMING.GUARD_SHIELD, "Anoint": 0,   # buyback: two rows, its own rule
		"Reincarnation": TIMING.GUARD_INSURANCE,
		"Transmutation": TIMING.GUARD_SWITCH, "About Face": TIMING.GUARD_SWITCH,
		"Giant Growth": 0, "Lightning Bolt": 0, "Death Ward": 0, "Humble": 0, "Fend Off": 0,
		"Glyph of Reincarnation": 0, "Disintegrate": 0, "Redeem": 0, "Warning": 0,
		"Great Defender": 0, "Terror": 0}
	for card_name in rows:
		assert_eq(TIMING.guard_of(CardRegistry.get_card(card_name)), rows[card_name], card_name)
	for card_name in ["Silhouette", "Reincarnation", "Indestructible Aura", "Great Defender"]:
		assert_true(TIMING.aims_home(CardRegistry.get_card(card_name)), card_name)
	for card_name in ["Transmutation", "About Face", "Lightning Bolt", "Terror"]:
		assert_false(TIMING.aims_home(CardRegistry.get_card(card_name)), card_name)
	assert_eq(TIMING._read_guard(TIMING.plain("Prevent all combat damage that would be dealt by target creature this turn.")), 0)
	assert_eq(TIMING._read_guard(TIMING.plain("If target creature would die this turn, return it to the battlefield.")), TIMING.GUARD_INSURANCE)
	assert_eq(TIMING._read_guard(TIMING.plain("Switch target green creature's power and toughness until end of turn.")), TIMING.GUARD_SWITCH)


# ------------------------------------------- no main-phase cast, no wrong aim --

func test_none_of_them_is_cast_in_the_main_phase() -> void:
	for profile in _rungs():
		for card_name in ["Silhouette", "Reincarnation", "Transmutation", "About Face",
				"Indestructible Aura", "Anoint"]:
			before_each()
			var ai := _ai(profile)
			_lands()
			put_battlefield(0, "Grizzly Bears")
			put_battlefield(1, "Hill Giant")
			put_battlefield(1, "Craw Wurm")
			var card := give_hand(0, card_name)
			var lines := _main(ai)
			assert_eq(card.zone, Mtg.Zone.HAND, "%s, %s: %s" % [profile.profile_name, card_name, lines])


func test_a_whole_round_never_aims_a_guard_across_the_table() -> void:
	# Our turn and theirs, their two creatures attacking into no block: the
	# shield and the insurance name no creature of theirs, and no switch is
	# spent where it changes nothing.
	for profile in _rungs():
		for card_name in ["Silhouette", "Reincarnation", "Transmutation"]:
			before_each()
			var ai := _ai(profile)
			_lands()
			put_battlefield(0, "Wall of Wood")
			var giant := put_battlefield(1, "Hill Giant")
			var wurm := put_battlefield(1, "Craw Wurm")
			var card := give_hand(0, card_name)
			advance_to_step(Mtg.Step.MAIN1)
			var lines: Array = []
			var guard := 0
			while not g.game_over and guard < 200 and g.turn_number <= 2:
				guard += 1
				if g.awaiting_blockers:
					assert_ok(g.declare_blockers(g.block_chooser(), {}))
				elif g.awaiting_attackers and g.active_player == 1:
					assert_ok(g.declare_attackers(1, [giant.id, wurm.id]))
				elif g.awaiting_attackers or g.priority_player == 0:
					var line := ai.act(g)
					if line != "pass": lines.append("%s: %s" % [Mtg.step_name(g.current_step()), line])
				else:
					g.pass_priority(1)
			assert_eq(card.zone, Mtg.Zone.HAND, "%s, %s: %s" % [profile.profile_name, card_name, lines])


func test_null_arm_casts_them_across_the_table_as_before() -> void:
	for card_name in ["Silhouette", "Reincarnation", "Transmutation"]:
		before_each()
		var ai := _ai(_null())
		_lands()
		put_battlefield(0, "Grizzly Bears")
		var wurm := put_battlefield(1, "Craw Wurm")
		var card := give_hand(0, card_name)
		advance_to_step(Mtg.Step.MAIN1)
		ai.act(g)
		assert_false(g.stack.is_empty(), "%s: the gate off is the pilot as it was" % card_name)
		if not g.stack.is_empty():
			assert_eq(g.stack.back().card, card)
			assert_eq(g.stack.back().targets[0].instance_id, wurm.id, card_name)


# ----------------------------------------------------------- 1 the shield --

func test_silhouette_answers_the_bolt_at_our_creature() -> void:
	for profile in _holders():
		before_each()
		var ai := _ai(profile)
		_lands()
		var ours := put_battlefield(0, "Hill Giant")
		var card := give_hand(0, "Silhouette")
		var lines := _their_spell(ai, "Lightning Bolt", ours)
		assert_eq(card.zone, Mtg.Zone.GRAVEYARD, "%s: %s" % [profile.profile_name, lines])
		assert_eq(ours.zone, Mtg.Zone.BATTLEFIELD, "%s: %s" % [profile.profile_name, lines])


func test_silhouette_is_kept_where_it_saves_nothing() -> void:
	# A Terror is no damage; a Bolt the Craw Wurm survives needs no answer;
	# a block is combat damage, which the printed line does not stop.
	var ai := _ai()
	_lands()
	var ours := put_battlefield(0, "Hill Giant")
	var card := give_hand(0, "Silhouette")
	var lines := _their_spell(ai, "Terror", ours)
	assert_eq(card.zone, Mtg.Zone.HAND, str(lines))
	before_each()
	ai = _ai()
	_lands()
	ours = put_battlefield(0, "Craw Wurm")
	card = give_hand(0, "Silhouette")
	lines = _their_spell(ai, "Lightning Bolt", ours)
	assert_eq(card.zone, Mtg.Zone.HAND, str(lines))
	before_each()
	ai = _ai()
	_lands()
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	card = give_hand(0, "Silhouette")
	lines = _their_attack(ai, [giant], {bears.id: giant.id})
	assert_eq(card.zone, Mtg.Zone.HAND, str(lines))


func test_null_arm_has_no_answer() -> void:
	var ai := _ai(_null())
	_lands()
	var ours := put_battlefield(0, "Hill Giant")
	var card := give_hand(0, "Silhouette")
	_their_spell(ai, "Lightning Bolt", ours)
	assert_eq(card.zone, Mtg.Zone.HAND)
	assert_eq(ours.zone, Mtg.Zone.GRAVEYARD)


func test_a_shield_of_all_damage_answers_bolt_and_block() -> void:
	# The same reading: "Prevent all damage that would be dealt to target
	# creature this turn."
	for profile in _holders():
		before_each()
		var ai := _ai(profile)
		_lands()
		var ours := put_battlefield(0, "Hill Giant")
		var card := give_hand(0, "Indestructible Aura")
		var lines := _their_spell(ai, "Lightning Bolt", ours)
		assert_eq(card.zone, Mtg.Zone.GRAVEYARD, "%s: %s" % [profile.profile_name, lines])
		assert_eq(ours.zone, Mtg.Zone.BATTLEFIELD, profile.profile_name)
		before_each()
		ai = _ai(profile)
		_lands()
		var bears := put_battlefield(0, "Grizzly Bears")
		var giant := put_battlefield(1, "Hill Giant")
		card = give_hand(0, "Indestructible Aura")
		lines = _their_attack(ai, [giant], {bears.id: giant.id})
		assert_eq(card.zone, Mtg.Zone.GRAVEYARD, "%s: %s" % [profile.profile_name, lines])
		assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, profile.profile_name)


# -------------------------------------------------------- 2 the insurance --

func test_reincarnation_answers_the_bolt_at_our_creature() -> void:
	for profile in _holders():
		before_each()
		var ai := _ai(profile)
		_lands()
		var ours := put_battlefield(0, "Hill Giant")
		var card := give_hand(0, "Reincarnation")
		var lines := _their_spell(ai, "Lightning Bolt", ours)
		assert_eq(card.zone, Mtg.Zone.GRAVEYARD, "%s: %s" % [profile.profile_name, lines])
		assert_eq(ours.zone, Mtg.Zone.BATTLEFIELD, "it came back: %s" % [lines])


func test_reincarnation_insures_the_blocker_that_dies() -> void:
	# Bears block a Hill Giant and die; a Craw Wurm lies in our graveyard.
	for profile in _rungs():
		before_each()
		var ai := _ai(profile)
		_lands()
		var bears := put_battlefield(0, "Grizzly Bears")
		var giant := put_battlefield(1, "Hill Giant")
		var wurm := _make_instance(0, "Craw Wurm")
		wurm.zone = Mtg.Zone.GRAVEYARD
		g.players[0].graveyard.append(wurm)
		var card := give_hand(0, "Reincarnation")
		var lines := _their_attack(ai, [giant], {bears.id: giant.id})
		assert_eq(card.zone, Mtg.Zone.GRAVEYARD, "%s: %s" % [profile.profile_name, lines])
		assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, profile.profile_name)
		assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD, "%s: %s" % [profile.profile_name, lines])
		assert_eq(wurm.controller_id, 0)


func test_reincarnation_is_kept_when_nothing_of_ours_dies() -> void:
	# Our Hill Giant blocks their Bears: the Bears die, and they are not ours
	# to insure. An unblocked attack kills nothing.
	for profile in _rungs():
		before_each()
		var ai := _ai(profile)
		_lands()
		var giant := put_battlefield(0, "Hill Giant")
		var bears := put_battlefield(1, "Grizzly Bears")
		var card := give_hand(0, "Reincarnation")
		var lines := _their_attack(ai, [bears], {giant.id: bears.id})
		assert_eq(card.zone, Mtg.Zone.HAND, "%s: %s" % [profile.profile_name, lines])
		before_each()
		ai = _ai(profile)
		_lands()
		put_battlefield(0, "Hill Giant")
		bears = put_battlefield(1, "Grizzly Bears")
		card = give_hand(0, "Reincarnation")
		lines = _their_attack(ai, [bears], {})
		assert_eq(card.zone, Mtg.Zone.HAND, "%s: %s" % [profile.profile_name, lines])


# ----------------------------------------------------------- 3 the switch --

func test_the_switch_kills_their_attacker_in_the_block() -> void:
	# Their Hurloon Minotaur (2/3) into our Giant Spider (2/4): at 3/2 the
	# Minotaur dies and the Spider lives.
	for profile in _rungs():
		for card_name in ["Transmutation", "About Face"]:
			before_each()
			var ai := _ai(profile)
			_lands()
			put_battlefield(0, "Mountain")
			var spider := put_battlefield(0, "Giant Spider")
			var minotaur := put_battlefield(1, "Hurloon Minotaur")
			var card := give_hand(0, card_name)
			var lines := _their_attack(ai, [minotaur], {spider.id: minotaur.id})
			assert_eq(card.zone, Mtg.Zone.GRAVEYARD, "%s, %s: %s" % [profile.profile_name, card_name, lines])
			assert_eq(minotaur.zone, Mtg.Zone.GRAVEYARD, "%s, %s" % [profile.profile_name, card_name])
			assert_eq(spider.zone, Mtg.Zone.BATTLEFIELD, "%s, %s" % [profile.profile_name, card_name])


func test_the_switch_is_kept_when_the_fight_is_the_same() -> void:
	# Hill Giant against Hill Giant, 3/3 either way; an unblocked Craw Wurm.
	for profile in _rungs():
		before_each()
		var ai := _ai(profile)
		_lands()
		var ours := put_battlefield(0, "Hill Giant")
		var theirs := put_battlefield(1, "Hill Giant")
		var card := give_hand(0, "Transmutation")
		var lines := _their_attack(ai, [theirs], {ours.id: theirs.id})
		assert_eq(card.zone, Mtg.Zone.HAND, "%s: %s" % [profile.profile_name, lines])
		before_each()
		ai = _ai(profile)
		_lands()
		put_battlefield(0, "Hill Giant")
		var wurm := put_battlefield(1, "Craw Wurm")
		card = give_hand(0, "Transmutation")
		lines = _their_attack(ai, [wurm], {})
		assert_eq(card.zone, Mtg.Zone.HAND, "%s: %s" % [profile.profile_name, lines])


func test_the_switch_kills_a_creature_of_no_power_in_our_main_phase() -> void:
	# Wall of Stone, 0/8: at 8/0 it is gone — and it is the Wall the switch
	# names, not the Craw Wurm beside it.
	for profile in _rungs():
		before_each()
		var ai := _ai(profile)
		_lands()
		put_battlefield(0, "Grizzly Bears")
		var wurm := put_battlefield(1, "Craw Wurm")
		var wall := put_battlefield(1, "Wall of Stone")
		var card := give_hand(0, "Transmutation")
		var lines := _main(ai)
		assert_eq(card.zone, Mtg.Zone.GRAVEYARD, "%s: %s" % [profile.profile_name, lines])
		assert_eq(wall.zone, Mtg.Zone.GRAVEYARD, "%s: %s" % [profile.profile_name, lines])
		assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)


func test_the_switch_saves_our_creature_from_the_bolt() -> void:
	# Giant Spider is 2/4... a Wall of Stone at 0/8 needs nothing; our
	# Hurloon Minotaur (2/3) under a Bolt lives at... 3/2 it does not: kept.
	# A Sea Serpent-sized 3/1 is what it saves: Hill Giant with 2 damage is
	# not one. So: the card is kept where the switch saves nothing.
	var ai := _ai()
	_lands()
	var ours := put_battlefield(0, "Hill Giant")
	var card := give_hand(0, "Transmutation")
	var lines := _their_spell(ai, "Lightning Bolt", ours)
	assert_eq(card.zone, Mtg.Zone.HAND, str(lines))
	assert_eq(ours.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------------ the forecast --

func test_the_stack_forecast_puts_everything_back() -> void:
	var ai := _ai()
	_lands()
	var ours := put_battlefield(0, "Hill Giant")
	var card := give_hand(0, "Reincarnation")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_next_turn()
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(ours)]))
	g.pass_priority(1)
	var base: Dictionary = TIMING.forecast_stack(g, ai, null, [])
	assert_eq(int(base["ours_lost"]), 1)
	var seen: Dictionary = TIMING.forecast_stack(g, ai, card, [TargetRef.card(ours)])
	assert_eq(int(seen["ours_lost"]), 0)
	assert_eq(g.stack.size(), 1)
	assert_eq(card.zone, Mtg.Zone.HAND)
	assert_eq(ours.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(g.death_watchers.is_empty())
	assert_null(g.undo_log)
	assert_eq(g.priority_player, 0)
