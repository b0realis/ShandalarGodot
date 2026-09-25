extends GameTest
## THE CONSCRIPTION AURA (2026-09-25). Aggression (Ice Age) grants first
## strike and trample and destroys its host at its controller's end step
## if it did not attack. The every-pack sweep had it friendly — a grant
## that picks an attacker — and the owner ruled otherwise: *"aggression
## can be played on enemy creature to destroy it if the creature is a
## threat. Cast on own creatures only if trample and first strike would
## gain critical advantage (especially trample for creatures with large
## power, 4 and above lets say…)"*.
##
## So: aimed across the table ([constant EffectIntent.AURA_HOSTILE]), and
## only at a body the clause actually kills — one that cannot attack, or
## one some untapped creature of ours can block, survive and kill
## ([method AiPlayer._conscription_kills]); with nothing of theirs worth
## it, our own attacker of four power or more that lacks trample, in our
## first main phase, when the declaration itself says it would swing
## ([method AiPlayer._conscription_host]). And a creature of ours that
## wears one attacks whatever the analysis says, because staying home is
## a destroy at our own end step ([method AiPlayer._conscripted]).
##
## Every test acts through AiPlayer.act / the public MtgGame API. Ice Age
## (Pack 3) is on for the script and off again after it.


func before_each() -> void:
	CardPacks.set_enabled(IceAgePack.ID, true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled(IceAgePack.ID, false)


func _wizard(seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, AiProfile.wizard())
	g.set_agent(seat, ai)
	return ai


func _lands(seat: int, land_name: String, count: int) -> void:
	for _i in count:
		put_battlefield(seat, land_name)


## The aura attached to [param host], or null.
func _aura_on(host: CardInstance, aura_name: String) -> CardInstance:
	for inst in g.all_battlefield():
		if inst.data.card_name == aura_name and inst.attached_to == host.id:
			return inst
	return null


func _in_hand(seat: int, card_name: String) -> bool:
	for card in g.players[seat].hand:
		if card.data.card_name == card_name:
			return true
	return false


## Seat 0 holds Aggression with the mana for it, in its first main phase.
func _armed(ai_seat := 0) -> AiPlayer:
	var ai := _wizard(ai_seat)
	_lands(ai_seat, "Mountain", 3)
	give_hand(ai_seat, "Aggression")
	advance_to_step(Mtg.Step.MAIN1)
	return ai


# ============================================================ the reader --

func test_the_reader_sees_both_gifts_and_the_clause() -> void:
	var data := CardRegistry.get_card("Aggression")
	assert_eq(EffectIntent.aura_aim(data), EffectIntent.Aim.HOSTILE, "across the table")
	assert_true(EffectIntent.aura_is_classified(data))
	assert_true(EffectIntent.aura_conscripts(data), "attack or be destroyed")
	var gifts: Array = EffectIntent.aura_gifts(data)
	var keywords: Array = []
	for gift in gifts:
		keywords.append(int(gift["keyword"]))
	assert_eq(keywords, [Mtg.Keyword.FIRST_STRIKE, Mtg.Keyword.TRAMPLE],
		"'has first strike and trample' is two grants, not one")
	assert_false(bool(gifts[0]["attack_only"]), "first strike serves a blocker too")
	assert_true(bool(gifts[1]["attack_only"]), "trample is an attacker's gift")
	# The same conjunction elsewhere in the pool, and the clause nowhere else.
	var wings: Array = []
	for gift in EffectIntent.aura_gifts(CardRegistry.get_card("Wings of Aesthir")):
		wings.append(int(gift["keyword"]))
	assert_eq(wings, [Mtg.Keyword.FLYING, Mtg.Keyword.FIRST_STRIKE],
		"'has flying and first strike' reads both")
	assert_false(EffectIntent.aura_conscripts(CardRegistry.get_card("Eternal Warrior")))
	assert_false(EffectIntent.aura_conscripts(CardRegistry.get_card("Weakness")))
	assert_false(EffectIntent.aura_conscripts(CardRegistry.get_card("Hill Giant")), "not an aura")


# ============================================= removal, across the table --

func test_it_goes_on_a_threat_our_blocker_can_kill_and_survive() -> void:
	# Their Grizzly Bears against our untapped Giant Spider (2/4): it
	# attacks into a block that kills it, or it is destroyed at their end
	# step. Either way it is gone.
	var ai := _armed()
	put_battlefield(0, "Giant Spider")
	var bears := put_battlefield(1, "Grizzly Bears")
	var did := ai.act(g)
	assert_string_contains(did, "Aggression")
	resolve_stack()
	assert_not_null(_aura_on(bears, "Aggression"), "on their creature")


func test_it_is_not_hung_on_a_creature_that_walks_through_us() -> void:
	# Their Hill Giant against our Grizzly Bears: nothing of ours blocks
	# it and lives, so it attacks every turn, now with first strike and
	# trample. The aura waits in hand.
	var ai := _armed()
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	var did := ai.act(g)
	assert_false(did.contains("Aggression"), "not cast to arm them: %s" % did)
	assert_true(_in_hand(0, "Aggression"), "kept")


func test_a_blocker_that_would_only_trade_does_not_count() -> void:
	# Their Hill Giant against our Hill Giant: a trade today, and with
	# first strike on theirs no trade at all — ours dies for nothing.
	var ai := _armed()
	put_battlefield(0, "Hill Giant")
	put_battlefield(1, "Hill Giant")
	var did := ai.act(g)
	assert_false(did.contains("Aggression"), "not cast into a first striker: %s" % did)
	assert_true(_in_hand(0, "Aggression"), "kept")


func test_a_tapped_blocker_is_no_blocker_on_their_turn() -> void:
	# The Spider that tapped this turn untaps after their turn, not before it.
	var ai := _armed()
	var spider := put_battlefield(0, "Giant Spider")
	spider.tapped = true
	put_battlefield(1, "Grizzly Bears")
	var did := ai.act(g)
	assert_false(did.contains("Aggression"), "no blocker, no kill: %s" % did)
	assert_true(_in_hand(0, "Aggression"), "kept")


func test_a_creature_that_cannot_attack_is_destroyed_outright() -> void:
	# Their Grizzly Bears under our Moat cannot attack: the clause
	# destroys it at their end step whatever we have to block with.
	var ai := _armed()
	put_battlefield(0, "Moat")
	var bears := put_battlefield(1, "Grizzly Bears")
	g.recalculate()
	assert_true(bears.cur_cant_attack, "grounded by the Moat")
	var did := ai.act(g)
	assert_string_contains(did, "Aggression")
	resolve_stack()
	assert_not_null(_aura_on(bears, "Aggression"))


func test_their_board_comes_before_our_own_big_attacker() -> void:
	# Both readings are on the table: our Craw Wurm (6/4, no trample)
	# would wear it, and their Bears would die to it. Removal first.
	var ai := _armed()
	var wurm := put_battlefield(0, "Craw Wurm")
	var bears := put_battlefield(1, "Grizzly Bears")
	var did := ai.act(g)
	assert_string_contains(did, "Aggression")
	resolve_stack()
	assert_not_null(_aura_on(bears, "Aggression"), "the threat, not the gift")
	assert_null(_aura_on(wurm, "Aggression"))


# ========================================== the owner's exception, at home --

func test_our_big_attacker_without_trample_wears_it_before_it_swings() -> void:
	# Nothing of theirs to remove; our Craw Wurm (6/4) attacks into an
	# empty board and trample is what six power wants.
	var ai := _armed()
	var wurm := put_battlefield(0, "Craw Wurm")
	var did := ai.act(g)
	assert_string_contains(did, "Aggression")
	resolve_stack()
	assert_not_null(_aura_on(wurm, "Aggression"), "on our own attacker")
	assert_true(wurm.has_keyword(Mtg.Keyword.TRAMPLE))
	assert_true(wurm.has_keyword(Mtg.Keyword.FIRST_STRIKE))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	ai.act(g)
	assert_true(g.combat.attackers.has(wurm.id), "and it swings")


func test_a_small_body_never_wears_it() -> void:
	# Grizzly Bears into an empty board attacks freely — and two power is
	# not what trample is for, while the end-step destroy is real.
	var ai := _armed()
	put_battlefield(0, "Grizzly Bears")
	var did := ai.act(g)
	assert_false(did.contains("Aggression"), "two power: %s" % did)
	assert_true(_in_hand(0, "Aggression"), "kept")


func test_a_body_that_already_tramples_gains_nothing() -> void:
	var ai := _armed()
	put_battlefield(0, "War Mammoth")   # 3/3 trample — small AND already trampling
	put_battlefield(0, "Force of Nature")   # 8/8 trample
	var did := ai.act(g)
	assert_false(did.contains("Aggression"), "trample on a trampler: %s" % did)
	assert_true(_in_hand(0, "Aggression"), "kept")


func test_a_summoning_sick_body_is_not_a_host() -> void:
	# The aura wants an attack this turn; a sick Wurm has none to give.
	var ai := _armed()
	put_battlefield(0, "Craw Wurm", true)
	var did := ai.act(g)
	assert_false(did.contains("Aggression"), "sick: %s" % did)
	assert_true(_in_hand(0, "Aggression"), "kept")


func test_not_after_combat() -> void:
	# In the second main phase the attack is behind us: the aura would be
	# a destroy at our own end step.
	var ai := _wizard(0)
	_lands(0, "Mountain", 3)
	give_hand(0, "Aggression")
	put_battlefield(0, "Craw Wurm")
	advance_to_step(Mtg.Step.MAIN2)
	var did := ai.act(g)
	assert_false(did.contains("Aggression"), "after combat: %s" % did)
	assert_true(_in_hand(0, "Aggression"), "kept")


func test_a_body_that_would_not_attack_is_not_a_host() -> void:
	# Our Craw Wurm (6/4) across from two untapped Craw Wurms of theirs:
	# the declaration would not send it, gifts or no gifts.
	var ai := _armed()
	put_battlefield(0, "Craw Wurm")
	put_battlefield(1, "Craw Wurm")
	put_battlefield(1, "Craw Wurm")
	var did := ai.act(g)
	assert_false(did.contains("Aggression"), "no attack to send it into: %s" % did)
	assert_true(_in_hand(0, "Aggression"), "kept")


# ==================================================== the conscript swings --

func test_our_enchanted_creature_attacks_into_a_hopeless_board() -> void:
	# Our Bears wear Aggression across from a Hill Giant: a losing attack
	# the AI would never choose, and staying home is a destroy at our own
	# end step that leaves nothing to block with. It swings.
	var ai := _wizard(0)
	var bears := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	g.attach_aura_from_anywhere(give_hand(0, "Aggression"), bears, 0)
	assert_true(bears.has_keyword(Mtg.Keyword.FIRST_STRIKE), "worn")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	var did := ai.act(g)
	assert_string_contains(did, "attacker")
	assert_false(g.awaiting_attackers, "the declaration was accepted")
	assert_true(g.combat.attackers.has(bears.id), "the conscript attacked")


func test_their_aggression_on_our_creature_conscripts_it_the_same() -> void:
	var ai := _wizard(0)
	var bears := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	g.attach_aura_from_anywhere(give_hand(1, "Aggression"), bears, 1)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	ai.act(g)
	assert_false(g.awaiting_attackers, "the declaration was accepted")
	assert_true(g.combat.attackers.has(bears.id), "whoever hung it, it swings")


func test_an_unenchanted_bear_still_stays_home() -> void:
	# The control: the same board without the aura keeps the Bears home.
	var ai := _wizard(0)
	var bears := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	ai.act(g)
	assert_false(g.awaiting_attackers, "the declaration was accepted")
	assert_false(g.combat.attackers.has(bears.id), "a losing attack, not chosen")
