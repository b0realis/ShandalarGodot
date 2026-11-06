extends GameTest
## Pack 10 (the Urza block), batch B1: Exhume ({1}{B} sorcery,
## cards/sets/usg/_spells.gd) — "Each player puts a creature card from
## their graveyard onto the battlefield." Untargeted; each player chooses
## in APNAP order (CR 101.4) before any card moves, then the chosen cards
## arrive together (MtgGame.put_onto_battlefield_together, Pack 10 E10).


## Scripted answers: a card by name from [member picks] (else the first
## candidate). [member seen] keeps the names offered; [member
## field_when_asked] counts both battlefields as the question is put.
class Seat extends DecisionAgent:
	var picks: Array[String] = []
	var seen: Array[String] = []
	var field_when_asked := -1
	func answer_card(g: MtgGame, pid: int, candidates: Array[CardInstance], _prompt: String) -> CardInstance:
		seen.clear()
		for c in candidates: seen.append(c.data.card_name)
		field_when_asked = g.players[0].battlefield.size() + g.players[1].battlefield.size()
		for n in picks.size():
			for c in candidates:
				if c.data.card_name == picks[n]:
					picks.remove_at(n)
					return c
		return null if candidates.is_empty() else candidates[0]


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _seat(pid: int) -> Seat:
	var s := Seat.new()
	g.set_agent(pid, s)
	return s

func _grave(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	g.put_into_graveyard(inst)
	return inst

func _cast_exhume() -> CardInstance:
	var exhume := give_hand(0, "Exhume")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, exhume))
	return exhume


func test_exhume_is_claimed() -> void:
	var c := CardRegistry.get_card("Exhume")
	assert_not_null(c)
	if c == null: return
	assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending")
	assert_eq((c.spell_effects[0] as EffectBase).ai_role, &"each_player_reanimates_one")


func test_each_player_returns_the_creature_card_of_their_choice() -> void:
	var me := _seat(0)
	var them := _seat(1)
	me.picks = ["Grizzly Bears"]
	them.picks = ["Hill Giant"]
	var wurm := _grave(0, "Craw Wurm")
	var bears := _grave(0, "Grizzly Bears")
	var bolt := _grave(0, "Lightning Bolt")
	var giant := _grave(1, "Hill Giant")
	var angel := _grave(1, "Serra Angel")
	var exhume := _cast_exhume()
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "P0's pick")
	assert_eq(bears.controller_id, 0)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "P1's pick")
	assert_eq(giant.controller_id, 1, "under the player who chose it")
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD, "a noncreature card is never offered")
	assert_false(me.seen.has("Lightning Bolt"))
	assert_eq(exhume.zone, Mtg.Zone.GRAVEYARD)


func test_a_player_with_no_creature_card_returns_nothing() -> void:
	var bears := _grave(1, "Grizzly Bears")
	_grave(0, "Lightning Bolt")
	_cast_exhume()
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "only the opponent had one")
	for i in g.players[0].battlefield:
		assert_false(i.is_creature())


func test_exhume_with_empty_graveyards_does_nothing() -> void:
	# Untargeted: nothing to refuse at casting, nothing to fizzle.
	var exhume := _cast_exhume()
	resolve_stack()
	assert_eq(exhume.zone, Mtg.Zone.GRAVEYARD)
	for p in g.players:
		for i in p.battlefield:
			assert_false(i.is_creature())


func test_both_choices_are_made_before_either_card_moves() -> void:
	var me := _seat(0)
	var them := _seat(1)
	_grave(0, "Grizzly Bears")
	_grave(1, "Hill Giant")
	var before := g.players[0].battlefield.size() + g.players[1].battlefield.size()
	_cast_exhume()
	resolve_stack()
	assert_eq(me.field_when_asked, before, "P0 was asked with nothing moved")
	assert_eq(them.field_when_asked, before, "and so was P1, after P0 chose")
	assert_eq(them.seen, ["Hill Giant"] as Array[String], "only P1's own graveyard")


## "Whenever another creature enters, you gain 1 life" (a synthetic Soul
## Warden): returned with the other card, it sees it (E10).
static func _warden() -> CardData:
	var c := CardData.new("Test Warden", "{W}", Mtg.CardType.CREATURE).pt(1, 1)
	return c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD,
		func(g: MtgGame, s: CardInstance, _e: GameEvent) -> void: g.adjust_life(s.controller_id, 1),
		"Whenever another creature enters, you gain 1 life.",
		func(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
			var other: CardInstance = e.data.get("instance")
			return other != s and other != null and other.is_creature()))


func test_the_two_cards_arrive_together() -> void:
	var warden := give_synthetic(1, _warden())
	g.discard_cards(1, [warden])
	_grave(0, "Grizzly Bears")
	_cast_exhume()
	resolve_stack()
	assert_eq(warden.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[1].life, 21,
		"P1's Warden saw P0's Bears arrive, though the Bears were put down first")


func test_a_human_seat_is_held_on_its_choice() -> void:
	var human := HumanAgent.new()
	g.agents[0] = human
	g.interactive_choices = true
	var bears := _grave(0, "Grizzly Bears")
	var wurm := _grave(0, "Craw Wurm")
	var giant := _grave(1, "Hill Giant")
	_cast_exhume()
	var guard := 0
	while g.awaiting_choice == null and not g.stack.is_empty() and guard < 10:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_not_null(g.awaiting_choice, "held on P0's pick")
	if g.awaiting_choice == null: return
	assert_eq(g.awaiting_choice.pid, 0)
	assert_eq(g.awaiting_choice.candidates.size(), 2)
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "nothing moved yet")
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_ok(g.answer_choice(bears.id))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "the player's pick, not the costlier Wurm")
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)


# -------------------------------------------------------------- fair hints --

func _hide(variant: int) -> void:
	var tops := ["Lightning Bolt", "Island", "Serra Angel"]
	if variant == 1:
		tops.reverse()
		for card_name in ["Wrath of God", "Lightning Bolt", "Shivan Dragon"]:
			give_hand(1, card_name)
	for pid in [0, 1]:
		for card_name in tops:
			var card := give_hand(pid, card_name)
			g.put_from_hand_on_top_of_library(card)

func _exhume_once(variant: int) -> Array:
	before_each()
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	g.set_agent(0, AiPlayer.new(0, p))
	g.set_agent(1, AiPlayer.new(1, p))
	var cards := [_grave(0, "Grizzly Bears"), _grave(0, "Craw Wurm"), _grave(0, "Hill Giant"),
		_grave(1, "Serra Angel"), _grave(1, "Gray Ogre")]
	_hide(variant)
	_cast_exhume()
	resolve_stack()
	var out: Array = []
	for i in cards: out.append(i.zone)
	return out

func test_the_choices_do_not_read_hidden_zones() -> void:
	assert_eq(_exhume_once(0), _exhume_once(1))
