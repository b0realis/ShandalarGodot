extends GameTest
## A SWEEPER IS ONE RESOLUTION (2026-09-10). CR 704.3.
##
## The Volcanic Eruption pass of 2026-09-10 bracketed a destroy LOOP and
## found, by survey, that a loop over LANDS is unobservable: nothing in
## MtgGame.destroy or MtgGame._move_to_graveyard checks state-based
## actions, and no land in the pool can route its own death through a
## helper that does. It said, and did not follow up, that the same loop is
## OBSERVABLE when the victims are CREATURES. This is the follow-up.
##
## THE SEAM. Two death REPLACEMENTS re-route a dying permanent into a
## helper that ends with check_state_based_actions():
##   * CardData.dies_returns_to_hand -> MtgGame.return_to_hand
##     (Firestorm Phoenix, the pool's only user);
##   * CardInstance.exile_instead_of_dying -> MtgGame.exile_permanent
##     (Disintegrate, Runesword, Whippoorwill).
## A mass BOUNCE or mass EXILE needs no replacement at all — Hurkyl's
## Recall and Martyr's Cry call those two helpers directly, once per
## victim, so every iteration of their loop used to check state-based
## actions in the middle of one resolution.
##
## AND THE OUTCOME DIFFERS, not just the ordering. A creature held above
## zero toughness by something the same sweeper is destroying dies to
## CR 704.5f the instant a mid-loop check runs — and 704.5f is not
## destruction, so a regeneration shield cannot replace it and is not even
## spent. Destroyed by the sweeper on a settled board it would have
## regenerated and lived. The first test below is that board, and it FAILED
## before this pass and PASSES after it: the Skeleton read GRAVEYARD where
## it should read BATTLEFIELD.
##
## WHAT IS BRACKETED, and where each shape is pinned here:
##   engine/effects/destroy_all_effect.gd — Armageddon, Flashfires,
##     Nevinyrral's Disk, Tranquility, Tsunami, Wrath of God, Shatterstorm,
##     Tivadar's Crusade, Acid Rain, Cleanse, and the Whimsy table's Disk;
##   the mass SACRIFICES: City in a Bottle, Golgothian Sylex;
##   the mass BOUNCE: Hurkyl's Recall;
##   the mass EXILES: Martyr's Cry, Hazezon Tamar;
##   the multi-victim DESTROYS: Hellfire, Abu Ja'far, War Barge,
##     Glyph of Doom, Glyph of Reincarnation.


# ------------------------------------------------- the synthetic apparatus --

## THE MICROSCOPE, the same one test_erupt_bracket_2026_09_10.gd uses. A
## trigger's CONDITION is consulted inside MtgGame.dispatch_event — in the
## middle of the very mutation that announced the event — while its
## resolution happens later. So a condition that writes the board down and
## then answers "no" reads the game at an instant no ordinary card can
## reach, and puts nothing on the stack for the reading.
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
		var creatures := 0
		var standing: Array = []
		for inst in game.all_battlefield():
			if inst.is_creature():
				creatures += 1
			standing.append(inst.data.card_name)
		var seen: Array = source.memory.get("seen", [])
		seen.append({
			"left": str(event.data["instance"].data.card_name),
			"creatures": creatures,
			"standing": standing,
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


## A REAL Aura from the registry, already on [param host] (setup only —
## the Aura's own casting is somebody else's test).
func _aura_on(card_name: String, host: CardInstance, pid: int) -> CardInstance:
	var aura := put_battlefield(pid, card_name)
	g.move_aura(aura, host)
	assert_eq(aura.attached_to, host.id, "%s took its host" % card_name)
	return aura


## Fire a Nevinyrral's Disk that was placed by [method put_battlefield]
## (it enters tapped, CR-correctly, and setup does not run an untap step).
func _fire_the_disk(pid: int, disk: CardInstance) -> void:
	g.untap_permanent(disk)
	add_mana(pid, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(pid, disk, 0, []))
	resolve_stack()


func _cast(pid: int, card_name: String, colors: Array,
		targets: Array = []) -> CardInstance:
	var card := give_hand(pid, card_name)
	for c in colors:
		add_mana(pid, int(c))
	assert_ok(g.cast_spell(pid, card, targets))
	return card


# ================================================== the outcome, not the order

func test_the_disk_no_longer_starves_a_creature_it_is_about_to_destroy() -> void:
	# THE BOARD THE NOTE DESCRIBES, in one sweeper's blast:
	#   Castle          — untapped creatures you control get +0/+2
	#   Firestorm Phoenix — dies-to-hand, and return_to_hand checks SBA
	#   Drudge Skeletons — 1/1, {B}: regenerate; wearing a Weakness (-2/-1)
	# Live, the Skeleton is -1/2. Take the Castle away and it is -1/0.
	#
	# Nevinyrral's Disk destroys all three in ONE resolution. Unbracketed,
	# the loop went Castle (gone), Phoenix (bounced -> SBA), and that
	# state-based check found the Skeleton at zero toughness and put it in
	# the graveyard under CR 704.5f — which is NOT destruction, so its
	# regeneration shield could not replace it and was still sitting there
	# unspent. Bracketed, the whole blast lands first: the Weakness goes
	# with the Castle, the Skeleton is destroyed as a 1/1, and the shield
	# does what a shield does.
	var disk := put_battlefield(0, "Nevinyrral's Disk")
	put_battlefield(0, "Castle")
	var phoenix := put_battlefield(0, "Firestorm Phoenix")
	var skeleton := put_battlefield(0, "Drudge Skeletons")
	var weakness := _aura_on("Weakness", skeleton, 0)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(skeleton.cur_toughness, 2,
		"1 base, -1 from the Weakness, +2 from the Castle")
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, skeleton, 0, []))   # {B}: Regenerate
	resolve_stack()
	assert_eq(skeleton.regeneration_shields, 1, "the shield is up")

	_fire_the_disk(0, disk)

	assert_eq(skeleton.zone, Mtg.Zone.BATTLEFIELD,
		"THE OUTCOME: the Skeleton regenerates out of the blast. Unbracketed "
		+ "it died to zero toughness mid-loop (CR 704.5f) with the shield "
		+ "unspent, because the Castle had already gone and the Phoenix's "
		+ "bounce checked state-based actions in the middle of one resolution")
	assert_eq(skeleton.regeneration_shields, 0, "and the shield paid for it")
	assert_true(skeleton.tapped, "regeneration taps (CR 701.15a)")
	assert_eq(skeleton.cur_toughness, 1, "a plain 1/1 again — both auras gone")
	assert_eq(weakness.zone, Mtg.Zone.GRAVEYARD, "the Weakness went with it")
	assert_eq(phoenix.zone, Mtg.Zone.HAND, "the Phoenix went home, as printed")
	assert_eq(disk.zone, Mtg.Zone.GRAVEYARD, "the Disk dies in its own blast")


func test_the_shield_is_refused_when_zero_toughness_is_the_real_cause() -> void:
	# THE CONTROL PAIR, and the reason the test above is about the OUTCOME
	# rather than the order. A regeneration shield never beats zero
	# toughness: CR 704.5f puts the creature in the graveyard as a rule,
	# not as a destruction, so nothing is replaced and nothing is spent.
	# What the bracket decides is WHICH of the two rules gets to kill the
	# creature — and only one of them the shield can answer.
	var skeleton := put_battlefield(0, "Drudge Skeletons")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, skeleton, 0, []))
	resolve_stack()
	assert_eq(skeleton.regeneration_shields, 1, "the shield is up")
	_cast(0, "Weakness", [Mtg.ManaColor.B], [TargetRef.card(skeleton)])
	resolve_stack()
	assert_eq(skeleton.zone, Mtg.Zone.GRAVEYARD,
		"1 base toughness, -1 from the Weakness — CR 704.5f")
	assert_false(g.log_lines.has("Drudge Skeletons regenerates"),
		"AND THE SHIELD WAS NEVER OFFERED: 704.5f is not destruction, so "
		+ "nothing asked the shield to replace anything. (Its counter reads "
		+ "zero afterwards only because CardInstance.clear_battlefield_state "
		+ "wipes it on the way out — the log is the witness, not the count.)")


# ============================================ the loop, seen from the inside

func test_nothing_is_swept_between_a_wraths_destroys() -> void:
	# THE RULE, pinned where it can be read. Wrath of God buries three
	# creatures in one resolution; the Recorder's condition runs inside
	# each departure's dispatch_event, and each reading must find the
	# creatures that have not been reached yet still standing.
	var recorder := _recorder(0)
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	put_battlefield(1, "Scryb Sprites")
	advance_to_step(Mtg.Step.MAIN1)
	_cast(0, "Wrath of God", [Mtg.ManaColor.C, Mtg.ManaColor.C,
		Mtg.ManaColor.W, Mtg.ManaColor.W])
	resolve_stack()
	var seen := _seen(recorder)
	assert_eq(seen.size(), 3, "three creatures left the battlefield")
	assert_eq(int(seen[0]["creatures"]), 2, "two still standing behind it")
	assert_eq(int(seen[1]["creatures"]), 1, "one still standing behind it")
	assert_eq(int(seen[2]["creatures"]), 0, "and the last one is the last")


func test_the_phoenix_bounce_no_longer_sweeps_an_orphan_mid_loop() -> void:
	# The Phoenix is the pool's only dies_returns_to_hand, and
	# MtgGame.return_to_hand ends with check_state_based_actions(). Put it
	# in the middle of a Wrath and the orphaned Aura behind it must still
	# be on the battlefield when the LAST creature's departure is
	# announced: one resolution, one sweep, CR 704.3.
	var recorder := _recorder(0)
	var bear := put_battlefield(1, "Grizzly Bears")
	var flight := _aura_on("Holy Strength", bear, 1)
	put_battlefield(1, "Firestorm Phoenix")
	put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	_cast(0, "Wrath of God", [Mtg.ManaColor.C, Mtg.ManaColor.C,
		Mtg.ManaColor.W, Mtg.ManaColor.W])
	resolve_stack()
	var seen := _seen(recorder)
	assert_eq(seen[0]["left"], "Grizzly Bears")
	assert_eq(seen[1]["left"], "Firestorm Phoenix",
		"the Phoenix goes home instead of dying")
	assert_eq(seen[2]["left"], "Hill Giant")
	assert_true(Array(seen[2]["standing"]).has("Holy Strength"),
		"AND THE ORPHANED AURA IS STILL ON THE BATTLEFIELD when the last "
		+ "victim leaves — the Phoenix's bounce did not get to sweep it "
		+ "mid-resolution (CR 704.3)")
	assert_eq(seen[3]["left"], "Holy Strength", "the sweep comes last")
	assert_eq(flight.zone, Mtg.Zone.GRAVEYARD)


# ============================================== the bracket closes, always

func test_the_bracket_closes_when_a_sweeper_finds_nothing() -> void:
	# The empty-board path: Tranquility with no enchantment on the table
	# runs the loop zero times. A deferral left open there would freeze
	# every state-based action for the rest of the game.
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	_cast(0, "Tranquility", [Mtg.ManaColor.C, Mtg.ManaColor.C, Mtg.ManaColor.G])
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "no enchantments, nothing done")
	_assert_state_based_actions_still_fire(bear)


func test_the_bracket_closes_when_every_victim_is_indestructible() -> void:
	# The other early exit: MtgGame.destroy returns immediately on an
	# indestructible permanent (CR 700.4), so the loop runs and buries
	# nothing. The bracket must still close.
	var mountain := put_battlefield(1, "Mountain")
	_aura_on("Consecrate Land", mountain, 1)
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(mountain.cur_indestructible, "the land is consecrated")
	_cast(0, "Armageddon", [Mtg.ManaColor.C, Mtg.ManaColor.C, Mtg.ManaColor.C,
		Mtg.ManaColor.W])
	resolve_stack()
	assert_eq(mountain.zone, Mtg.Zone.BATTLEFIELD, "nothing was destroyed")
	_assert_state_based_actions_still_fire(bear)


func test_the_bracket_closes_when_the_sweeper_kills_its_own_caster() -> void:
	# The nastiest exit of all: a sweeper that ends the game. Hellfire
	# destroys every nonblack creature and then burns its caster for the
	# count plus three, and the game is over before the effect returns.
	# The close must still happen on the way out.
	g.players[0].life = 4
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	_cast(0, "Hellfire", [Mtg.ManaColor.C, Mtg.ManaColor.C, Mtg.ManaColor.B,
		Mtg.ManaColor.B, Mtg.ManaColor.B])
	resolve_stack()
	assert_true(g.game_over, "one dead creature plus three is four")
	assert_eq(g.winner, 1)
	_assert_bracket_closed()


func _assert_state_based_actions_still_fire(bear: CardInstance) -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD,
		"state-based actions still fire — the bracket did not leak")
	_assert_bracket_closed()


## The bracket's own books, read directly. Everywhere the game carries on
## afterwards there is an observable proof as well (the Bolt above), but a
## sweeper that ENDS the game leaves no "afterwards" to observe from:
## check_state_based_actions returns on game_over whatever the counter
## says. So the counter is the only witness for that exit, and it is the
## one thing this pass must not get wrong — a deferral left open freezes
## state-based actions for the rest of the game.
func _assert_bracket_closed() -> void:
	assert_eq(g._defer_depth, 0, "no simultaneous bracket is still open")
	assert_false(g._defer_state_based_actions,
		"and state-based actions are not deferred")


# ================================================ regeneration still works

func test_a_plain_sweeper_still_lets_a_shield_do_its_job() -> void:
	# Cleanse is a DestroyAllEffect with can_regenerate left true, so the
	# Skeleton's shield is the whole difference between it and the board.
	var skeleton := put_battlefield(0, "Drudge Skeletons")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, skeleton, 0, []))
	resolve_stack()
	assert_eq(skeleton.regeneration_shields, 1)
	_cast(0, "Cleanse", [Mtg.ManaColor.C, Mtg.ManaColor.C, Mtg.ManaColor.W,
		Mtg.ManaColor.W])
	resolve_stack()
	assert_eq(skeleton.zone, Mtg.Zone.BATTLEFIELD, "it regenerated")
	assert_eq(skeleton.regeneration_shields, 0, "spending the shield")
	assert_true(skeleton.tapped)


func test_wrath_of_god_still_ignores_the_shield() -> void:
	# The other half of the same knob: can_regenerate = false, and the
	# bracket does not soften it (CR 701.15d).
	var skeleton := put_battlefield(0, "Drudge Skeletons")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, skeleton, 0, []))
	resolve_stack()
	_cast(0, "Wrath of God", [Mtg.ManaColor.C, Mtg.ManaColor.C,
		Mtg.ManaColor.W, Mtg.ManaColor.W])
	resolve_stack()
	assert_eq(skeleton.zone, Mtg.Zone.GRAVEYARD, "they can't be regenerated")
	assert_false(g.log_lines.has("Drudge Skeletons regenerates"),
		"the shield was never offered (CR 701.15d)")


# ============================================== one sweeper of every shape

func test_hurkyls_recall_bounces_every_artifact_in_one_go() -> void:
	# THE MASS BOUNCE. MtgGame.return_to_hand ends with
	# check_state_based_actions(), so this loop used to check once per
	# artifact. The Animate Artifact makes the reading visible: it is an
	# Aura on the Sol Ring, so the instant the Ring goes it is an orphan —
	# and it must not be swept until the whole Recall has landed.
	var recorder := _recorder(0)
	var ring := put_battlefield(1, "Sol Ring")
	var animate := _aura_on("Animate Artifact", ring, 1)
	put_battlefield(1, "Howling Mine")
	advance_to_step(Mtg.Step.MAIN1)
	_cast(0, "Hurkyl's Recall", [Mtg.ManaColor.C, Mtg.ManaColor.U],
		[TargetRef.player(1)])
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.HAND)
	assert_eq(animate.zone, Mtg.Zone.GRAVEYARD, "the orphan is swept, after")
	var seen := _seen(recorder)
	assert_eq(seen[0]["left"], "Sol Ring")
	assert_eq(seen[1]["left"], "Howling Mine")
	assert_true(Array(seen[1]["standing"]).has("Animate Artifact"),
		"the orphaned Aura is still standing when the second artifact goes")
	assert_eq(seen[2]["left"], "Animate Artifact")


func test_martyrs_cry_exiles_every_white_creature_in_one_go() -> void:
	# THE MASS EXILE. MtgGame.exile_permanent also ends with
	# check_state_based_actions(). Same reading, and the card's own draw
	# count must be unchanged by the bracket.
	var recorder := _recorder(0)
	var lions := put_battlefield(1, "Savannah Lions")
	var strength := _aura_on("Holy Strength", lions, 1)
	put_battlefield(1, "Benalish Hero")
	var library_before := g.players[1].library.size()
	advance_to_step(Mtg.Step.MAIN1)
	_cast(0, "Martyr's Cry", [Mtg.ManaColor.W, Mtg.ManaColor.W])
	resolve_stack()
	assert_eq(lions.zone, Mtg.Zone.EXILE)
	assert_eq(strength.zone, Mtg.Zone.GRAVEYARD, "orphaned, then swept")
	assert_eq(g.players[1].library.size(), library_before - 2,
		"one card for each creature exiled")
	var seen := _seen(recorder)
	assert_true(Array(seen[1]["standing"]).has("Holy Strength"),
		"still standing when the second martyr goes")


func test_city_in_a_bottle_sacrifices_arabia_in_one_go() -> void:
	# THE MASS SACRIFICE, from a triggered ability rather than a spell —
	# and the OTHER death replacement as the microscope. MtgGame.
	# sacrifice_permanent goes through _move_to_graveyard exactly as a
	# destruction does, so a victim the Whippoorwill has marked
	# (CardInstance.exile_instead_of_dying, CR 614.1c) is re-routed into
	# MtgGame.exile_permanent — which ends with check_state_based_actions().
	# Put the marked Arabian FIRST and an unmarked one behind it, and the
	# second one's reading says whether that check got to run.
	var recorder := _recorder(0)
	var bird := put_battlefield(0, "Whippoorwill")            # drk: survives
	var maiden := put_battlefield(1, "Bird Maiden")           # arn
	var strength := _aura_on("Holy Strength", maiden, 1)
	var djinn := put_battlefield(1, "Erhnam Djinn")           # arn
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.activate_ability(0, bird, 0, [TargetRef.card(maiden)]))
	resolve_stack()
	assert_true(maiden.exile_instead_of_dying, "the Maiden is marked")
	_cast(0, "City in a Bottle", [Mtg.ManaColor.C, Mtg.ManaColor.C])
	resolve_stack()
	assert_eq(maiden.zone, Mtg.Zone.EXILE, "exiled instead of dying")
	assert_eq(djinn.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(strength.zone, Mtg.Zone.GRAVEYARD, "orphaned, then swept")
	var seen := _seen(recorder)
	var order: Array = []
	for row in seen:
		order.append(row["left"])
	assert_eq(order, ["Bird Maiden", "Erhnam Djinn", "Holy Strength"],
		"both Arabians first, the orphan afterwards")
	assert_true(Array(seen[1]["standing"]).has("Holy Strength"),
		"AND THE ORPHAN WAS STILL STANDING when the Djinn was sacrificed — "
		+ "the marked Maiden's exile did not get to sweep it mid-resolution "
		+ "(CR 704.3)")


func test_golgothian_sylex_sacrifices_antiquities_in_one_go() -> void:
	# The same shape from an ACTIVATED ability, and the sweep includes the
	# Sylex itself. Atog is marked, so its departure goes through
	# exile_permanent; Su-Chi behind it is the reading.
	var recorder := _recorder(0)
	var bird := put_battlefield(0, "Whippoorwill")            # drk: survives
	var sylex := put_battlefield(0, "Golgothian Sylex")       # atq
	var atog := put_battlefield(1, "Atog")                    # atq
	var strength := _aura_on("Holy Strength", atog, 1)
	var su_chi := put_battlefield(1, "Su-Chi")                # atq
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.activate_ability(0, bird, 0, [TargetRef.card(atog)]))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, sylex, 0, []))
	resolve_stack()
	assert_eq(sylex.zone, Mtg.Zone.GRAVEYARD, "it goes in its own sweep")
	assert_eq(atog.zone, Mtg.Zone.EXILE, "exiled instead of dying")
	assert_eq(su_chi.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(strength.zone, Mtg.Zone.GRAVEYARD, "orphaned, then swept")
	var seen := _seen(recorder)
	assert_eq(seen[2]["left"], "Su-Chi")
	assert_true(Array(seen[2]["standing"]).has("Holy Strength"),
		"the orphan is still standing when the last Antiquities permanent "
		+ "is sacrificed")


func test_abu_ja_far_takes_both_blockers_at_once() -> void:
	# A DIES trigger that destroys SEVERAL creatures — two blockers in one
	# resolution. The marked blocker leaves through exile_permanent, and
	# the unmarked one behind it is the reading.
	var recorder := _recorder(0)
	var bird := put_battlefield(0, "Whippoorwill")
	var abu := put_battlefield(0, "Abu Ja'far")
	var bear := put_battlefield(1, "Grizzly Bears")
	var strength := _aura_on("Holy Strength", bear, 1)
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.activate_ability(0, bird, 0, [TargetRef.card(bear)]))
	resolve_stack()
	run_combat([abu.id], {bear.id: abu.id, giant.id: abu.id})
	resolve_stack()
	assert_eq(abu.zone, Mtg.Zone.GRAVEYARD, "a 0/1 into two blockers")
	assert_eq(bear.zone, Mtg.Zone.EXILE, "marked, so exiled instead of dying")
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(strength.zone, Mtg.Zone.GRAVEYARD)
	var seen := _seen(recorder)
	var order: Array = []
	for row in seen:
		order.append(row["left"])
	assert_eq(order.slice(order.find("Grizzly Bears")),
		["Grizzly Bears", "Hill Giant", "Holy Strength"],
		"both blockers, then the orphan: %s" % [order])
	assert_true(Array(seen[order.find("Hill Giant")]["standing"]).has("Holy Strength"),
		"the orphan is still standing when the second blocker goes")
	_assert_bracket_closed()


# ==================================== the rest of what this pass bracketed ==

func test_hazezon_scatters_every_sand_warrior_in_one_go() -> void:
	# Another MASS EXILE, this one from a leave-trigger. An Aura on the
	# first Sand Warrior is the reading: it is orphaned the moment that
	# token goes, and it must still be standing when the second one leaves.
	var recorder := _recorder(0)
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var hazezon := put_battlefield(0, "Hazezon Tamar")
	resolve_stack()
	advance_to_next_turn()
	advance_to_next_turn()      # his controller's next upkeep
	resolve_stack()
	var sands: Array[CardInstance] = []
	for inst in g.players[0].battlefield:
		if inst.data.card_name == "Sand Warrior":
			sands.append(inst)
	assert_eq(sands.size(), 2, "one Sand Warrior per land")
	var strength := _aura_on("Holy Strength", sands[0], 0)
	g.destroy(hazezon)
	g.check_state_based_actions()
	resolve_stack()
	assert_null(g.find_on_battlefield(0, "Sand Warrior"), "they all blow away")
	assert_eq(strength.zone, Mtg.Zone.GRAVEYARD, "orphaned, then swept")
	var seen := _seen(recorder)
	var second := -1
	var sand_seen := 0
	for i in seen.size():
		if str(seen[i]["left"]) == "Sand Warrior":
			sand_seen += 1
			if sand_seen == 2:
				second = i
	assert_eq(sand_seen, 2, "both tokens left the battlefield")
	assert_true(Array(seen[second]["standing"]).has("Holy Strength"),
		"the orphan is still standing when the second Sand Warrior goes")
	_assert_bracket_closed()


func test_the_war_barge_drowns_both_passengers_in_one_go() -> void:
	# A delayed trigger that destroys several creatures. The marked
	# passenger leaves through exile_permanent; the second is the reading.
	var recorder := _recorder(0)
	var bird := put_battlefield(0, "Whippoorwill")
	var barge := put_battlefield(0, "War Barge")
	var bear := put_battlefield(0, "Grizzly Bears")
	var strength := _aura_on("Holy Strength", bear, 0)
	var giant := put_battlefield(0, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 6)
	assert_ok(g.activate_ability(0, barge, 0, [TargetRef.card(bear)]))
	resolve_stack()
	assert_ok(g.activate_ability(0, barge, 0, [TargetRef.card(giant)]))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.activate_ability(0, bird, 0, [TargetRef.card(bear)]))
	resolve_stack()
	g.destroy(barge)
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.EXILE, "marked, so exiled instead of dying")
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "both passengers go down")
	assert_eq(strength.zone, Mtg.Zone.GRAVEYARD)
	var seen := _seen(recorder)
	var second := -1
	for i in seen.size():
		if str(seen[i]["left"]) == "Hill Giant":
			second = i
	assert_true(Array(seen[second]["standing"]).has("Holy Strength"),
		"the orphan is still standing when the second passenger drowns")
	_assert_bracket_closed()


## Two attackers into one Wall — the only way a Wall's block history holds
## more than one name (Blaze of Glory, CR 509.1b), and therefore the only
## board on which either Glyph destroys SEVERAL creatures at once.
func _two_attackers_into_one_wall() -> Dictionary:
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id, bear.id]))
	resolve_stack()
	var blaze := give_hand(0, "Blaze of Glory")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, blaze, [TargetRef.card(wall)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	# ONE-TO-MANY (CR 509.1b): the value is an ARRAY of attackers.
	assert_ok(g.declare_blockers(1, {wall.id: [giant.id, bear.id]}))
	return {"giant": giant, "bear": bear, "wall": wall}


func test_glyph_of_doom_buries_both_blocked_attackers_in_one_go() -> void:
	var board := _two_attackers_into_one_wall()
	assert_ok(g.pass_priority(0))
	var glyph := give_hand(1, "Glyph of Doom")
	add_mana(1, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(1, glyph, [TargetRef.card(board["wall"])]))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(board["giant"].zone, Mtg.Zone.GRAVEYARD)
	assert_eq(board["bear"].zone, Mtg.Zone.GRAVEYARD,
		"both attackers the Wall stopped, in one delayed action")
	_assert_bracket_closed()


func test_glyph_of_reincarnation_trades_both_in_one_go() -> void:
	var board := _two_attackers_into_one_wall()
	advance_to_step(Mtg.Step.MAIN2)
	assert_ok(g.pass_priority(0))
	var glyph := give_hand(1, "Glyph of Reincarnation")
	add_mana(1, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(1, glyph, [TargetRef.card(board["wall"])]))
	resolve_stack()
	# The Glyph's controller picks the WORST body out of the attacker's
	# graveyard each time (CR 609.3), which after each destruction is the
	# creature just killed — so both come straight back, twice over, in
	# one resolution.
	assert_eq(board["giant"].zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(board["bear"].zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(board["wall"].zone, Mtg.Zone.BATTLEFIELD, "the Wall stands")
	_assert_bracket_closed()
