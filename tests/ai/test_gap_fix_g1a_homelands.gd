extends GameTest
## GAP FIX G1a (gap review 2026-11-10, the two Homelands questions; the
## owner's defaults of that day).
##
## Aether Storm — "Pay 4 life: Destroy this enchantment. Any player may
## activate this ability." The pilot paid the 4 life to destroy even its OWN
## Storm for a Grizzly Bears. It pays now only when what it then casts —
## the creature cards of its own hand its mana pays for this main phase —
## is worth more than the life, so never for one cheap creature.
##
## Clockwork Steed / Swarm — "{X}, {T}: put up to X +1/+0 counters on this
## creature. Activate only during your upkeep." The {T} keeps it home: the
## pilot wound up a 3/3 that would have attacked an empty board. It
## recharges now only when the attack declaration would leave it home.
##
## The Homelands module is [member AiProfile.forecasts_tactics] whole; its
## null is the shared scorer. Public board and our own hand only: a card
## swapped in their hand does not move either decision.

const H := preload("res://engine/ai/homelands_tactics.gd")


func before_each() -> void:
	CardPacks.set_enabled("pack-4", true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-4", false)
	CardPacks.set_enabled(CardPacks.ID, false)


func pilot(forecasts := true) -> AiPlayer:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	ai.profile.develops_late = false
	ai.profile.forecasts_tactics = forecasts
	g.set_agent(0, ai)
	return ai


static func _digest(option: Dictionary) -> Array:
	if option.is_empty(): return []
	return [snappedf(float(option["value"]), 0.001), int(option.get("x", 0))]


# --- Aether Storm -----------------------------------------------------------

func test_our_own_storm_is_not_lifted_for_a_grizzly_bears() -> void:
	var storm := put_battlefield(0, "Aether Storm")
	give_hand(0, "Grizzly Bears")
	for _i in 2: put_battlefield(0, "Forest")
	for _i in 3: give_hand(1, "Craw Wurm")   # their hidden hand: what the Storm holds back
	advance_to_step(Mtg.Step.MAIN1)
	var ai := pilot()
	assert_true(ai._ability_option(g, storm, 0, AiPlayer.Moment.MAIN).is_empty())
	ai.act(g)
	assert_eq(storm.zone, Mtg.Zone.BATTLEFIELD, "four life for one 2/2")
	assert_eq(g.players[0].life, 20)


func test_their_storm_is_not_lifted_for_one_cheap_creature() -> void:
	var storm := put_battlefield(1, "Aether Storm")
	give_hand(0, "Grizzly Bears")
	for _i in 2: put_battlefield(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	var ai := pilot()
	assert_true(ai._ability_option(g, storm, 0, AiPlayer.Moment.MAIN).is_empty(),
		"a 2/2 is not worth four life")


func test_their_storm_is_lifted_for_a_craw_wurm() -> void:
	var storm := put_battlefield(1, "Aether Storm")
	var wurm := give_hand(0, "Craw Wurm")
	for _i in 6: put_battlefield(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	var ai := pilot()
	assert_eq(ai.act(g), "activated Aether Storm", "a 6/4 is worth four life")
	resolve_stack()
	assert_eq(storm.zone, Mtg.Zone.GRAVEYARD)
	assert_string_contains(ai.act(g), "Craw Wurm")
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)


func test_two_creatures_the_mana_pays_for_add_up() -> void:
	var storm := put_battlefield(0, "Aether Storm")
	give_hand(0, "Grizzly Bears")
	give_hand(0, "Giant Spider")
	var forests: Array = []
	for _i in 6: forests.append(put_battlefield(0, "Forest"))
	advance_to_step(Mtg.Step.MAIN1)
	var ai := pilot()
	assert_true(_clears(ai._ability_option(g, storm, 0, AiPlayer.Moment.MAIN)),
		"a 2/4 and a 2/2 together are worth the four life")
	forests[4].tapped = true
	forests[5].tapped = true
	assert_false(_clears(ai._ability_option(g, storm, 0, AiPlayer.Moment.MAIN)),
		"with four mana only the Giant Spider is cast, and it alone is not")
	assert_eq(ai._try_activate(g), "")
	assert_eq(storm.zone, Mtg.Zone.BATTLEFIELD)


## Does [param option] clear the main phase's bar — would it be activated?
static func _clears(option: Dictionary) -> bool:
	return not option.is_empty() and float(option["value"]) >= AiPlayer.ABILITY_BAR_MAIN


func test_the_storm_reads_no_hidden_card() -> void:
	var storm := put_battlefield(1, "Aether Storm")
	give_hand(0, "Craw Wurm")
	for _i in 6: put_battlefield(0, "Forest")
	var hidden := give_hand(1, "Craw Wurm")
	advance_to_step(Mtg.Step.MAIN1)
	var ai := pilot()
	var before := _digest(ai._ability_option(g, storm, 0, AiPlayer.Moment.MAIN))
	hidden.data = CardRegistry.get_card("Lightning Bolt")
	assert_eq(_digest(ai._ability_option(g, storm, 0, AiPlayer.Moment.MAIN)), before)
	assert_false(before.is_empty())


func test_the_storm_null_is_untouched() -> void:
	var storm := put_battlefield(0, "Aether Storm")
	advance_to_step(Mtg.Step.MAIN1)
	assert_null(H.option(g, pilot(false), storm, 0, "MAIN"))


# --- Clockwork Steed --------------------------------------------------------

func _steed_at_our_upkeep(counters: int) -> CardInstance:
	var steed := put_battlefield(0, "Clockwork Steed")   # enters with four
	if counters < 4: g.remove_counters(steed, "+1/+0", 4 - counters)
	advance_to_next_turn()
	advance_to_step(Mtg.Step.UPKEEP)
	assert_eq(g.active_player, 0)
	add_mana(0, Mtg.ManaColor.C, 5)
	return steed


func test_a_steed_that_attacks_this_turn_is_not_wound_up() -> void:
	var steed := _steed_at_our_upkeep(3)
	var ai := pilot()
	assert_true(ai._ability_option(g, steed, 0, AiPlayer.Moment.UPKEEP).is_empty(),
		"a 3/3 into an empty board attacks; {T} would keep it home")
	assert_eq(ai._try_activate(g, AiPlayer.Moment.UPKEEP), "")
	assert_false(steed.tapped)


func test_a_steed_with_no_power_is_wound_up() -> void:
	var steed := _steed_at_our_upkeep(0)
	var ai := pilot()
	assert_eq(ai._try_activate(g, AiPlayer.Moment.UPKEEP), "activated Clockwork Steed",
		"a 0/3 has no attack to lose")
	resolve_stack()
	assert_eq(int(steed.counters.get("+1/+0", 0)), 4)


func test_a_steed_kept_home_by_a_blocker_is_wound_up() -> void:
	var steed := _steed_at_our_upkeep(1)
	put_battlefield(1, "Hill Giant")   # a 1/3 does not attack into a 3/3
	var ai := pilot()
	assert_eq(ai._try_activate(g, AiPlayer.Moment.UPKEEP), "activated Clockwork Steed")


func test_the_wind_up_reads_no_hidden_card() -> void:
	var steed := _steed_at_our_upkeep(1)
	put_battlefield(1, "Hill Giant")
	var hidden := give_hand(1, "Giant Growth")
	var ai := pilot()
	var before := _digest(ai._ability_option(g, steed, 0, AiPlayer.Moment.UPKEEP))
	hidden.data = CardRegistry.get_card("Terror")
	assert_eq(_digest(ai._ability_option(g, steed, 0, AiPlayer.Moment.UPKEEP)), before)
	assert_false(before.is_empty())
