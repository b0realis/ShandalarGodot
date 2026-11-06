extends GameTest
## Pack 10 E10 — ARRIVE TOGETHER: MtgGame.put_onto_battlefield_together, the
## arrival twin of depart_together. "Put all those cards onto the
## battlefield" (Living Death, Replenish, Show and Tell, Exhume) is ONE
## moment: every choice is made (APNAP, CR 101.4) while none of the batch
## is on the battlefield, then they all arrive, then every ENTERS event is
## announced — so each "whenever another creature enters" sees all the
## others (CR 603.6a, 603.10) and an Aura can only enchant what was already
## there (CR 303.4f-g).


## Every answer it gives, with its seat — the order the questions came in.
class Recorder extends DecisionAgent:
	var log: Array
	var seat := 0
	func _init(shared: Array, p_seat: int) -> void:
		log = shared
		seat = p_seat
	func answer_card(_g: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		log.append([seat, prompt])
		return candidates[0] if not candidates.is_empty() else null


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)


## "Whenever another creature enters, you gain 1 life" — a synthetic Soul
## Warden, so the counting does not depend on a pack.
static func _watcher() -> CardData:
	var c := CardData.new("Test Warden", "{W}", Mtg.CardType.CREATURE).pt(1, 1)
	return c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD,
		func(g: MtgGame, s: CardInstance, _e: GameEvent) -> void: g.adjust_life(s.controller_id, 1),
		"Whenever another creature enters, you gain 1 life.",
		func(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
			var other: CardInstance = e.data.get("instance")
			return other != s and other != null and other.is_creature()))


func _in_graveyard(pid: int, card_name: String) -> CardInstance:
	var card := give_hand(pid, card_name)
	g.discard_cards(pid, [card])
	return card


func _synthetic_in_graveyard(pid: int, data: CardData) -> CardInstance:
	var card := give_synthetic(pid, data)
	g.discard_cards(pid, [card])
	return card


# ===================================================== 1. one moment --

func test_a_watcher_in_the_batch_sees_every_other_arrival() -> void:
	var bears := _in_graveyard(0, "Grizzly Bears")
	var giant := _in_graveyard(0, "Hill Giant")
	var warden := _synthetic_in_graveyard(0, _watcher())   # LAST in the batch
	var entered := g.put_onto_battlefield_together([
		{"instance": bears}, {"instance": giant}, {"instance": warden}])
	resolve_stack()
	assert_eq(entered.size(), 3)
	for card in [bears, giant, warden]:
		assert_eq(card.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].life, 22, "the Warden saw both others, though it came last")


func test_one_after_another_the_same_watcher_misses_the_earlier_ones() -> void:
	# The control: the sequential arrival the helper replaces.
	var bears := _in_graveyard(0, "Grizzly Bears")
	var warden := _synthetic_in_graveyard(0, _watcher())
	g.reanimate(bears, 0)
	g.reanimate(warden, 0)
	resolve_stack()
	assert_eq(g.players[0].life, 20, "it arrived after the Bears and saw nothing")


func test_cards_come_from_every_zone_and_leave_it() -> void:
	var from_grave := _in_graveyard(0, "Grizzly Bears")
	var from_hand := give_hand(0, "Hill Giant")
	var from_exile := give_hand(1, "Craw Wurm")
	g.discard_cards(1, [from_exile])
	g.exile_from_graveyard(from_exile)
	assert_eq(from_exile.zone, Mtg.Zone.EXILE)
	var library := g.players[0].library
	var from_library: CardInstance = library.back()
	g.put_onto_battlefield_together([{"instance": from_grave}, {"instance": from_hand},
		{"instance": from_exile}, {"instance": from_library, "tapped": true}])
	for card in [from_grave, from_hand, from_exile, from_library]:
		assert_eq(card.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(g.players[0].graveyard.has(from_grave))
	assert_false(g.players[0].hand.has(from_hand))
	assert_false(g.players[1].exile.has(from_exile))
	assert_false(library.has(from_library))
	assert_eq(from_exile.controller_id, 1, "its owner by default")
	assert_true(from_library.tapped, "\"tapped\": true")
	assert_true(from_grave.summoning_sick)


func test_controller_and_counters_are_the_effects() -> void:
	var theirs := _in_graveyard(1, "Grizzly Bears")
	g.put_onto_battlefield_together([{"instance": theirs, "controller": 0,
		"counters": {"+1/+1": 2}}])
	assert_eq(theirs.controller_id, 0)
	assert_eq(int(theirs.counters.get("+1/+1", 0)), 2)
	assert_eq(theirs.cur_power, 4)
	assert_true(g.came_under_control_since_last_upkeep(theirs), "echo's clock is started too")


# ===================================== 2. the choices, before anything --

func test_choices_are_asked_active_player_first() -> void:
	var asked: Array = []
	g.set_agent(0, Recorder.new(asked, 0))
	g.set_agent(1, Recorder.new(asked, 1))
	put_battlefield(1, "Grizzly Bears")   # something to copy
	var their_clone := _in_graveyard(1, "Clone")
	var my_clone := _in_graveyard(0, "Clone")
	# The opponent's card is listed first; the active player still chooses first.
	g.put_onto_battlefield_together([{"instance": their_clone}, {"instance": my_clone}])
	assert_eq(asked.size(), 2)
	assert_eq(int(asked[0][0]), 0, "APNAP: the active player's choice first (CR 101.4)")
	assert_eq(int(asked[1][0]), 1)


func test_a_clone_cannot_copy_a_card_entering_with_it() -> void:
	put_battlefield(1, "Grizzly Bears")
	var wurm := _in_graveyard(0, "Craw Wurm")
	var clone := _in_graveyard(0, "Clone")
	g.put_onto_battlefield_together([{"instance": wurm}, {"instance": clone}])
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(clone.data.card_name, "Grizzly Bears", "only what was already there")


func test_a_kismet_in_the_batch_does_not_tap_the_others() -> void:
	var kismet := _in_graveyard(1, "Kismet")
	var bears := _in_graveyard(0, "Grizzly Bears")
	g.put_onto_battlefield_together([{"instance": kismet}, {"instance": bears}])
	assert_eq(kismet.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(bears.tapped, "Kismet was not on the battlefield yet")


func test_a_kismet_already_there_still_taps_an_arrival() -> void:
	put_battlefield(1, "Kismet")
	var bears := _in_graveyard(0, "Grizzly Bears")
	g.put_onto_battlefield_together([{"instance": bears}])
	assert_true(bears.tapped)


func test_a_refused_arrival_stays_where_it_was_and_the_rest_enter() -> void:
	put_battlefield(1, "Worms of the Earth")   # lands can't enter
	var land := give_hand(0, "Forest")
	var bears := _in_graveyard(0, "Grizzly Bears")
	var entered := g.put_onto_battlefield_together([{"instance": land}, {"instance": bears}])
	assert_eq(entered, [bears] as Array[CardInstance])
	assert_eq(land.zone, Mtg.Zone.HAND)
	assert_true(g.players[0].hand.has(land), "back in the hand it came from")


# =========================================================== 3. Auras --

func test_an_aura_enchants_only_what_was_already_there() -> void:
	var old := put_battlefield(0, "Hill Giant")
	var strength := _in_graveyard(0, "Holy Strength")
	var bears := _in_graveyard(0, "Grizzly Bears")
	g.put_onto_battlefield_together([{"instance": bears}, {"instance": strength}])
	assert_eq(strength.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(strength.attached_to, old.id, "not the Bears entering with it (CR 303.4f)")
	assert_eq(old.cur_power, 4)


func test_an_aura_with_nothing_to_enchant_stays_in_its_zone() -> void:
	var strength := _in_graveyard(0, "Holy Strength")
	var bears := _in_graveyard(0, "Grizzly Bears")
	var entered := g.put_onto_battlefield_together([{"instance": bears}, {"instance": strength}])
	assert_eq(entered, [bears] as Array[CardInstance])
	assert_eq(strength.zone, Mtg.Zone.GRAVEYARD, "CR 303.4g")
	assert_true(g.players[0].graveyard.has(strength))


func test_an_effect_may_name_the_aura_host() -> void:
	var a := put_battlefield(0, "Hill Giant")
	var b := put_battlefield(0, "Grizzly Bears")
	var strength := _in_graveyard(0, "Holy Strength")
	g.put_onto_battlefield_together([{"instance": strength, "host": b}])
	assert_eq(strength.attached_to, b.id)
	assert_eq(a.attachments.size(), 0)


func test_animate_dead_in_a_batch_raises_its_card_right_after() -> void:
	var dead := _in_graveyard(0, "Craw Wurm")
	var animate := _in_graveyard(0, "Animate Dead")
	var bears := _in_graveyard(0, "Grizzly Bears")
	g.put_onto_battlefield_together([{"instance": animate}, {"instance": bears}])
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(animate.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(dead.zone, Mtg.Zone.BATTLEFIELD, "the Wurm it chose was raised")
	assert_eq(animate.attached_to, dead.id)


# ================================== 4. a human asked inside a resolution --

class Replenish extends EffectBase:
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var entries: Array = []
		for card in g.players[pid].graveyard.duplicate():
			if (card as CardInstance).data.is_type(Mtg.CardType.ENCHANTMENT):
				entries.append({"instance": card})
		g.put_onto_battlefield_together(entries)


func test_a_human_seat_is_held_on_the_aura_host_question() -> void:
	var human := HumanAgent.new()
	g.agents[0] = human
	g.interactive_choices = true
	var giant := put_battlefield(0, "Hill Giant")
	var bears := put_battlefield(1, "Grizzly Bears")
	var strength := _in_graveyard(0, "Holy Strength")
	var spell := CardData.new("Test Replenish", "{W}", Mtg.CardType.SORCERY).spell(Replenish.new())
	var card := give_synthetic(0, spell)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, card))
	var guard := 0
	while g.awaiting_choice == null and not g.stack.is_empty() and guard < 10:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_not_null(g.awaiting_choice, "held on what the Aura enchants")
	if g.awaiting_choice == null: return
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.CARD)
	assert_eq(g.awaiting_choice.candidates.size(), 2)
	assert_eq(strength.zone, Mtg.Zone.GRAVEYARD, "nothing has happened yet")
	assert_ok(g.answer_choice(bears.id))
	resolve_stack()
	assert_eq(strength.attached_to, bears.id, "the player's choice, the opponent's creature")
	assert_eq(giant.attachments.size(), 0)


# ============================================= 5. the journal, and Living Death --

func test_the_search_journal_takes_a_batch_back() -> void:
	var bears := _in_graveyard(0, "Grizzly Bears")
	var giant := give_hand(0, "Hill Giant")
	var m := g.make_mark()
	g.put_onto_battlefield_together([{"instance": bears}, {"instance": giant}])
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	g.unmake_to(m)
	g.end_search()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.players[0].graveyard.has(bears))
	assert_eq(giant.zone, Mtg.Zone.HAND)
	assert_true(g.players[0].hand.has(giant))
	assert_false(g.players[0].battlefield.has(bears))


func test_living_death_returns_its_creatures_together() -> void:
	CardPacks.set_enabled("pack-9", true)
	var bears := put_battlefield(0, "Grizzly Bears")
	g.destroy(bears)
	var warden := put_battlefield(0, "Soul Warden")
	g.destroy(warden)
	var giant := put_battlefield(1, "Hill Giant")
	g.destroy(giant)
	var death := give_hand(0, "Living Death")
	add_mana(0, Mtg.ManaColor.B, 5)
	var life := g.players[0].life
	assert_ok(g.cast_spell(0, death))
	resolve_stack()
	for card in [bears, warden, giant]:
		assert_eq(card.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(giant.controller_id, 1)
	assert_eq(g.players[0].life, life + 2,
		"the Warden saw the Bears AND the opponent's Giant arrive with it")
