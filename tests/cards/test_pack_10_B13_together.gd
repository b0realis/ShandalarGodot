extends GameTest
## Pack 10 (the Urza block), batch B13: Show and Tell and Replenish — cards
## put onto the battlefield TOGETHER (Pack 10 E10,
## MtgGame.put_onto_battlefield_together: the choices first, APNAP, then one
## arrival, then every "enters" event).

const W := Mtg.ManaColor.W
const U := Mtg.ManaColor.U

## A seat that answers yes/no as scripted (-1: the hint) and picks cards by
## name when it can (else the first candidate, the hint).
class Seat extends DecisionAgent:
	var yes := -1
	var prefer: Array = []
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

var me: Seat
var foe: Seat


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	me = Seat.new()
	foe = Seat.new()
	g.set_agent(0, me)
	g.set_agent(1, foe)
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


## "Whenever another creature enters, you gain 1 life."
static func _warden() -> CardData:
	var c := CardData.new("Test Warden", "{W}", Mtg.CardType.CREATURE).pt(1, 1)
	return c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD,
		func(g: MtgGame, s: CardInstance, _e: GameEvent) -> void: g.adjust_life(s.controller_id, 1),
		"Whenever another creature enters, you gain 1 life.",
		func(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
			var other: CardInstance = e.data.get("instance")
			return other != s and other != null and other.is_creature()))


func _show_and_tell() -> CardInstance:
	var spell := give_hand(0, "Show and Tell")
	add_mana(0, U, 3)
	assert_ok(g.cast_spell(0, spell))
	resolve_stack()
	return spell


func test_show_and_tell_and_replenish_are_claimed() -> void:
	for card_name in ["Show and Tell", "Replenish"]:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending", card_name)


# ----------------------------------------------------------- Show and Tell --

func test_each_player_puts_a_card_and_they_arrive_together() -> void:
	var giant := give_hand(0, "Hill Giant")
	var wurm := give_hand(0, "Craw Wurm")
	var warden := give_synthetic(1, _warden())
	foe.prefer = ["Test Warden"]
	_show_and_tell()
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD, "the default: the biggest")
	assert_eq(giant.zone, Mtg.Zone.HAND)
	assert_eq(warden.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(warden.controller_id, 1)
	assert_eq(wurm.controller_id, 0)
	assert_true(wurm.summoning_sick)
	assert_eq(g.players[1].life, 21, "the Warden saw the Wurm arrive with it")


func test_the_active_player_chooses_first_and_the_choice_is_revealed() -> void:
	var seen: Array = []
	g.information_revealed.connect(func(viewer: int, title: String, names: Array) -> void:
		seen.append([viewer, title, names.duplicate()]))
	give_hand(0, "Grizzly Bears")
	give_hand(1, "Hill Giant")
	_show_and_tell()
	assert_eq(seen.size(), 2)
	assert_eq(int(seen[0][0]), -1, "to both players")
	assert_eq(seen[0][2], ["Grizzly Bears"], "the active player's choice first (CR 101.4)")
	assert_eq(seen[1][2], ["Hill Giant"])


func test_show_and_tell_is_optional_for_each_player() -> void:
	var bear := give_hand(0, "Grizzly Bears")
	var giant := give_hand(1, "Hill Giant")
	foe.yes = 0
	_show_and_tell()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(giant.zone, Mtg.Zone.HAND, "declined")


func test_only_artifacts_creatures_enchantments_and_lands_are_offered() -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	var forest := give_hand(0, "Forest")
	me.prefer = ["Lightning Bolt"]
	_show_and_tell()
	assert_eq(bolt.zone, Mtg.Zone.HAND, "an instant is never a candidate")
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].lands_played_this_turn, 0, "not the land drop")


func test_nobody_is_asked_without_a_candidate() -> void:
	give_hand(1, "Lightning Bolt")
	_show_and_tell()
	assert_true(foe.asked.is_empty())


func test_an_aura_needs_a_host_already_there() -> void:
	var strength := give_hand(0, "Holy Strength")
	_show_and_tell()
	assert_eq(strength.zone, Mtg.Zone.HAND, "nothing to enchant: not offered (CR 303.4g)")
	var bear := put_battlefield(0, "Grizzly Bears")
	var second := give_hand(0, "Show and Tell")
	add_mana(0, U, 3)
	assert_ok(g.cast_spell(0, second))
	resolve_stack()
	assert_eq(strength.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(strength.attached_to, bear.id)


func test_a_human_is_asked_inside_the_resolution() -> void:
	g.set_agent(0, HumanAgent.new())
	g.interactive_choices = true
	var bear := give_hand(0, "Grizzly Bears")
	var spell := give_hand(0, "Show and Tell")
	add_mana(0, U, 3)
	assert_ok(g.cast_spell(0, spell))
	var guard := 0
	while g.awaiting_choice == null and not g.stack.is_empty() and guard < 10:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_not_null(g.awaiting_choice, "held on the human's \"may\"")
	if g.awaiting_choice == null: return
	assert_eq(g.awaiting_choice.pid, 0)
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.YES_NO)
	assert_ok(g.answer_choice(true))
	guard = 0
	while g.awaiting_choice != null and guard < 5:
		assert_ok(g.answer_choice(bear.id))
		guard += 1
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------------------------------------- Replenish --

func _replenish() -> void:
	var spell := give_hand(0, "Replenish")
	add_mana(0, W, 4)
	assert_ok(g.cast_spell(0, spell))
	resolve_stack()


func _buried(pid: int, card_name: String) -> CardInstance:
	var card := give_hand(pid, card_name)
	g.discard_cards(pid, [card])
	return card


func test_replenish_returns_every_enchantment_card_together() -> void:
	var crusade := _buried(0, "Crusade")
	var moon := _buried(0, "Bad Moon")
	var bear := _buried(0, "Grizzly Bears")
	var theirs := _buried(1, "Crusade")
	_replenish()
	assert_eq(crusade.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(moon.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(crusade.controller_id, 0)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "not an enchantment")
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD, "only YOUR graveyard")


func test_replenish_aura_finds_a_host_or_stays() -> void:
	var strength := _buried(0, "Holy Strength")
	_replenish()
	assert_eq(strength.zone, Mtg.Zone.GRAVEYARD, "nothing to enchant (CR 303.4g)")
	var bear := put_battlefield(0, "Grizzly Bears")
	_replenish()
	assert_eq(strength.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(strength.attached_to, bear.id)
	assert_eq([bear.cur_power, bear.cur_toughness], [3, 4])
