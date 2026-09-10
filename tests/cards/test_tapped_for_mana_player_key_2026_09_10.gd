extends GameTest
## TAPPED_FOR_MANA CARRIES BOTH MEANINGS OF "THAT PLAYER" (2026-09-10).
##
## The BECAME_TAPPED pass of 2026-09-09 unified `controller` across its five
## dispatch sites to the TAPPED PERMANENT'S controller, and left
## TAPPED_FOR_MANA alone on purpose: its watchers are worded two different
## ways. Manabarbs deals its damage "to THAT PLAYER" and Mana Flare has
## "THAT PLAYER adds", both meaning the player who tapped the land; Gauntlet
## of Might and Wild Growth say "ITS CONTROLLER", meaning the land's.
##
## At the one dispatch site the two values are provably the same —
## MtgGame.tap_for_mana refuses a permanent its activator does not control,
## which is pinned below — so the divergence was latent, not live. It is
## also one card away: the day something taps another player's land for
## mana, an event with one key would have to lie to two of its four
## readers.
##
## So the event now carries BOTH, the way ABILITY_ACTIVATED already does:
## `controller` is the land's controller, as on every other event in
## Mtg.EventType that carries the key, and `player` is the hand that tapped
## it. Every watcher reads the meaning its own oracle text names. Nothing
## changed for any of them today — the two values are equal at the site —
## and the tests below pull them apart by hand so that the day they are not
## equal is a day the pool is already right about.


# ------------------------------------------------- the synthetic apparatus --

## Writes down BOTH keys of every TAPPED_FOR_MANA event, in the order they
## were dispatched. A permanent of its own, so the trigger index reaches it
## exactly as it reaches a card.
class Ledger:
	static func data() -> CardData:
		return CardData.new("Test Mana Tap Ledger", "{1}", Mtg.CardType.ENCHANTMENT) \
			.triggered(TriggeredAbility.new(
				Mtg.EventType.TAPPED_FOR_MANA, Ledger.record,
				"Whenever a land is tapped for mana, write down both players "
				+ "the event named."))

	static func record(_game: MtgGame, source: CardInstance,
			event: GameEvent) -> void:
		var seen: Array = source.memory.get("seen", [])
		seen.append({
			"controller": int(event.data.get("controller", -1)),
			"player": int(event.data.get("player", -1)),
		})
		source.memory["seen"] = seen


func _ledger(pid: int) -> CardInstance:
	return put_synthetic(pid, Ledger.data())


func _seen(ledger: CardInstance) -> Array:
	return ledger.memory.get("seen", [])


## The event the site cannot produce yet: [param land_controller]'s land,
## tapped by [param tapper]. Hand-built exactly as MtgGame.tap_for_mana
## builds it, with the two seats pulled apart.
func _tap_event(land: CardInstance, land_controller: int,
		tapper: int) -> GameEvent:
	return GameEvent.new(Mtg.EventType.TAPPED_FOR_MANA, {
		"instance": land,
		"controller": land_controller,
		"player": tapper,
		"color": Mtg.ManaColor.R,
		"colors": [Mtg.ManaColor.R],
	})


## Offer [param event] to [param source]'s own TAPPED_FOR_MANA trigger the
## way MtgGame.dispatch_event does: the condition first, then the
## resolution. Returns false when the card's condition declined it.
func _offer(source: CardInstance, event: GameEvent) -> bool:
	for trig in source.cur_triggered_abilities:
		if trig.event_type != Mtg.EventType.TAPPED_FOR_MANA:
			continue
		if not trig.matches(g, source, event):
			return false
		trig.on_resolve.call(g, source, event)
		return true
	assert_true(false, "%s has no TAPPED_FOR_MANA trigger" % source.data.card_name)
	return false


# ====================================== ONE: WHAT THE LIVE SITE ANNOUNCES ==

func test_the_event_names_the_land_and_the_hand_that_tapped_it() -> void:
	var ledger := _ledger(0)
	var theirs := put_battlefield(1, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	assert_ok(g.tap_for_mana(1, theirs))
	resolve_stack()
	assert_eq(_seen(ledger).size(), 1, "one tap, one line")
	var line: Dictionary = _seen(ledger)[0]
	assert_eq(int(line["controller"]), 1, "`controller` is the land's controller")
	assert_eq(int(line["player"]), 1, "`player` is the hand that tapped it")


func test_nobody_can_tap_a_land_they_do_not_control_for_mana() -> void:
	# WHY the two values are equal at this site, and the whole reason the
	# divergence is latent rather than live: the activator of a mana ability
	# is always the permanent's controller. The day a card breaks that, the
	# event is already carrying both answers.
	var theirs := put_battlefield(1, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.tap_for_mana(0, theirs), "you don't control that permanent")


func test_both_keys_are_on_the_event_for_every_land_anyone_taps() -> void:
	# Two taps, one seat each — and the ledger reads in the STACK's order
	# rather than the clock's: the first tap's trigger goes on first and so
	# resolves last (CR 603.3b), which is why seat 1's Island is line one.
	var ledger := _ledger(1)
	var ours := put_battlefield(0, "Mountain")
	var theirs := put_battlefield(1, "Island")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.tap_for_mana(0, ours))
	assert_ok(g.pass_priority(0))
	assert_ok(g.tap_for_mana(1, theirs))
	resolve_stack()
	var seen := _seen(ledger)
	assert_eq(seen.size(), 2)
	assert_eq(int(seen[0]["controller"]), 1, "their Island, their seat")
	assert_eq(int(seen[0]["player"]), 1)
	assert_eq(int(seen[1]["controller"]), 0, "our Mountain, ours")
	assert_eq(int(seen[1]["player"]), 0)


# ============================ TWO: WHICH MEANING EACH WATCHER READS ==
#
# Four cards, two wordings. The events below are hand-built with the seats
# pulled apart — seat 1's Mountain, seat 0's tap — which is the shape the
# site cannot produce yet and the shape the keys exist for.

func test_manabarbs_burns_the_hand_that_tapped() -> void:
	# "Whenever a player taps a land for mana, Manabarbs deals 1 damage to
	# THAT PLAYER" — the tapper, not the landlord.
	var barbs := put_battlefield(0, "Manabarbs")
	var theirs := put_battlefield(1, "Mountain")
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(_offer(barbs, _tap_event(theirs, 1, 0)))
	assert_eq(g.players[0].life, 19, "the hand that tapped takes the point")
	assert_eq(g.players[1].life, 20, "the land's controller does not")


func test_mana_flare_fills_the_tapping_players_pool() -> void:
	# "…THAT PLAYER adds one mana of any type that land produced."
	var flare := put_battlefield(0, "Mana Flare")
	var theirs := put_battlefield(1, "Mountain")
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(_offer(flare, _tap_event(theirs, 1, 0)))
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.R), 1,
		"the bonus goes to the hand that tapped")
	assert_eq(g.players[1].mana_pool.total(), 0)


func test_gauntlet_of_might_pays_the_lands_controller() -> void:
	# "Whenever a Mountain is tapped for mana, ITS CONTROLLER adds an
	# additional {R}" — the other wording, and the control for the two
	# above: this card reads `controller` and always did.
	var gauntlet := put_battlefield(0, "Gauntlet of Might")
	var theirs := put_battlefield(1, "Mountain")
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(_offer(gauntlet, _tap_event(theirs, 1, 0)))
	assert_eq(g.players[1].mana_pool.total_of(Mtg.ManaColor.R), 1,
		"the Mountain's controller, whoever tapped it")
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_wild_growth_pays_the_lands_controller() -> void:
	# "Whenever enchanted land is tapped for mana, ITS CONTROLLER adds an
	# additional {G}." The Aura is seat 0's, the land is seat 1's, and the
	# green is seat 1's.
	var theirs := put_battlefield(1, "Mountain")
	var growth := put_battlefield(0, "Wild Growth")
	g.move_aura(growth, theirs)
	assert_eq(growth.attached_to, theirs.id, "the Aura took its host")
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(_offer(growth, _tap_event(theirs, 1, 0)))
	assert_eq(g.players[1].mana_pool.total_of(Mtg.ManaColor.G), 1,
		"the enchanted land's controller, whoever tapped it")
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_a_watcher_of_another_players_land_is_declined_by_its_own_condition() -> void:
	# The conditions are untouched by any of this: Gauntlet still asks
	# whether the land is a Mountain, Wild Growth still asks whether it is
	# its own host.
	var gauntlet := put_battlefield(0, "Gauntlet of Might")
	var forest := put_battlefield(1, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_false(_offer(gauntlet, _tap_event(forest, 1, 0)),
		"a Forest is not a Mountain")
	var growth := put_battlefield(0, "Wild Growth")
	var mountain := put_battlefield(1, "Mountain")
	g.move_aura(growth, mountain)
	assert_false(_offer(growth, _tap_event(forest, 1, 0)),
		"Wild Growth only hears its own host")


# ================= THREE: NOTHING CHANGED FOR ANY CARD IN PLAY TODAY ==

func test_all_four_watchers_still_read_the_same_seat_at_the_live_site() -> void:
	# The whole table at once, through the real action. Seat 1 taps their
	# own enchanted Mountain: the two "that player" cards and the two "its
	# controller" cards all land on seat 1, because at this site the two
	# meanings are one seat. That is the promise the change had to keep.
	put_battlefield(0, "Manabarbs")
	put_battlefield(0, "Mana Flare")
	put_battlefield(0, "Gauntlet of Might")
	var mountain := put_battlefield(1, "Mountain")
	var growth := put_battlefield(0, "Wild Growth")   # seat 0's Aura, seat 1's land
	g.move_aura(growth, mountain)
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	assert_ok(g.tap_for_mana(1, mountain))
	assert_eq(g.players[1].mana_pool.total_of(Mtg.ManaColor.R), 3,
		"the Mountain's own {R}, Gauntlet of Might's and Mana Flare's")
	assert_eq(g.players[1].mana_pool.total_of(Mtg.ManaColor.G), 1,
		"and Wild Growth's")
	assert_eq(g.players[0].mana_pool.total(), 0, "none of it is seat 0's")
	resolve_stack()
	assert_eq(g.players[1].life, 19, "Manabarbs stings the hand that tapped")
	assert_eq(g.players[0].life, 20)
