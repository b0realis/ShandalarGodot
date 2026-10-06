extends GameTest
## Pack 9 (the Tempest block), batch B5: the Tempest Auras in
## cards/sets/tmp/_auras.gd — Crown of Flames, Endless Scream, Flickering
## Ward, Frog Tongue, Hero's Resolve, Sadistic Glee, Shimmering Wings,
## Spinal Graft, Steal Enchantment and Tahngarth's Rage.

const CLAIMED := ["Crown of Flames", "Endless Scream", "Flickering Ward", "Frog Tongue",
	"Hero's Resolve", "Sadistic Glee", "Shimmering Wings", "Spinal Graft",
	"Steal Enchantment", "Tahngarth's Rage"]

## Answers every yes/no with [member yes] and every colour with [member color]
## (0 = follow the hint), and remembers the hints it was given.
class Seat extends DecisionAgent:
	var yes := true
	var color := 0
	var color_hints: Array[int] = []
	func answer_yes_no(_g: MtgGame, _pid: int, _prompt: String, _hint: bool) -> bool:
		return yes
	func answer_color(_g: MtgGame, _pid: int, _prompt: String, hint: int) -> int:
		color_hints.append(hint)
		return color if color != 0 else hint


var me: Seat


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	CardRegistry.ensure_loaded()
	super()
	me = Seat.new()
	g.set_agent(0, me)
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)


func _enchant(pid: int, aura_name: String, host: CardInstance, mana: Array, x := 0) -> CardInstance:
	var aura := give_hand(pid, aura_name)
	for m in mana: add_mana(pid, int(m))
	assert_ok(g.cast_spell(pid, aura, [TargetRef.card(host)], x))
	resolve_stack()
	return aura


func _counter(i: CardInstance, kind: String) -> int:
	return int(i.counters.get(kind, 0))


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)
		assert_true(c.is_aura(), "%s enchants something" % card_name)


# ----------------------------------------------------------- Crown of Flames --

func test_crown_of_flames_pumps_its_host_and_goes_home() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var crown := _enchant(0, "Crown of Flames", bears, [Mtg.ManaColor.R])
	assert_eq(crown.attached_to, bears.id)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, crown, 0, []))
	resolve_stack()
	assert_eq([bears.cur_power, bears.cur_toughness], [3, 2])
	assert_refused(g.activate_ability(0, crown, 1, []))
	assert_eq(crown.zone, Mtg.Zone.BATTLEFIELD, "no {R}, no return")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.activate_ability(0, crown, 1, []))
	resolve_stack()
	assert_eq(crown.zone, Mtg.Zone.HAND)
	assert_eq(bears.cur_power, 3, "the pump lasts until end of turn, Aura or not")
	advance_to_next_turn()
	assert_eq(bears.cur_power, 2)


func test_crown_of_flames_pump_follows_the_creature_it_enchanted() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var crown := _enchant(0, "Crown of Flames", bears, [Mtg.ManaColor.R])
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.activate_ability(0, crown, 0, []))
	# Return the Aura in response: the pump still finds the creature.
	assert_ok(g.activate_ability(0, crown, 1, []))
	resolve_stack()
	assert_eq(crown.zone, Mtg.Zone.HAND)
	assert_eq(bears.cur_power, 3)


# ------------------------------------------------------------ Endless Scream --

func test_endless_scream_enters_with_x_counters_and_pumps_by_them() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var scream := give_hand(0, "Endless Scream")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, scream, [TargetRef.card(bears)], 3))
	resolve_stack()
	assert_eq(scream.attached_to, bears.id)
	assert_eq(_counter(scream, "scream"), 3, "on the Aura")
	assert_eq([bears.cur_power, bears.cur_toughness], [5, 2])
	g.remove_counters(scream, "scream", 1)
	assert_eq(bears.cur_power, 4, "the counters are read live")


func test_endless_scream_for_zero_gives_nothing() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var scream := _enchant(0, "Endless Scream", bears, [Mtg.ManaColor.B], 0)
	assert_eq(_counter(scream, "scream"), 0)
	assert_eq(bears.cur_power, 2)


# ----------------------------------------------------------- Flickering Ward --

func test_flickering_ward_protects_from_the_chosen_colour() -> void:
	me.color = Mtg.ManaColor.R
	var bears := put_battlefield(0, "Grizzly Bears")
	var ward := _enchant(0, "Flickering Ward", bears, [Mtg.ManaColor.W])
	assert_eq(me.color_hints.size(), 1, "the colour is asked as it enters")
	assert_ne(bears.cur_protection & Mtg.ManaColor.R, 0)
	assert_eq(ward.zone, Mtg.Zone.BATTLEFIELD)
	advance_to_next_turn()
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(1, bolt, [TargetRef.card(bears)]))


func test_flickering_ward_from_white_keeps_itself_but_not_another_white_aura() -> void:
	me.color = Mtg.ManaColor.W
	var bears := put_battlefield(0, "Grizzly Bears")
	var strength := _enchant(0, "Holy Strength", bears, [Mtg.ManaColor.W])
	var ward := _enchant(0, "Flickering Ward", bears, [Mtg.ManaColor.W])
	assert_eq(ward.zone, Mtg.Zone.BATTLEFIELD, "this effect doesn't remove this Aura (CR 702.16d)")
	assert_eq(strength.zone, Mtg.Zone.GRAVEYARD, "another white Aura falls off")


func test_flickering_ward_returns_to_its_owners_hand_for_white() -> void:
	me.color = Mtg.ManaColor.B
	var bears := put_battlefield(0, "Grizzly Bears")
	var ward := _enchant(0, "Flickering Ward", bears, [Mtg.ManaColor.W])
	assert_refused(g.activate_ability(0, ward, 0, []))
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.activate_ability(0, ward, 0, []))
	resolve_stack()
	assert_eq(ward.zone, Mtg.Zone.HAND)
	assert_eq(bears.cur_protection & Mtg.ManaColor.B, 0, "the protection went with it")


# --------------------------------------------------------------- Frog Tongue --

func test_frog_tongue_draws_a_card_and_lets_its_host_block_a_flyer() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var tongue := give_hand(0, "Frog Tongue")
	add_mana(0, Mtg.ManaColor.G)
	var hand := g.players[0].hand.size()
	assert_ok(g.cast_spell(0, tongue, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand, "cast one, drew one")
	assert_true(bears.has_keyword(Mtg.Keyword.REACH))
	var angel := put_battlefield(1, "Serra Angel")
	advance_to_next_turn()
	run_combat([angel.id], {bears.id: angel.id})
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "it blocked the Angel")
	assert_eq(g.players[0].life, 20)


# ------------------------------------------------------------ Hero's Resolve --

func test_heros_resolve_gives_plus_one_plus_five() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var resolve := _enchant(0, "Hero's Resolve", bears, [Mtg.ManaColor.W, Mtg.ManaColor.C])
	assert_eq(resolve.attached_to, bears.id)
	assert_eq([bears.cur_power, bears.cur_toughness], [3, 7])
	g.destroy(resolve)
	assert_eq([bears.cur_power, bears.cur_toughness], [2, 2])


# ------------------------------------------------------------- Sadistic Glee --

func test_sadistic_glee_feeds_on_every_creature_death() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var glee := _enchant(0, "Sadistic Glee", bears, [Mtg.ManaColor.B])
	var lions := put_battlefield(1, "Savannah Lions")
	g.destroy(lions)
	resolve_stack()
	assert_eq(_counter(bears, "+1/+1"), 1, "an opponent's creature")
	var giant := put_battlefield(0, "Hill Giant")
	g.destroy(giant)
	resolve_stack()
	assert_eq(_counter(bears, "+1/+1"), 2, "one of yours")
	assert_eq([bears.cur_power, bears.cur_toughness], [4, 4])
	g.destroy(bears)
	resolve_stack()
	assert_eq(glee.zone, Mtg.Zone.GRAVEYARD, "its own host's death grows nothing")


# ---------------------------------------------------------- Shimmering Wings --

func test_shimmering_wings_gives_flying_and_returns_for_blue() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var wings := _enchant(0, "Shimmering Wings", bears, [Mtg.ManaColor.U])
	assert_true(bears.has_keyword(Mtg.Keyword.FLYING))
	assert_refused(g.activate_ability(0, wings, 0, []))
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.activate_ability(0, wings, 0, []))
	resolve_stack()
	assert_eq(wings.zone, Mtg.Zone.HAND)
	assert_false(bears.has_keyword(Mtg.Keyword.FLYING))


func test_shimmering_wings_return_reads_the_ai_self_bounce_role() -> void:
	var wings := CardRegistry.get_card("Shimmering Wings")
	assert_eq(wings.activated_abilities[0].effects[0].ai_role, &"self_bounce")
	var crown := CardRegistry.get_card("Crown of Flames")
	assert_eq(crown.activated_abilities[0].effects[0].ai_role, &"pump_host")


# -------------------------------------------------------------- Spinal Graft --

func test_spinal_graft_pumps_and_kills_its_host_when_targeted() -> void:
	var skeletons := put_battlefield(0, "Drudge Skeletons")
	var graft := _enchant(0, "Spinal Graft", skeletons, [Mtg.ManaColor.B, Mtg.ManaColor.C])
	assert_eq([skeletons.cur_power, skeletons.cur_toughness], [4, 4])
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, skeletons, 0, []))
	resolve_stack()
	assert_eq(skeletons.zone, Mtg.Zone.BATTLEFIELD, "regenerating targets nothing")
	var growth := give_hand(0, "Giant Growth")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(skeletons)]))
	assert_eq(g.stack.size(), 2, "the trigger waits above the spell")
	resolve_stack()
	assert_eq(skeletons.zone, Mtg.Zone.GRAVEYARD, "it can't be regenerated")
	assert_eq(graft.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(growth.zone, Mtg.Zone.GRAVEYARD, "the Growth lost its target")


func test_spinal_graft_ignores_untargeted_damage() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	_enchant(0, "Spinal Graft", bears, [Mtg.ManaColor.B, Mtg.ManaColor.C])
	var giant := put_battlefield(1, "Hill Giant")
	g.deal_damage(giant, TargetRef.card(bears), 2)
	assert_true(g.stack.is_empty())
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)


# --------------------------------------------------------- Steal Enchantment --

func test_steal_enchantment_takes_an_enchantment_until_it_leaves() -> void:
	var moon := put_battlefield(1, "Bad Moon")
	var steal := _enchant(0, "Steal Enchantment", moon, [Mtg.ManaColor.U, Mtg.ManaColor.U])
	assert_eq(steal.attached_to, moon.id)
	assert_eq(moon.controller_id, 0)
	g.destroy(steal)
	assert_eq(moon.controller_id, 1, "control returns with the Aura gone")


func test_steal_enchantment_cannot_enchant_a_creature() -> void:
	var bears := put_battlefield(1, "Grizzly Bears")
	var steal := give_hand(0, "Steal Enchantment")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_refused(g.cast_spell(0, steal, [TargetRef.card(bears)]))
	assert_eq(steal.zone, Mtg.Zone.HAND)


func test_steal_enchantment_on_an_aura_leaves_it_on_its_creature() -> void:
	var lions := put_battlefield(1, "Savannah Lions")
	advance_to_next_turn()
	var strength := _enchant(1, "Holy Strength", lions, [Mtg.ManaColor.W])
	assert_eq(strength.attached_to, lions.id)
	advance_to_next_turn()
	_enchant(0, "Steal Enchantment", strength, [Mtg.ManaColor.U, Mtg.ManaColor.U])
	assert_eq(strength.controller_id, 0, "you control the Aura")
	assert_eq(strength.attached_to, lions.id, "it stays on what it enchants")
	assert_eq(lions.controller_id, 1)
	assert_eq([lions.cur_power, lions.cur_toughness], [3, 3])


# ---------------------------------------------------------- Tahngarth's Rage --

func test_tahngarths_rage_pumps_an_attacker_and_shrinks_everything_else() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	_enchant(0, "Tahngarth's Rage", bears, [Mtg.ManaColor.R])
	assert_eq([bears.cur_power, bears.cur_toughness], [0, 1])
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bears.id]))
	assert_eq([bears.cur_power, bears.cur_toughness], [5, 2])
	advance_to_step(Mtg.Step.MAIN2)
	assert_eq(g.players[1].life, 15)
	assert_eq([bears.cur_power, bears.cur_toughness], [0, 1], "combat is over")


func test_tahngarths_rage_kills_an_opposing_one_toughness_creature() -> void:
	var lions := put_battlefield(1, "Savannah Lions")
	var rage := _enchant(0, "Tahngarth's Rage", lions, [Mtg.ManaColor.R])
	assert_eq(lions.zone, Mtg.Zone.GRAVEYARD, "-2/-1 on a 2/1")
	assert_eq(rage.zone, Mtg.Zone.GRAVEYARD)
