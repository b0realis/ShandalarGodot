extends GameTest
## VOLCANIC ERUPTION IS ONE RESOLUTION, DESTROYS INCLUDED (2026-09-10).
##
## The pass of 2026-09-09 bracketed the BLAST — "…to each creature and each
## player" is a single damage event, and without the bracket a mutually
## lethal Eruption ended as a win instead of the draw CR 104.4b requires.
## The DESTROY half was left a plain loop, and this is the survey that says
## what that was worth.
##
## WHAT THE POOL CAN SEE: nothing. CR 704.3 checks state-based actions when
## a player WOULD receive priority, never in the middle of one resolution,
## so the question is whether anything can make a state-based check happen
## between two destroys. In this engine [method MtgGame.destroy] and
## [method MtgGame._move_to_graveyard] never call
## [method MtgGame.check_state_based_actions] at all: a dies- or
## leave-trigger goes on the STACK (only a mana trigger resolves off-stack,
## CR 605.1b, and the pool's three are all TAPPED_FOR_MANA), the two
## death REPLACEMENTS that would route a permanent through a checking
## helper — `dies_returns_to_hand` and `exile_instead_of_dying` — are set
## by nothing that can name a land (Disintegrate, Runesword, Whippoorwill
## all read "target creature"), and no LAND in the pool carries an
## immediate leave hook (CardData.as_it_leaves has three users: Oubliette,
## Cyclopean Tomb, Titania's Song — an enchantment and two artifacts).
## Dingus Egg, the one card in the pool that watches a land reach a
## graveyard, is an ordinary stacked trigger and cannot act until the
## Eruption has finished resolving.
##
## SO THIS IS A RULE TEST, NOT A BUG TEST. The bracket now wraps the whole
## resolution because CR 704.3 says a resolution is one, and these tests
## pin the property rather than a fixed misbehaviour: nothing is swept
## between the destroys, nothing is swept between the destroys and the
## blast, and the bracket closes even when the Eruption buries nothing.


# ------------------------------------------------- the synthetic apparatus --

## A no-payload Aura for a land: a thing to be ORPHANED. Its whole job is
## to be the card a state-based action would sweep the instant its host is
## destroyed, so that "was it in a graveyard yet?" is a question with an
## answer.
class Vine:
	static func data() -> CardData:
		return CardData.new("Test Witness Vine", "{G}", Mtg.CardType.ENCHANTMENT) \
			.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land",
				Vine.any_land))

	static func any_land(inst: CardInstance) -> bool:
		return inst.is_land()


## THE MICROSCOPE. A trigger's CONDITION is consulted inside
## MtgGame.dispatch_event — that is, in the middle of the very mutation
## that announced the event — while its resolution happens later, off the
## stack. So a condition that writes down the board and then answers "no"
## reads the game at an instant no ordinary card can reach, and puts
## nothing on the stack for the reading.
class Recorder:
	static func data() -> CardData:
		return CardData.new("Test Departure Recorder", "{1}", Mtg.CardType.ENCHANTMENT) \
			.triggered(TriggeredAbility.new(
				Mtg.EventType.LEAVES_BATTLEFIELD, Recorder.never,
				"Whenever a permanent leaves the battlefield, write down the "
				+ "board as the event was announced.",
				Recorder.snapshot))

	static func snapshot(game: MtgGame, source: CardInstance,
			event: GameEvent) -> bool:
		var mountains := 0
		for inst in game.all_battlefield():
			if inst.is_land() and inst.has_subtype("mountain"):
				mountains += 1
		var swept := 0
		for p in game.players:
			for card in p.graveyard:
				if card.data.card_name == "Test Witness Vine":
					swept += 1
		var seen: Array = source.memory.get("seen", [])
		seen.append({
			"left": str(event.data["instance"].data.card_name),
			"mountains": mountains,
			"vines_swept": swept,
		})
		source.memory["seen"] = seen
		return false   # never actually goes on the stack

	static func never(_game: MtgGame, _source: CardInstance,
			_event: GameEvent) -> void:
		pass


func _recorder(pid: int) -> CardInstance:
	return put_synthetic(pid, Recorder.data())


func _seen(recorder: CardInstance) -> Array:
	return recorder.memory.get("seen", [])


## An orphan-in-waiting on [param host].
func _vine_on(host: CardInstance, pid: int) -> CardInstance:
	var vine := put_synthetic(pid, Vine.data())
	g.move_aura(vine, host)
	assert_eq(vine.attached_to, host.id, "the vine took its host")
	return vine


## A REAL Aura from the registry, already on [param host] (setup only —
## the Aura's own casting is somebody else's test).
func _aura_on(card_name: String, host: CardInstance, pid: int) -> CardInstance:
	var aura := put_battlefield(pid, card_name)
	g.move_aura(aura, host)
	assert_eq(aura.attached_to, host.id, "%s took its host" % card_name)
	return aura


func _erupt(pid: int, refs: Array) -> CardInstance:
	var erupt := give_hand(pid, "Volcanic Eruption")
	add_mana(pid, Mtg.ManaColor.U, 3)
	add_mana(pid, Mtg.ManaColor.C, refs.size())
	assert_ok(g.cast_spell(pid, erupt, refs, refs.size()))
	return erupt


# ================================================ the bracket, from inside ==

func test_nothing_is_swept_between_the_destroys() -> void:
	# THE RULE, pinned where it can be read: CR 704.3 forbids a state-based
	# check in the middle of a resolution, so the Vine orphaned by the FIRST
	# Mountain's destruction must still be on the battlefield when the
	# SECOND Mountain's departure is announced.
	var recorder := _recorder(0)
	var m1 := put_battlefield(1, "Mountain")
	var m2 := put_battlefield(1, "Mountain")
	var vine := _vine_on(m1, 1)
	advance_to_step(Mtg.Step.MAIN1)
	_erupt(0, [TargetRef.card(m1), TargetRef.card(m2)])
	resolve_stack()
	var seen := _seen(recorder)
	assert_eq(seen.size(), 3, "two Mountains and the orphaned Vine")
	assert_eq(seen[0]["left"], "Mountain")
	assert_eq(int(seen[0]["mountains"]), 1, "one Mountain still standing")
	assert_eq(int(seen[0]["vines_swept"]), 0, "the Vine is orphaned, not gone")
	assert_eq(seen[1]["left"], "Mountain")
	assert_eq(int(seen[1]["mountains"]), 0, "the second Mountain goes too")
	assert_eq(int(seen[1]["vines_swept"]), 0,
		"AND THE VINE IS STILL ON THE BATTLEFIELD — no state-based action "
		+ "ran between the two destroys (CR 704.3)")
	assert_eq(seen[2]["left"], "Test Witness Vine",
		"the sweep comes last, once the whole resolution has landed")
	assert_eq(vine.zone, Mtg.Zone.GRAVEYARD)


func test_the_orphan_is_still_standing_when_the_blast_lands() -> void:
	# The other seam of the same resolution: the destroys and the damage are
	# ONE bracket, so nothing is swept between them either. The recorder's
	# ledger is empty of the Vine until after every packet has landed, and
	# the Vine's own departure is the last line in it.
	var recorder := _recorder(0)
	var m1 := put_battlefield(1, "Mountain")
	var bear := put_battlefield(1, "Grizzly Bears")     # 2/2, dies to the blast
	var vine := _vine_on(m1, 1)
	advance_to_step(Mtg.Step.MAIN1)
	_erupt(0, [TargetRef.card(m1)])
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD,
		"one Mountain buried is one damage — the 2/2 survives it")
	var seen := _seen(recorder)
	assert_eq(seen.size(), 2, "the Mountain, then the Vine")
	assert_eq(seen[0]["left"], "Mountain")
	assert_eq(seen[1]["left"], "Test Witness Vine")
	assert_eq(int(seen[1]["mountains"]), 0)
	assert_eq(vine.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 19, "one damage to each player")
	assert_eq(g.players[1].life, 19)


func test_the_bracket_closes_even_when_the_eruption_buries_nothing() -> void:
	# A Consecrated Mountain has indestructible (CR 700.4), so an Eruption
	# aimed at it destroys nothing, deals nothing and takes the early exit.
	# The bracket must still close: a deferral left open would freeze every
	# state-based action for the rest of the game, and the Bears below would
	# stand there with lethal damage on it.
	var mountain := put_battlefield(1, "Mountain")
	_aura_on("Consecrate Land", mountain, 1)
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(mountain.cur_indestructible, "the land is consecrated")
	_erupt(0, [TargetRef.card(mountain)])
	resolve_stack()
	assert_eq(mountain.zone, Mtg.Zone.BATTLEFIELD, "nothing was destroyed")
	assert_eq(g.players[0].life, 20, "and nothing was dealt")
	assert_eq(g.players[1].life, 20)
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD,
		"state-based actions still fire — the bracket did not leak")


func test_dingus_egg_still_cracks_once_per_mountain() -> void:
	# The one card in the pool that watches a land reach a graveyard, and
	# the reason the loop's order was worth checking at all. Its trigger is
	# an ordinary stacked one: both copies go on the stack during the
	# resolution and pay out afterwards, two damage a Mountain, to the
	# LANDS' controller — which the bracket does not change.
	put_battlefield(0, "Dingus Egg")
	var m1 := put_battlefield(1, "Mountain")
	var m2 := put_battlefield(1, "Mountain")
	advance_to_step(Mtg.Step.MAIN1)
	_erupt(0, [TargetRef.card(m1), TargetRef.card(m2)])
	resolve_stack()
	assert_eq(m1.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(m2.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 18, "the blast: two Mountains buried")
	assert_eq(g.players[1].life, 14,
		"the blast plus two Dingus Egg cracks of 2 — one per Mountain")


func test_the_blast_still_ends_a_mutual_kill_as_a_draw() -> void:
	# The 2026-09-09 property, re-pinned from the other side of the moved
	# bracket: begin_simultaneous now opens before the destroys, and only
	# the outermost end_simultaneous sweeps, so the two lethal packets are
	# still one event (CR 704.3) and still a draw (CR 104.4b).
	g.players[0].life = 3
	g.players[1].life = 3
	var refs: Array = []
	for _i in 4:
		refs.append(TargetRef.card(put_battlefield(1, "Mountain")))
	advance_to_step(Mtg.Step.MAIN1)
	_erupt(0, refs)
	resolve_stack()
	assert_true(g.game_over)
	assert_true(g.is_draw, "and it is a draw, not a win")
	assert_eq(g.winner, -1, "nobody won")
