extends GameTest
## Pack 9 (the Tempest block), the fair AI's RESPONSE SPELLS (stage 4,
## casting; engine/ai/tempest_spells.gd `respond`, [member AiProfile.forecasts_tactics]).
##
## Kor Chant's redirect, Resuscitate's team regeneration, Fighting Chance's
## coin fog, Blood Frenzy's doomed pump, Temper's growing shield, Rebound's
## player retarget and Change of Heart's "can't attack" each have ONE
## moment — a declared combat, a spell on the stack, their beginning of
## combat. The reader saw a card-local effect and cast them into our own
## empty main phase ("Kor Chant random casts", the B12 batch's smoke), at
## our own creature or theirs. They are now never the main planner's, and
## each is cast at its moment when the public board says it saves or kills
## something worth the card. The opponent's hidden hand is never read.


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-9", true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _lands(pid: int, land: String, n: int) -> void:
	for _i in n:
		put_battlefield(pid, land)


## Their attack with [param attacker], our [param blocker] (or none) on it;
## seat 0 then holds priority in the declare-blockers step.
func _their_attack(attacker: CardInstance, blocker: CardInstance) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.awaiting_attackers) and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.declare_attackers(1, [attacker.id]))
	guard = 0
	while not g.awaiting_blockers and guard < 50:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_ok(g.declare_blockers(0, {} if blocker == null else {blocker.id: attacker.id}))
	guard = 0
	while g.priority_player != 0 and guard < 10:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_eq(g.current_step(), Mtg.Step.DECLARE_BLOCKERS)


## Our attack with [param attacker], their [param blocker] on it; seat 0
## then holds priority in the declare-blockers step.
func _our_attack(attacker: CardInstance, blocker: CardInstance) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	var guard := 0
	while not g.awaiting_blockers and guard < 50:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_ok(g.declare_blockers(1, {blocker.id: attacker.id}))
	assert_eq(g.priority_player, 0)


func _finish_combat() -> void:
	var guard := 0
	while g.current_step() != Mtg.Step.COMBAT_END and not g.game_over and guard < 100:
		_advance_once()
		guard += 1


# ------------------------------------------------------- never the main phase's --

func test_no_response_spell_is_cast_into_our_main_phase() -> void:
	var ai := _ai()
	_lands(0, "Plains", 4)
	_lands(0, "Mountain", 4)
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	var hand: Array = []
	for card_name in ["Kor Chant", "Temper", "Change of Heart", "Fighting Chance",
			"Blood Frenzy", "Imps' Taunt", "Whim of Volrath", "Fling"]:
		hand.append(give_hand(0, card_name))
	advance_to_step(Mtg.Step.MAIN1)
	for _i in 4:
		ai.act(g)
		resolve_stack()
	for card in hand:
		assert_eq(card.zone, Mtg.Zone.HAND, card.data.card_name + " waits for its moment")


# ------------------------------------------------------------------- Kor Chant --

func test_kor_chant_turns_their_wurm_on_itself() -> void:
	var ai := _ai()
	_lands(0, "Plains", 3)
	var bears := put_battlefield(0, "Grizzly Bears")
	var wurm := put_battlefield(1, "Craw Wurm")
	give_hand(0, "Kor Chant")
	_their_attack(wurm, bears)
	assert_string_contains(ai.act(g), "Kor Chant")
	resolve_stack()
	_finish_combat()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "the Wurm's 6 went elsewhere")
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD, "into its own 4 toughness")


func test_the_null_arm_lets_the_bears_die() -> void:
	var ai := _ai(false)
	_lands(0, "Plains", 3)
	var bears := put_battlefield(0, "Grizzly Bears")
	var wurm := put_battlefield(1, "Craw Wurm")
	var chant := give_hand(0, "Kor Chant")
	_their_attack(wurm, bears)
	ai.act(g)
	assert_eq(chant.zone, Mtg.Zone.HAND)


# ----------------------------------------------------------------- Resuscitate --

func test_resuscitate_saves_the_blocker() -> void:
	var ai := _ai()
	_lands(0, "Forest", 3)
	var giant := put_battlefield(0, "Hill Giant")
	var wurm := put_battlefield(1, "Craw Wurm")
	give_hand(0, "Resuscitate")
	_their_attack(wurm, giant)
	assert_string_contains(ai.act(g), "Resuscitate")


# ------------------------------------------------------------- Fighting Chance --

func test_fighting_chance_on_a_lost_attack() -> void:
	var ai := _ai()
	put_battlefield(0, "Mountain")
	var ours := put_battlefield(0, "Craw Wurm")
	var theirs := put_battlefield(1, "Craw Wurm")
	give_hand(0, "Fighting Chance")
	_our_attack(ours, theirs)
	assert_string_contains(ai.act(g), "Fighting Chance")


# ---------------------------------------------------------------- Blood Frenzy --

func test_blood_frenzy_dooms_their_unblocked_wurm() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 2)
	var wurm := put_battlefield(1, "Craw Wurm")
	give_hand(0, "Blood Frenzy")
	_their_attack(wurm, null)
	assert_string_contains(ai.act(g), "Blood Frenzy")
	resolve_stack()
	advance_to_next_turn()
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 10, "ten points for their Wurm")


func test_blood_frenzy_never_where_the_four_points_kill_us() -> void:
	var ai := _ai()
	_lands(0, "Mountain", 2)
	var wurm := put_battlefield(1, "Craw Wurm")
	g.players[0].life = 9
	var frenzy := give_hand(0, "Blood Frenzy")
	_their_attack(wurm, null)
	ai.act(g)
	assert_eq(frenzy.zone, Mtg.Zone.HAND, "6 + 4 is our 9 life")


# ---------------------------------------------------------------------- Temper --

func test_temper_answers_their_bolt_and_grows() -> void:
	var ai := _ai()
	_lands(0, "Plains", 5)
	var bears := put_battlefield(0, "Grizzly Bears")
	give_hand(0, "Temper")
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.MAIN1) and guard < 400:
		_advance_once()
		guard += 1
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bears)]))
	assert_ok(g.pass_priority(1))
	assert_string_contains(ai.act(g), "Temper")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(int(bears.counters.get("+1/+1", 0)), 3)


# --------------------------------------------------------------------- Rebound --

func test_rebound_sends_their_fireball_back() -> void:
	var ai := _ai()
	_lands(0, "Island", 2)
	give_hand(0, "Rebound")
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.MAIN1) and guard < 400:
		_advance_once()
		guard += 1
	var fireball := give_hand(1, "Fireball")
	add_mana(1, Mtg.ManaColor.R, 6)
	assert_ok(g.cast_spell(1, fireball, [TargetRef.player(0)], 5))
	assert_ok(g.pass_priority(1))
	assert_string_contains(ai.act(g), "Rebound")
	resolve_stack()
	assert_eq(g.players[0].life, 20)
	assert_eq(g.players[1].life, 15)


# ------------------------------------------------------------- Change of Heart --

func test_change_of_heart_keeps_their_wurm_home() -> void:
	var ai := _ai()
	put_battlefield(0, "Plains")
	var wurm := put_battlefield(1, "Craw Wurm")
	give_hand(0, "Change of Heart")
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.COMBAT_BEGIN) \
			and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	assert_string_contains(ai.act(g), "Change of Heart")
	resolve_stack()
	assert_true(wurm.cant_attack_this_turn)


# ------------------------------------------------------------------ Imps' Taunt --

func test_imps_taunt_drags_their_bears_into_our_giant() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 2)
	put_battlefield(0, "Hill Giant")
	var bears := put_battlefield(1, "Grizzly Bears")
	give_hand(0, "Imps' Taunt")
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.COMBAT_BEGIN) \
			and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	assert_string_contains(ai.act(g), "Imps' Taunt")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)


func test_imps_taunt_never_drags_a_creature_we_cannot_stop() -> void:
	var ai := _ai()
	_lands(0, "Swamp", 2)
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Craw Wurm")
	var taunt := give_hand(0, "Imps' Taunt")
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.COMBAT_BEGIN) \
			and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.pass_priority(1))
	ai.act(g)
	assert_eq(taunt.zone, Mtg.Zone.HAND)
