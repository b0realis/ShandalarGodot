extends GameTest
## Pack 10 (the Urza block), batch B5: the enters-the-battlefield triggers of
## cards/sets/usg/_triggers.gd and cards/sets/uds/_triggers.gd — targets
## chosen as the trigger goes on the stack (none legal: no trigger, CR
## 603.3d), whose choice each "may" and "unless" is, an Aura put onto the
## battlefield without being cast (CR 303.4f-g) and the clauses that act on
## the source only while it is the same object (CR 400.7).

## Every name the two B5 modules claim (60).
const CLAIMED := ["Monk Idealist", "Monk Realist", "Academy Researchers", "Imaginary Pet",
	"Spire Owl", "Stern Proctor", "Abyssal Horror", "Cackling Fiend", "Dark Hatchling",
	"Flesh Reaver", "Hollow Dogs", "Order of Yawgmoth", "Priest of Gix", "Ravenous Skirge",
	"Reclusive Wight", "Skittering Skirge", "Sleeper Agent", "Spined Fluke", "Vebulid",
	"Dromosaur", "Electryte", "Goblin Cadets", "Goblin Lackey", "Retromancer", "Scoria Wurm",
	"Viashino Weaponsmith", "Argothian Enchantress", "Argothian Wurm", "Cave Tiger",
	"Child of Gaea", "Endless Wurm", "Titania's Chosen", "Cathodion", "Karn, Silver Golem",
	"Wall of Junk", "Academy Rector", "False Prophet", "Reliquary Monk", "Tethered Griffin",
	"Aura Thief", "Iridescent Drake", "Kingfisher", "Rayne, Academy Chancellor",
	"Telepathic Spies", "Thieving Magpie", "Apprentice Necromancer", "Body Snatcher",
	"Disease Carriers", "Phyrexian Negator", "Plague Dogs", "Skittering Horror",
	"Covetous Dragon", "Goblin Gardener", "Goblin Masons", "Emperor Crocodile", "Gamekeeper",
	"Marker Beetles", "Yavimaya Elder", "Junk Diver", "Masticore"]

## The three whose only text beyond keywords is the engine's "sacrifice this
## when" clause (CardData.sacrifices_when) rather than a trigger.
const CLAUSE_ONLY := ["Tethered Griffin", "Covetous Dragon", "Emperor Crocodile"]

## A seat whose answers a test scripts: yes/no (-1 follows the hint), card
## names to prefer (else the first, ranked candidate), discards by name.
class Seat extends DecisionAgent:
	var yes := -1
	var prefer: Array = []
	var discard_names: Array = []
	var asked: Array = []

	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
		return hint if yes < 0 else yes == 1

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		asked.append(prompt)
		for name in prefer:
			for c in candidates:
				if c.data.card_name == name: return c
		return null if candidates.is_empty() else candidates[0]

	func answer_discard(game: MtgGame, pid: int, count: int) -> Array[CardInstance]:
		var out: Array[CardInstance] = []
		for name in discard_names:
			for c in game.players[pid].hand:
				if c.data.card_name == name and not out.has(c) and out.size() < count:
					out.append(c)
		if out.size() < count:
			for c in super(game, pid, count):
				if not out.has(c) and out.size() < count: out.append(c)
		return out


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

## [param pid] casts [param card_name] (its mana provided); the stack stays.
func cast_only(card_name: String, targets: Array = [], pid := 0) -> CardInstance:
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	var card := give_hand(pid, card_name)
	fund(pid, card)
	assert_ok(g.cast_spell(pid, card, targets))
	return card

func cast(card_name: String, targets: Array = [], pid := 0) -> CardInstance:
	var card := cast_only(card_name, targets, pid)
	resolve_stack()
	return card

func _names(cards: Array) -> Array:
	var out: Array = []
	for c in cards: out.append(c.data.card_name)
	return out


func test_every_b5_card_is_claimed_and_no_longer_pending() -> void:
	assert_eq(CLAIMED.size(), 60)
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending",
			"%s is still pending" % card_name)
		if CLAUSE_ONLY.has(card_name):
			assert_true(c.sacrifice_condition.is_valid(), "%s has its sacrifice clause" % card_name)
		else:
			assert_false(c.triggered_abilities.is_empty() and c.activated_abilities.is_empty(),
				"%s has its abilities" % card_name)


# ---------------------------------------------------------------- Monk Idealist --

func test_monk_idealist_returns_an_enchantment_card_from_your_graveyard() -> void:
	var crusade := give_hand(0, "Crusade")
	g.discard_cards(0, [crusade])
	var bear := give_hand(0, "Grizzly Bears")
	g.discard_cards(0, [bear])
	cast("Monk Idealist")
	assert_eq(crusade.zone, Mtg.Zone.HAND, "the enchantment card came back")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "a creature card is not a legal target")

func test_monk_idealist_has_no_trigger_without_an_enchantment_card() -> void:
	var bear := give_hand(0, "Grizzly Bears")
	g.discard_cards(0, [bear])
	var their := give_hand(1, "Crusade")
	g.discard_cards(1, [their])
	var monk := cast_only("Monk Idealist")
	resolve_stack()
	assert_eq(monk.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(their.zone, Mtg.Zone.GRAVEYARD, "only YOUR graveyard")
	assert_true(g.stack.is_empty())


# ----------------------------------------------------------------- Monk Realist --

func test_monk_realist_destroys_the_opponents_enchantment_first() -> void:
	var mine := put_battlefield(0, "Crusade")
	var theirs := put_battlefield(1, "Bad Moon")
	cast("Monk Realist")
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD)

func test_monk_realist_must_destroy_its_own_enchantment_when_alone() -> void:
	var mine := put_battlefield(0, "Crusade")
	cast("Monk Realist")
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, "a mandatory target")


# ---------------------------------------------------------- Academy Researchers --

func test_academy_researchers_puts_an_aura_from_hand_onto_itself() -> void:
	var strength := give_hand(0, "Holy Strength")
	var researchers := cast("Academy Researchers")
	assert_eq(strength.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(strength.attached_to, researchers.id)
	assert_eq(researchers.cur_power, 3, "Holy Strength: +1/+2")
	assert_eq(researchers.cur_toughness, 4)

func test_academy_researchers_may_decline() -> void:
	var strength := give_hand(0, "Holy Strength")
	me.yes = 0
	cast("Academy Researchers")
	assert_eq(strength.zone, Mtg.Zone.HAND)

func test_academy_researchers_offers_only_auras_it_could_enchant() -> void:
	var wild := give_hand(0, "Wild Growth")   # enchant land
	cast("Academy Researchers")
	assert_eq(wild.zone, Mtg.Zone.HAND, "an Aura that cannot enchant it stays in hand")
	assert_false(me.asked.any(func(p: String) -> bool: return p.begins_with("Academy Researchers")),
		"nothing to offer, nothing asked")

func test_academy_researchers_does_nothing_once_it_has_left() -> void:
	var strength := give_hand(0, "Holy Strength")
	var researchers := cast_only("Academy Researchers")
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))   # the creature resolves; its trigger waits
	assert_eq(researchers.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.stack.size(), 1)
	g.return_to_hand(researchers)
	resolve_stack()
	assert_eq(strength.zone, Mtg.Zone.HAND)

func test_academy_researchers_asks_a_human_seat_and_holds_the_resolution() -> void:
	var human := HumanAgent.new()
	g.agents[0] = human
	g.interactive_choices = true
	var strength := give_hand(0, "Holy Strength")
	var researchers := cast_only("Academy Researchers")
	var guard := 0
	while not g.stack.is_empty() and g.awaiting_choice == null and guard < 20:
		g.pass_priority(g.priority_player)
		guard += 1
	assert_not_null(g.awaiting_choice, "held open on the may")
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.YES_NO)
	assert_ok(g.answer_choice(true))
	guard = 0
	while g.awaiting_choice != null and guard < 5:
		if g.awaiting_choice.kind == PlayerChoice.Kind.CARD:
			assert_ok(g.answer_choice("Holy Strength"))
		else:
			assert_ok(g.answer_choice(true))
		guard += 1
	resolve_stack()
	assert_eq(strength.attached_to, researchers.id)


# -------------------------------------------------------------------- Spire Owl --

func test_spire_owl_reorders_the_top_four_privately() -> void:
	var lib := g.players[0].library
	var names := ["Lightning Bolt", "Grizzly Bears", "Hill Giant", "Shivan Dragon"]
	for n in names:
		var card := _make_instance(0, n)
		card.zone = Mtg.Zone.LIBRARY
		lib.append(card)
	me.prefer = ["Shivan Dragon", "Hill Giant", "Grizzly Bears", "Lightning Bolt"]
	var shown: Array = []
	g.information_revealed.connect(func(viewer: int, _t: String, cards: Array) -> void:
		shown.append([viewer, cards]))
	cast("Spire Owl")
	assert_eq(shown.size(), 1)
	assert_eq(int(shown[0][0]), 0, "only its controller sees them")
	assert_eq(lib[lib.size() - 1].data.card_name, "Shivan Dragon", "next draw first")
	assert_eq(lib[lib.size() - 4].data.card_name, "Lightning Bolt")


# ----------------------------------------------------------------- Stern Proctor --

func test_stern_proctor_returns_an_artifact_or_enchantment_to_its_owners_hand() -> void:
	var ring := put_battlefield(1, "Sol Ring")
	var bear := put_battlefield(1, "Grizzly Bears")
	cast("Stern Proctor")
	assert_eq(ring.zone, Mtg.Zone.HAND)
	assert_true(g.players[1].hand.has(ring), "its owner's hand")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------------------------------------- Abyssal Horror --

func test_abyssal_horror_makes_the_target_player_discard_two_of_their_choice() -> void:
	give_hand(1, "Forest")
	var bolt := give_hand(1, "Lightning Bolt")
	var bear := give_hand(1, "Grizzly Bears")
	foe.discard_names = ["Lightning Bolt", "Grizzly Bears"]
	cast("Abyssal Horror")
	assert_eq(g.players[1].hand.size(), 1)
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


# ---------------------------------------------------------------- Cackling Fiend --

func test_cackling_fiend_makes_each_opponent_discard_one() -> void:
	give_hand(1, "Forest")
	give_hand(1, "Grizzly Bears")
	var mine := give_hand(0, "Island")
	cast("Cackling Fiend")
	assert_eq(g.players[1].hand.size(), 1)
	assert_eq(mine.zone, Mtg.Zone.HAND, "not its controller")


# ---------------------------------------------------------------- Dark Hatchling --

func test_dark_hatchling_destroys_a_nonblack_creature_without_regeneration() -> void:
	var knight := put_battlefield(1, "Black Knight")
	var giant := put_battlefield(1, "Hill Giant")
	var hatchling := cast("Dark Hatchling")
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD, "black is not a legal target")
	assert_eq(hatchling.zone, Mtg.Zone.BATTLEFIELD)

func test_dark_hatchling_kills_through_a_regeneration_shield() -> void:
	var troll := put_battlefield(1, "Uthden Troll")
	troll.regeneration_shields = 1   # setup: a shield already standing
	cast("Dark Hatchling")
	assert_eq(troll.zone, Mtg.Zone.GRAVEYARD, "can't be regenerated")


# ------------------------------------------------------------------ Priest of Gix --

func test_priest_of_gix_adds_three_black_on_resolution() -> void:
	var priest := cast_only("Priest of Gix")
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))
	assert_eq(priest.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 0, "the trigger uses the stack")
	resolve_stack()
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 3)


# ------------------------------------------------------------------ Sleeper Agent --

func test_sleeper_agent_goes_to_the_opponent_as_it_enters() -> void:
	var agent := cast("Sleeper Agent")
	assert_eq(agent.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(agent.controller_id, 1)
	assert_eq(agent.owner_id, 0)


# ------------------------------------------------------------------- Spined Fluke --

func test_spined_fluke_sacrifices_the_cheapest_other_creature() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var fluke := cast("Spined Fluke")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(fluke.zone, Mtg.Zone.BATTLEFIELD)

func test_spined_fluke_alone_sacrifices_itself() -> void:
	var fluke := cast("Spined Fluke")
	assert_eq(fluke.zone, Mtg.Zone.GRAVEYARD)

func test_spined_fluke_regenerates_for_black() -> void:
	var fluke := put_battlefield(0, "Spined Fluke")
	resolve_stack()   # put_battlefield fires its enters trigger: it eats itself
	fluke = put_battlefield(0, "Spined Fluke")
	put_battlefield(0, "Grizzly Bears")
	resolve_stack()
	assert_eq(fluke.zone, Mtg.Zone.BATTLEFIELD)
	add_mana(0, Mtg.ManaColor.B, 1)
	assert_ok(g.activate_ability(0, fluke, 0))
	resolve_stack()
	g.destroy(fluke)
	assert_eq(fluke.zone, Mtg.Zone.BATTLEFIELD, "regenerated")


# ---------------------------------------------------------------- Argothian Wurm --

func test_argothian_wurm_goes_to_the_library_top_when_the_opponent_sacrifices_a_land() -> void:
	for n in 4: put_battlefield(1, "Forest")
	var wurm := cast("Argothian Wurm")
	assert_eq(wurm.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[0].library[-1], wurm, "on top of its owner's library")
	assert_eq(g.players[1].battlefield.filter(func(i: CardInstance) -> bool: return i.is_land()).size(), 3)

func test_argothian_wurm_stays_when_nobody_sacrifices() -> void:
	put_battlefield(1, "Forest")
	var mine := put_battlefield(0, "Forest")
	var wurm := cast("Argothian Wurm")
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD, "its controller's hint keeps it")

func test_argothian_wurm_asks_the_active_player_first() -> void:
	put_battlefield(0, "Forest")
	for n in 4: put_battlefield(1, "Forest")
	me.yes = 1
	var wurm := cast("Argothian Wurm")
	assert_eq(wurm.zone, Mtg.Zone.LIBRARY, "its controller may sacrifice one too")
	assert_true(foe.asked.is_empty(), "once one player has, nobody else is asked")


# --------------------------------------------------------------- Iridescent Drake --

func test_iridescent_drake_takes_an_aura_from_the_opponents_graveyard() -> void:
	var strength := give_hand(1, "Holy Strength")
	g.discard_cards(1, [strength])
	var drake := cast("Iridescent Drake")
	assert_eq(strength.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(strength.attached_to, drake.id)
	assert_eq(strength.controller_id, 0, "under your control")
	assert_eq(strength.owner_id, 1)

func test_iridescent_drake_leaves_an_aura_it_cannot_carry() -> void:
	var wild := give_hand(0, "Wild Growth")
	g.discard_cards(0, [wild])
	var drake := cast("Iridescent Drake")
	assert_eq(drake.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(wild.zone, Mtg.Zone.GRAVEYARD, "CR 303.4g: it stays")


# --------------------------------------------------------------- Telepathic Spies --

func test_telepathic_spies_shows_the_opponents_hand_to_its_controller_only() -> void:
	give_hand(1, "Lightning Bolt")
	give_hand(1, "Forest")
	var shown: Array = []
	g.information_revealed.connect(func(viewer: int, _t: String, cards: Array) -> void:
		shown.append([viewer, cards]))
	cast("Telepathic Spies")
	assert_eq(shown.size(), 1)
	assert_eq(int(shown[0][0]), 0)
	assert_eq((shown[0][1] as Array).size(), 2)
	assert_true((shown[0][1] as Array).has("Lightning Bolt"))


# ------------------------------------------------------------------ Body Snatcher --

func test_body_snatcher_stays_if_you_discard_a_creature_card() -> void:
	var bear := give_hand(0, "Grizzly Bears")
	give_hand(0, "Forest")
	var snatcher := cast("Body Snatcher")
	assert_eq(snatcher.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)

func test_body_snatcher_is_exiled_without_a_creature_card_to_discard() -> void:
	var forest := give_hand(0, "Forest")
	var snatcher := cast("Body Snatcher")
	assert_eq(snatcher.zone, Mtg.Zone.EXILE)
	assert_eq(forest.zone, Mtg.Zone.HAND, "a land card is no payment")

func test_body_snatcher_is_exiled_when_its_controller_declines() -> void:
	give_hand(0, "Grizzly Bears")
	me.yes = 0
	var snatcher := cast("Body Snatcher")
	assert_eq(snatcher.zone, Mtg.Zone.EXILE)

func test_priest_of_gix_mana_burns_only_under_the_fifth_edition_rules() -> void:
	for preset in ["fifth", "modern"]:
		before_each()
		g.rules.set_preset(preset)
		cast("Priest of Gix")
		assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 3, preset)
		advance_to_step(Mtg.Step.COMBAT_BEGIN)
		assert_eq(g.players[0].life, 17 if preset == "fifth" else 20, "unspent {B}{B}{B} (%s)" % preset)


func test_argothian_wurm_holds_a_human_opponent_on_the_sacrifice() -> void:
	var human := HumanAgent.new()
	g.agents[1] = human
	g.interactive_choices = true
	for n in 4: put_battlefield(1, "Forest")
	var wurm := cast_only("Argothian Wurm")
	var guard := 0
	while not g.stack.is_empty() and g.awaiting_choice == null and guard < 20:
		g.pass_priority(g.priority_player)
		guard += 1
	assert_not_null(g.awaiting_choice, "the opponent's may is the opponent's")
	assert_eq(g.awaiting_choice.pid, 1)
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.YES_NO)
	assert_ok(g.answer_choice(true))
	guard = 0
	while g.awaiting_choice != null and guard < 5:
		assert_ok(g.answer_choice("Forest") if g.awaiting_choice.kind == PlayerChoice.Kind.CARD else g.answer_choice(true))
		guard += 1
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[1].battlefield.size(), 3)
