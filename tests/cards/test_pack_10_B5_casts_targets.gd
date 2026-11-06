extends GameTest
## Pack 10 (the Urza block), batch B5: the spell-cast and becomes-the-target
## triggers of cards/sets/usg/_triggers.gd and cards/sets/uds/_triggers.gd
## — whose cast it hears and what kind of spell (live types and colors on
## the stack), Argothian Enchantress's shroud, and Retromancer's and
## Rayne's "the targeting object's controller" (BECAME_TARGET, once per
## targeted object per stack object), Rayne's two "may"s and whether she is
## enchanted as the ability resolves or as she last existed (CR 608.2h).

class Seat extends DecisionAgent:
	var yes := -1
	var asked: Array = []

	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
		return hint if yes < 0 else yes == 1


var me: Seat
var foe: Seat


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	CardRegistry.ensure_loaded()
	super()
	me = Seat.new()
	foe = Seat.new()
	g.set_agent(0, me)
	g.set_agent(1, foe)
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-10", false)


func fund(pid: int, card: CardInstance) -> void:
	var cost := card.data.cost
	for c in cost.colored:
		add_mana(pid, c, int(cost.colored[c]))
	if cost.generic > 0:
		add_mana(pid, Mtg.ManaColor.C, cost.generic)

## [param pid] casts [param card_name]; the stack stays.
func cast_only(card_name: String, targets: Array = [], pid := 0) -> CardInstance:
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	var card := give_hand(pid, card_name)
	fund(pid, card)
	assert_ok(g.cast_spell(pid, card, targets))
	return card

## P1 bolts [param target] (a TargetRef) in P0's main phase; resolves all.
func _opponent_bolts(target: TargetRef) -> void:
	cast_only("Lightning Bolt", [target], 1)
	resolve_stack()


# ---------------------------------------------- Skittering Skirge, Skittering Horror --

func test_skittering_skirge_and_horror_go_when_you_cast_a_creature_spell() -> void:
	var skirge := put_battlefield(0, "Skittering Skirge")
	var horror := put_battlefield(0, "Skittering Horror")
	cast_only("Lightning Bolt", [TargetRef.player(1)])
	resolve_stack()
	assert_eq(skirge.zone, Mtg.Zone.BATTLEFIELD, "not a creature spell")
	assert_eq(horror.zone, Mtg.Zone.BATTLEFIELD)
	var bear := cast_only("Grizzly Bears")
	assert_eq(g.stack.size(), 3, "the Bears and two triggers above it")
	resolve_stack()
	assert_eq(skirge.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(horror.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)

func test_skittering_skirge_ignores_the_opponents_creature_spells() -> void:
	var skirge := put_battlefield(0, "Skittering Skirge")
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	cast_only("Llanowar Elves", [], 1)
	resolve_stack()
	assert_eq(skirge.zone, Mtg.Zone.BATTLEFIELD)


# --------------------------------------------------------- Argothian Enchantress --

func test_argothian_enchantress_has_shroud() -> void:
	var enchantress := put_battlefield(0, "Argothian Enchantress")
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R, 1)
	assert_ok(g.pass_priority(0))
	assert_refused(g.cast_spell(1, bolt, [TargetRef.card(enchantress)]))
	assert_true(enchantress.cur_shroud)

func test_argothian_enchantress_draws_for_your_enchantment_spells_only() -> void:
	put_battlefield(0, "Argothian Enchantress")
	var hand := g.players[0].hand.size()
	cast_only("Crusade")
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 1)
	cast_only("Grizzly Bears")
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 1, "a creature spell draws nothing")


# --------------------------------------------------------------- Titania's Chosen --

func test_titanias_chosen_grows_for_every_green_spell() -> void:
	var chosen := put_battlefield(0, "Titania's Chosen")
	cast_only("Grizzly Bears")
	resolve_stack()
	assert_eq(chosen.cur_power, 2)
	cast_only("Giant Growth", [TargetRef.card(chosen)], 1)
	resolve_stack()
	assert_eq(int(chosen.counters.get("+1/+1", 0)), 2, "an opponent's green spell counts too")
	cast_only("Lightning Bolt", [TargetRef.player(1)])
	resolve_stack()
	assert_eq(int(chosen.counters.get("+1/+1", 0)), 2, "red does not")


# --------------------------------------------------------------------- Retromancer --

func test_retromancer_punishes_the_targeting_spells_controller() -> void:
	var retro := put_battlefield(0, "Retromancer")
	_opponent_bolts(TargetRef.card(retro))
	assert_eq(g.players[1].life, 17, "the trigger resolves before the Bolt")
	assert_eq(retro.zone, Mtg.Zone.GRAVEYARD)

func test_retromancer_also_hits_its_own_controller() -> void:
	var retro := put_battlefield(0, "Retromancer")
	cast_only("Giant Growth", [TargetRef.card(retro)])
	resolve_stack()
	assert_eq(g.players[0].life, 17)
	assert_eq(g.players[1].life, 20)

func test_retromancer_still_deals_damage_after_it_has_left() -> void:
	var retro := put_battlefield(0, "Retromancer")
	cast_only("Lightning Bolt", [TargetRef.card(retro)], 1)
	g.return_to_hand(retro)
	resolve_stack()
	assert_eq(retro.zone, Mtg.Zone.HAND)
	assert_eq(g.players[1].life, 17, "from the Retromancer as it last existed (CR 608.2h)")


# ------------------------------------------------------ Rayne, Academy Chancellor --

func test_rayne_draws_when_an_opponent_targets_you() -> void:
	put_battlefield(0, "Rayne, Academy Chancellor")
	var hand := g.players[0].hand.size()
	_opponent_bolts(TargetRef.player(0))
	assert_eq(g.players[0].hand.size(), hand + 1)

func test_rayne_draws_when_an_opponent_targets_your_permanent() -> void:
	put_battlefield(0, "Rayne, Academy Chancellor")
	var bear := put_battlefield(0, "Grizzly Bears")
	var hand := g.players[0].hand.size()
	_opponent_bolts(TargetRef.card(bear))
	assert_eq(g.players[0].hand.size(), hand + 1)

func test_rayne_ignores_your_own_targets_and_the_opponents_side() -> void:
	put_battlefield(0, "Rayne, Academy Chancellor")
	var theirs := put_battlefield(1, "Grizzly Bears")
	var mine := put_battlefield(0, "Hill Giant")
	var hand := g.players[0].hand.size()
	cast_only("Giant Growth", [TargetRef.card(mine)])
	resolve_stack()
	_opponent_bolts(TargetRef.card(theirs))
	assert_eq(g.players[0].hand.size(), hand)

func test_rayne_draws_two_when_enchanted_and_the_draws_are_optional() -> void:
	var rayne := put_battlefield(0, "Rayne, Academy Chancellor")
	var strength := give_hand(0, "Holy Strength")
	g.attach_aura_from_anywhere(strength, rayne, 0)
	assert_true(g.is_enchanted(rayne))
	var hand := g.players[0].hand.size()
	_opponent_bolts(TargetRef.player(0))
	assert_eq(g.players[0].hand.size(), hand + 2)
	me.yes = 0
	_opponent_bolts(TargetRef.player(0))
	assert_eq(g.players[0].hand.size(), hand + 2, "declined")

func test_rayne_reads_whether_she_was_enchanted_as_she_last_existed() -> void:
	var rayne := put_battlefield(0, "Rayne, Academy Chancellor")
	var strength := give_hand(0, "Holy Strength")
	g.attach_aura_from_anywhere(strength, rayne, 0)
	var hand := g.players[0].hand.size()
	# P1 bolts P0; with the trigger waiting, Rayne is destroyed.
	cast_only("Lightning Bolt", [TargetRef.player(0)], 1)
	assert_eq(g.stack.size(), 2, "the Bolt and Rayne's trigger")
	g.destroy(rayne)
	assert_eq(rayne.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(strength.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].hand.size(), hand + 2, "enchanted as she last existed")

func test_rayne_enchanted_after_triggering_counts_as_she_last_existed() -> void:
	var rayne := put_battlefield(0, "Rayne, Academy Chancellor")
	var hand := g.players[0].hand.size()
	cast_only("Lightning Bolt", [TargetRef.player(0)], 1)
	var strength := give_hand(0, "Holy Strength")
	g.attach_aura_from_anywhere(strength, rayne, 0)   # setup: enchanted only now
	g.destroy(rayne)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 2, "the leave hook saw her Aura")

func test_rayne_reads_her_auras_live_while_she_stays() -> void:
	var rayne := put_battlefield(0, "Rayne, Academy Chancellor")
	var strength := give_hand(0, "Holy Strength")
	g.attach_aura_from_anywhere(strength, rayne, 0)
	var hand := g.players[0].hand.size()
	cast_only("Lightning Bolt", [TargetRef.player(0)], 1)
	g.destroy(strength)
	resolve_stack()
	assert_eq(rayne.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].hand.size(), hand + 1, "no longer enchanted as the ability resolves")
