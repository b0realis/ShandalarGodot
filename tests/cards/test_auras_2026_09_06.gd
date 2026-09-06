extends GameTest
## TWO THINGS ABOUT AURAS, from the playtest of 2026-09-06 — the rules
## half of both of that afternoon's reports. Their SCREEN halves are in
## `tests/ui/test_enchanted_attacker_2026_09_06.gd` (the click that went
## to the aura instead of its host) and
## `tests/ui/test_enchanted_permanent_2026_09_06.gd` (the aura a strip
## pile swallowed).
##
## §1 MORE THAN ONE AURA ON ONE PERMANENT, and the owner's rule for it:
## *"Yes, multiple auras can be on a card! All should take effect and
## present final cumulative card properties when dealing with the card."*
## Pinned as SUMMATION over the whole pool, not one card at a time: the
## P/T of a host wearing two auras is its own plus BOTH deltas, and the
## damage it deals unblocked is that sum. The earlier sweep read the
## damage against `cur_power` — which is exactly the number a
## "first aura wins" bug would have got wrong too, so it could not have
## caught one.
##
## §2 AN AURA ON A PERMANENT ITS CASTER DOES NOT CONTROL.
##
## *"Opponent casts **Psychic Venom** on MY land — it went directly to the
## graveyard. The card should be present as an aura behind my land on my
## playfield, and should take effect immediately when I tap my land. If
## that enchantment gets destroyed it goes to the OPPONENT's graveyard.
## Check all similar cases."*
##
## Three claims, and the engine already held all three: what the player
## saw was a DRAWING bug (`tests/ui/test_enchanted_permanent_2026_09_06.gd`
## — a permanent folded into one of the original's strip piles lost its
## aura fan, so the Venom was nowhere on the table and "it went to the
## graveyard" was the only reading left). They are pinned here anyway,
## because a claim that is only true by accident is one refactor from
## being false, and because the sweep at the bottom is the "check all
## similar cases" the report asked for.
##
##  1. IT ATTACHES. CR 303.4a — an Aura spell that resolves enters
##     attached to the object it targeted, whoever controls that object.
##  2. IT FIRES FOR THE RIGHT PLAYER. Psychic Venom deals its 2 to the
##     LAND's controller, not the aura's.
##  3. IT DIES TO ITS OWNER. CR 400.3 — a card put into a graveyard goes
##     to its OWNER's, never to the graveyard of whoever controlled what
##     it was attached to.


## An aura from [param pid]'s hand, put onto [param host] — which is quite
## deliberately allowed to belong to the other seat.
func _enchant(card_name: String, host: CardInstance, pid: int) -> CardInstance:
	var aura := _make_instance(pid, card_name)
	aura.zone = Mtg.Zone.HAND
	g.players[pid].hand.append(aura)
	g.attach_aura_from_anywhere(aura, host, pid)
	return aura


# ------------------------------------- THE BOARD THE REPORT DESCRIBES --

func test_the_opponent_casts_it_on_my_land_through_the_real_cast_path() -> void:
	var mine := put_battlefield(0, "Island")
	advance_to_next_turn()          # seat 1's own main phase
	resolve_stack()
	var venom := give_hand(1, "Psychic Venom")
	add_mana(1, Mtg.ManaColor.U)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, venom, [TargetRef.card(mine)]))
	resolve_stack()
	assert_eq(venom.zone, Mtg.Zone.BATTLEFIELD,
		"it is on the battlefield, not in a graveyard")
	assert_eq(venom.attached_to, mine.id,
		"attached to the land it targeted (CR 303.4a)")
	assert_eq(venom.controller_id, 1, "controlled by the seat that cast it")
	assert_true(mine.attachments.has(venom.id), "and the land knows")


func test_it_stings_the_lands_controller_not_the_auras() -> void:
	var mine := put_battlefield(0, "Island")
	_enchant("Psychic Venom", mine, 1)
	var mine_before: int = g.players[0].life
	var theirs_before: int = g.players[1].life
	g.tap_for_mana(0, mine)
	resolve_stack()
	assert_eq(g.players[0].life, mine_before - 2,
		"2 damage to the LAND's controller, on the tap")
	assert_eq(g.players[1].life, theirs_before,
		"and none to the seat that owns the aura")


func test_destroyed_it_goes_to_its_owners_graveyard() -> void:
	var mine := put_battlefield(0, "Island")
	var venom := _enchant("Psychic Venom", mine, 1)
	g.destroy(venom)
	assert_true(g.players[1].graveyard.has(venom),
		"CR 400.3: a card goes to its OWNER's graveyard")
	assert_false(g.players[0].graveyard.has(venom),
		"never to the graveyard of whoever controlled the land")


## ...and when the HOST dies, the Aura follows it off (CR 704.5m) — into
## the same OWNER's graveyard, not the host controller's. Killed with a
## real spell, so the state-based check runs where a duel runs it.
func test_the_host_dying_sends_the_aura_to_its_owner_too() -> void:
	var mine := put_battlefield(0, "Grizzly Bears")
	var weakness := _enchant("Weakness", mine, 1)
	assert_eq(mine.cur_toughness, 1, "2/2 under Weakness is a 0/1")
	advance_to_next_turn()          # seat 1's own turn
	resolve_stack()
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(mine)]))
	resolve_stack()
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, "the creature died")
	assert_true(g.players[0].graveyard.has(mine), "my creature, my graveyard")
	assert_eq(weakness.zone, Mtg.Zone.GRAVEYARD,
		"the aura fell off with it (CR 704.5m)")
	assert_true(g.players[1].graveyard.has(weakness),
		"their aura, their graveyard (CR 400.3)")


# ------------------------------------------------- CHECK ALL THE CASES --

## Every Aura in the pool that can legally sit on a permanent the OTHER
## seat controls: it stays on the battlefield attached, its controller is
## its caster, and it goes to its OWNER's graveyard when it dies.
##
## Immolation is the one card left out and the reason is the rules': +2/-2
## on a 2/2 makes a 4/0, the toughness SBA sweeps it (CR 704.5f) and the
## Aura follows (CR 704.5m) before this test could ever look at it.
func test_every_aura_that_can_cross_the_table() -> void:
	var checked := 0
	for card_name in CardRegistry.all_names():
		var data: CardData = CardRegistry.get_card(card_name)
		if not data.is_aura() or card_name == "Immolation":
			continue
		g = MtgGame.new()
		var filler: Array = []
		for _i in 30:
			filler.append("Forest")
		g.setup(filler, filler, "P0", "P1", 20, 20, 424242)
		g.start(0)
		var hosts: Array = [
			put_battlefield(0, "Grizzly Bears"), put_battlefield(0, "Island"),
			put_battlefield(0, "Mountain"), put_battlefield(0, "Forest"),
			put_battlefield(0, "Plains"), put_battlefield(0, "Swamp"),
			put_battlefield(0, "Black Vise")]
		resolve_stack()
		var host: CardInstance = null
		for h in hosts:
			if h.zone == Mtg.Zone.BATTLEFIELD \
					and data.aura_target.is_legal(g, TargetRef.card(h), null):
				host = h
				break
		if host == null:
			continue   # nothing of mine it could ever enchant
		var aura := _enchant(card_name, host, 1)
		if aura.zone != Mtg.Zone.BATTLEFIELD:
			# "Enchant creature you control" (Cocoon) and friends: the
			# attach is refused outright, which is the right answer.
			continue
		checked += 1
		assert_eq(aura.attached_to, host.id,
			"%s attached to the permanent the other seat controls" % card_name)
		assert_eq(aura.controller_id, 1,
			"%s is controlled by the seat that played it" % card_name)
		g.destroy(aura)
		assert_true(g.players[1].graveyard.has(aura),
			"%s went to its OWNER's graveyard (CR 400.3)" % card_name)
	assert_gt(checked, 40,
		"the sweep actually found auras to aim across the table")


# ==================================================================== §1 --
#
# THE CUMULATIVE RULE. A host wearing two auras reads as its printed body
# plus both of their deltas, and deals that sum unblocked.

const _DUMMY_P := 6
const _DUMMY_T := 6


func _dummy_data() -> CardData:
	return CardData.new("Sweep Dummy", "{4}", Mtg.CardType.CREATURE) \
		.pt(_DUMMY_P, _DUMMY_T)


func _fresh_game() -> void:
	g = MtgGame.new()
	var filler: Array = []
	for _i in 30:
		filler.append("Forest")
	g.setup(filler, filler, "P0", "P1", 20, 20, 424242)
	g.start(0)


## Every Aura in the pool that can enchant a plain creature.
func _creature_auras() -> Array:
	_fresh_game()
	var bear := put_battlefield(0, "Grizzly Bears")
	var names: Array = []
	for n in CardRegistry.all_names():
		var d: CardData = CardRegistry.get_card(n)
		if d.is_aura() and d.aura_target.is_legal(g, TargetRef.card(bear), null):
			names.append(n)
	names.sort()
	return names


## `[power, toughness]` of a fresh dummy wearing exactly [param list], or
## `[]` when the combination took the creature off our battlefield
## (Control Magic) or off the table entirely.
func _pt_wearing(list: Array) -> Array:
	_fresh_game()
	var host := put_synthetic(0, _dummy_data())
	for n in list:
		_enchant(n, host, 0)
	g.recalculate()
	if host.zone != Mtg.Zone.BATTLEFIELD \
			or not g.players[0].battlefield.has(host):
		return []
	return [host.cur_power, host.cur_toughness]


## THE REPORTED BOARD, in the engine: a 1/1 Jackal wearing Firebreathing
## (no static body change) and The Brute (+1/+0) is a 2/1.
func test_the_hurr_jackal_board_reads_cumulatively() -> void:
	_fresh_game()
	var jackal := put_battlefield(0, "Hurr Jackal")
	_enchant("Firebreathing", jackal, 0)
	_enchant("The Brute", jackal, 0)
	g.recalculate()
	assert_eq(jackal.attachments.size(), 2, "both auras are on it")
	assert_eq(jackal.cur_power, 2, "1/1 plus The Brute's +1/+0")
	assert_eq(jackal.cur_toughness, 1)
	run_combat([jackal.id])
	assert_eq(g.players[1].life, 18, "and it deals that 2 unblocked")


## EVERY PAIR. The host's P/T is its printed body plus BOTH auras' solo
## deltas — 1326 pairs over the 52 creature-auras in the pool.
##
## The exceptions are the WARD cycle and they are the rules' own: a
## creature with protection from a colour sheds an Aura of that colour
## (CR 702.16d / 704.5m), so Red Ward + The Brute is a creature wearing
## ONE aura, correctly. A pair whose second aura is no longer attached is
## therefore not a summation case at all, and is measured as what it is.
func test_every_pair_of_auras_sums() -> void:
	var names := _creature_auras()
	var solo := {}
	for n in names:
		solo[n] = _pt_wearing([n])
	var bad: Array = []
	var checked := 0
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: String = names[i]
			var b: String = names[j]
			if (solo[a] as Array).is_empty() or (solo[b] as Array).is_empty():
				continue
			var got := _pt_wearing([a, b])
			if got.is_empty():
				continue
			# A ward that made its partner fall off: one aura, not two.
			var wearing := 0
			for inst in g.players[0].battlefield:
				wearing += inst.attachments.size()
			if wearing < 2:
				continue
			checked += 1
			var want := [
				_DUMMY_P + (solo[a][0] - _DUMMY_P) + (solo[b][0] - _DUMMY_P),
				_DUMMY_T + (solo[a][1] - _DUMMY_T) + (solo[b][1] - _DUMMY_T)]
			if got != want:
				bad.append("%s + %s -> %s, expected %s" % [a, b, str(got), str(want)])
	assert_eq(bad.size(), 0, "two auras sum: %s" % ", ".join(bad))
	assert_gt(checked, 1000, "the sweep really walked the pool")


## ...AND A THIRD ONE ON TOP. Every aura in the pool wearing the same two
## companions, so a triple is measured as well as a pair.
func test_a_third_aura_sums_too() -> void:
	var names := _creature_auras()
	var base := _pt_wearing(["Holy Strength", "Unholy Strength"])
	var bad: Array = []
	var checked := 0
	for n in names:
		if n == "Holy Strength" or n == "Unholy Strength":
			continue
		var solo := _pt_wearing([n])
		if solo.is_empty():
			continue
		var got := _pt_wearing([n, "Holy Strength", "Unholy Strength"])
		if got.is_empty():
			continue
		var wearing := 0
		for inst in g.players[0].battlefield:
			wearing += inst.attachments.size()
		if wearing < 3:
			continue     # a ward shed one of the three; not a triple
		checked += 1
		var want := [base[0] + (solo[0] - _DUMMY_P), base[1] + (solo[1] - _DUMMY_T)]
		if got != want:
			bad.append("%s on the pair -> %s, expected %s" % [n, str(got), str(want)])
	assert_eq(bad.size(), 0, "three auras sum: %s" % ", ".join(bad))
	assert_gt(checked, 30, "the triple sweep really walked the pool")


## AND THE DAMAGE FOLLOWS THE SUM. Every pair, attacked unblocked: the
## defender loses exactly the attacker's live power.
##
## Brainwash ("can't attack unless its controller pays {3}") and Gaseous
## Form ("prevent all combat damage") are the two cards that legitimately
## break the equality, and they break it by doing what they print.
func test_every_pair_deals_its_summed_power_unblocked() -> void:
	var names := _creature_auras()
	var bad: Array = []
	var checked := 0
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: String = names[i]
			var b: String = names[j]
			if a == "Brainwash" or b == "Brainwash" \
					or a == "Gaseous Form" or b == "Gaseous Form":
				continue
			_fresh_game()
			var host := put_synthetic(0, _dummy_data())
			_enchant(a, host, 0)
			_enchant(b, host, 0)
			if host.zone != Mtg.Zone.BATTLEFIELD:
				continue
			advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
			if not g.players[0].battlefield.has(host):
				continue    # Control Magic took it across the table
			if CombatState.attack_illegality(g, host, 1) != "":
				continue
			assert_ok(g.declare_attackers(0, [host.id]))
			resolve_stack()
			advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
			assert_ok(g.declare_blockers(1, {}))
			var power: int = host.cur_power
			var before: int = g.players[1].life
			advance_to_step(Mtg.Step.COMBAT_END)
			checked += 1
			if before - g.players[1].life != power:
				bad.append("%s + %s: power %d, defender lost %d" % [
					a, b, power, before - g.players[1].life])
	assert_eq(bad.size(), 0, "the sum is what lands: %s" % ", ".join(bad))
	assert_gt(checked, 900, "the sweep really walked the pool")
