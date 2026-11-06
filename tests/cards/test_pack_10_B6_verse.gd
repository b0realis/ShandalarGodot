extends GameTest
## Pack 10 (the Urza block), batch B6: Urza's Saga's verse-counter
## enchantments in cards/sets/usg/_enchantments.gd — Serra's Liturgy,
## Lilting Refrain, Recantation, Discordant Dirge, Vile Requiem, Rumbling
## Crescendo, Torch Song, Midsummer Revel and War Dance. The counter is
## optional at each of the controller's upkeeps; "up to X targets" is fixed
## as the ability is announced, every other X is the count the sacrifice
## recorded (CR 601.2c, 608.2h).

const MT := preload("res://engine/ai/mirage_tactics.gd")
const W := Mtg.ManaColor.W
const U := Mtg.ManaColor.U
const B := Mtg.ManaColor.B
const R := Mtg.ManaColor.R
const G := Mtg.ManaColor.G

const VERSE := ["Serra's Liturgy", "Lilting Refrain", "Recantation", "Discordant Dirge",
	"Vile Requiem", "Rumbling Crescendo", "Torch Song", "Midsummer Revel", "War Dance"]

## A seat whose answers a test scripts: yes/no (-1 follows the hint), card
## names to prefer, and [member decline] for an optional card question.
class Seat extends DecisionAgent:
	var yes := -1
	var prefer: Array = []
	var decline := false
	var asked: Array = []
	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
		return hint if yes < 0 else yes == 1
	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		asked.append(prompt)
		if decline: return null
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


func _to_upkeep(pid: int) -> void:
	var start := g.turn_number
	var guard := 0
	while not g.game_over and guard < 800 and not (g.turn_number > start
			and g.active_player == pid and g.current_step() == Mtg.Step.UPKEEP):
		_advance_once()
		guard += 1
	assert_lt(guard, 800, "never reached the upkeep")

func _priority(pid: int) -> void:
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.priority_player, pid)

func _verse(i: CardInstance) -> int: return int(i.counters.get("verse", 0))

## [param card_name] on [param pid]'s battlefield with [param n] verse counters.
func _charged(pid: int, card_name: String, n: int) -> CardInstance:
	var i := put_battlefield(pid, card_name)
	if n > 0: g.add_counters(i, "verse", n)
	return i

func _pt(i: CardInstance) -> Array: return [i.cur_power, i.cur_toughness]


# ---------------------------------------------------------- the verse upkeep --

func test_each_verse_card_offers_a_counter_at_its_controllers_upkeep() -> void:
	var cards: Array[CardInstance] = []
	for card_name in VERSE: cards.append(put_battlefield(0, card_name))
	_to_upkeep(1)
	resolve_stack()
	for i in cards: assert_eq(_verse(i), 0, "not in the opponent's upkeep")
	_to_upkeep(0)
	resolve_stack()
	for i in cards: assert_eq(_verse(i), 1, i.data.card_name)
	assert_eq(me.asked.size(), VERSE.size())


func test_the_verse_counter_may_be_declined() -> void:
	var song := put_battlefield(0, "Torch Song")
	me.yes = 0
	_to_upkeep(0)
	resolve_stack()
	assert_eq(_verse(song), 0)
	me.yes = 1
	_to_upkeep(0)
	resolve_stack()
	assert_eq(_verse(song), 1)


func test_a_verse_counter_waits_for_a_human_answer() -> void:
	var song := put_battlefield(0, "Torch Song")
	_to_upkeep(0)
	g.agents[0] = HumanAgent.new()
	g.interactive_choices = true
	var guard := 0
	while g.awaiting_choice == null and not g.stack.is_empty() and guard < 10:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_not_null(g.awaiting_choice)
	if g.awaiting_choice == null: return
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.YES_NO)
	assert_ok(g.answer_choice(true))
	g.interactive_choices = false
	g.agents[0] = me
	assert_eq(_verse(song), 1)
	assert_eq(g.unanswered_choices.size(), 0)


# ---------------------------------------------------------- Serra's Liturgy --

func test_serras_liturgy_destroys_up_to_x_artifacts_and_enchantments() -> void:
	var liturgy := _charged(0, "Serra's Liturgy", 2)
	var ring := put_battlefield(1, "Sol Ring")
	var anthem := put_battlefield(1, "Glorious Anthem")
	var pod := put_battlefield(1, "Ornithopter")
	add_mana(0, W)
	assert_refused(g.activate_ability(0, liturgy, 0,
		[TargetRef.card(ring), TargetRef.card(anthem), TargetRef.card(pod)]), "")
	assert_eq(liturgy.zone, Mtg.Zone.BATTLEFIELD, "a refused activation pays nothing")
	assert_ok(g.activate_ability(0, liturgy, 0, [TargetRef.card(ring), TargetRef.card(anthem)]))
	assert_eq(liturgy.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(anthem.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(pod.zone, Mtg.Zone.BATTLEFIELD)


func test_serras_liturgy_refuses_a_creature_and_may_take_fewer() -> void:
	var liturgy := _charged(0, "Serra's Liturgy", 3)
	var bears := put_battlefield(1, "Grizzly Bears")
	var ring := put_battlefield(1, "Sol Ring")
	add_mana(0, W)
	assert_refused(g.activate_ability(0, liturgy, 0, [TargetRef.card(bears)]))
	assert_ok(g.activate_ability(0, liturgy, 0, [TargetRef.card(ring)]))
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)


func test_a_verse_card_with_no_counters_takes_no_target() -> void:
	var liturgy := _charged(0, "Serra's Liturgy", 0)
	var ring := put_battlefield(1, "Sol Ring")
	add_mana(0, W, 2)
	assert_refused(g.activate_ability(0, liturgy, 0, [TargetRef.card(ring)]))
	assert_ok(g.activate_ability(0, liturgy, 0, []))
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------------------------------- Lilting Refrain --

func _bears_on_the_stack() -> CardInstance:
	var bears := give_hand(0, "Grizzly Bears")
	add_mana(0, G, 2)
	assert_ok(g.cast_spell(0, bears))
	return bears

func test_lilting_refrain_counters_unless_x_is_paid() -> void:
	var refrain := _charged(1, "Lilting Refrain", 2)
	var bears := _bears_on_the_stack()
	_priority(1)
	assert_ok(g.activate_ability(1, refrain, 0, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "nothing to pay {2} with")


func test_lilting_refrain_is_paid_off() -> void:
	var refrain := _charged(1, "Lilting Refrain", 2)
	var bears := _bears_on_the_stack()
	add_mana(0, G, 2)
	me.yes = 1
	_priority(1)
	assert_ok(g.activate_ability(1, refrain, 0, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "the caster paid {2}")
	assert_true(me.asked.size() > 0 and String(me.asked[-1]).contains("{2}"))


func test_lilting_refrain_with_no_verse_asks_for_nothing_but_zero() -> void:
	var refrain := _charged(1, "Lilting Refrain", 0)
	var bears := _bears_on_the_stack()
	_priority(1)
	assert_ok(g.activate_ability(1, refrain, 0, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "{0} is always paid")


# -------------------------------------------------------------- Recantation --

func test_recantation_returns_up_to_x_permanents_to_their_owners() -> void:
	var recantation := _charged(0, "Recantation", 2)
	var mine := put_battlefield(0, "Grizzly Bears")
	var theirs := put_battlefield(1, "Sol Ring")
	add_mana(0, U)
	assert_ok(g.activate_ability(0, recantation, 0, [TargetRef.card(mine), TargetRef.card(theirs)]))
	resolve_stack()
	assert_eq(mine.zone, Mtg.Zone.HAND)
	assert_true(g.players[0].hand.has(mine))
	assert_eq(theirs.zone, Mtg.Zone.HAND)
	assert_true(g.players[1].hand.has(theirs))


# --------------------------------------------------------- Discordant Dirge --

func test_discordant_dirge_takes_the_chosen_cards() -> void:
	var dirge := _charged(0, "Discordant Dirge", 2)
	var bolt := give_hand(1, "Lightning Bolt")
	var giant := give_hand(1, "Hill Giant")
	var forest := give_hand(1, "Forest")
	me.prefer = ["Forest", "Lightning Bolt"]
	add_mana(0, B)
	assert_ok(g.activate_ability(0, dirge, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.HAND, "two counters, two cards")


func test_discordant_dirge_may_take_fewer() -> void:
	var dirge := _charged(0, "Discordant Dirge", 3)
	var bolt := give_hand(1, "Lightning Bolt")
	me.decline = true
	add_mana(0, B)
	assert_ok(g.activate_ability(0, dirge, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.HAND, "up to X: none chosen")


func test_discordant_dirge_cannot_target_its_controller() -> void:
	var dirge := _charged(0, "Discordant Dirge", 1)
	add_mana(0, B)
	assert_refused(g.activate_ability(0, dirge, 0, [TargetRef.player(0)]))


# ------------------------------------------------------------- Vile Requiem --

func test_vile_requiem_destroys_nonblack_creatures_without_regeneration() -> void:
	var requiem := _charged(0, "Vile Requiem", 2)
	var troll := put_battlefield(1, "Uthden Troll")
	var bears := put_battlefield(1, "Grizzly Bears")
	var knight := put_battlefield(1, "Black Knight")
	_priority(1)
	add_mana(1, R)
	assert_ok(g.activate_ability(1, troll, 0, []))
	resolve_stack()
	assert_eq(troll.regeneration_shields, 1)
	add_mana(0, B, 2)
	assert_refused(g.activate_ability(0, requiem, 0, [TargetRef.card(knight)]), "")
	assert_ok(g.activate_ability(0, requiem, 0, [TargetRef.card(troll), TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(troll.zone, Mtg.Zone.GRAVEYARD, "they can't be regenerated")
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------- Rumbling Crescendo --

func test_rumbling_crescendo_destroys_up_to_x_lands() -> void:
	var crescendo := _charged(0, "Rumbling Crescendo", 2)
	var a := put_battlefield(1, "Island")
	var b := put_battlefield(1, "Swamp")
	var bears := put_battlefield(1, "Grizzly Bears")
	add_mana(0, R)
	assert_refused(g.activate_ability(0, crescendo, 0, [TargetRef.card(bears)]))
	assert_ok(g.activate_ability(0, crescendo, 0, [TargetRef.card(a), TargetRef.card(b)]))
	resolve_stack()
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)


# --------------------------------------------------------------- Torch Song --

func test_torch_song_deals_its_counters_as_damage_to_any_target() -> void:
	var song := _charged(0, "Torch Song", 3)
	var giant := put_battlefield(1, "Hill Giant")
	add_mana(0, R, 3)
	assert_ok(g.activate_ability(0, song, 0, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	var second := _charged(0, "Torch Song", 4)
	add_mana(0, R, 3)
	assert_ok(g.activate_ability(0, second, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 16)


func test_torch_song_is_a_red_source_after_it_is_gone() -> void:
	put_battlefield(1, "Absolute Law")
	var song := _charged(0, "Torch Song", 2)
	var giant := put_battlefield(1, "Hill Giant")
	add_mana(0, R, 3)
	assert_refused(g.activate_ability(0, song, 0, [TargetRef.card(giant)]), "")


func test_torch_song_line_is_the_counter_blast_the_ai_reads() -> void:
	var song := _charged(0, "Torch Song", 3)
	var effect: EffectBase = song.cur_activated_abilities[0].effects[0]
	assert_eq(MT.counter_damage(song, effect), 3)


# ---------------------------------------------------------- Midsummer Revel --

func test_midsummer_revel_makes_x_beasts() -> void:
	var revel := _charged(0, "Midsummer Revel", 2)
	add_mana(0, G)
	assert_ok(g.activate_ability(0, revel, 0, []))
	resolve_stack()
	var beasts := 0
	for i in g.players[0].battlefield:
		if i.is_token and i.data.card_name == "Beast":
			beasts += 1
			assert_eq(_pt(i), [3, 3])
			assert_eq(i.cur_colors, G)
	assert_eq(beasts, 2)


func test_midsummer_revel_with_no_counters_makes_nothing() -> void:
	var revel := _charged(0, "Midsummer Revel", 0)
	add_mana(0, G)
	var before := g.players[0].battlefield.size()
	assert_ok(g.activate_ability(0, revel, 0, []))
	resolve_stack()
	assert_eq(g.players[0].battlefield.size(), before - 1)


# ---------------------------------------------------------------- War Dance --

func test_war_dance_pumps_by_x_until_end_of_turn() -> void:
	var dance := _charged(0, "War Dance", 3)
	var bears := put_battlefield(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, dance, 0, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(_pt(bears), [5, 5])
	advance_to_next_turn()
	assert_eq(_pt(bears), [2, 2])
