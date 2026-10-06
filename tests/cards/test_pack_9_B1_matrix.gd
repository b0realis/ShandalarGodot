extends GameTest
## Pack 9 (the Tempest block), batch B1: the SHADOW matrix — every creature
## body of cards/sets/{tmp,sth,exo}/_shadow.gd against the blocking rule of
## CR 702.28b ("a creature with shadow can't be blocked by creatures
## without shadow, and a creature without shadow can't be blocked by
## creatures with shadow"), both directions, under every rules preset —
## modern, modern_mana_burn and fifth (shadow reads the same in 1997 and
## today) — plus the two "can block creatures with shadow as though it had
## shadow" bodies (Heartwood Dryad, Wall of Diffusion), which still block
## ordinary creatures. The predicate is the one the declaration uses
## ([method CombatState.block_illegality]);
## real declarations pin it for a sample of bodies under each preset.

## Every B1 name (36): none may carry the dispatcher's pending guard.
const CLAIMED := ["Circle of Protection: Shadow", "Dauthi Embrace", "Dauthi Ghoul",
	"Dauthi Horror", "Dauthi Marauder", "Dauthi Mercenary", "Dauthi Mindripper",
	"Dauthi Slayer", "Heartwood Dryad", "Maze of Shadows", "Phyrexian Splicer",
	"Reality Anchor", "Shadow Rift", "Shadowstorm", "Soltari Crusader", "Soltari Emissary",
	"Soltari Foot Soldier", "Soltari Guerrillas", "Soltari Lancer", "Soltari Monk",
	"Soltari Priest", "Soltari Trooper", "Thalakos Dreamsower", "Thalakos Mistfolk",
	"Thalakos Seer", "Thalakos Sentry", "Wall of Diffusion", "Dauthi Trapper",
	"Soltari Champion", "Thalakos Deceiver", "Dauthi Cutthroat", "Dauthi Jackal",
	"Dauthi Warlord", "Soltari Visionary", "Thalakos Drifters", "Thalakos Scout"]

## The creature bodies with PRINTED shadow (24).
const SHADES := ["Dauthi Ghoul", "Dauthi Horror", "Dauthi Marauder", "Dauthi Mercenary",
	"Dauthi Mindripper", "Dauthi Slayer", "Soltari Crusader", "Soltari Foot Soldier",
	"Soltari Guerrillas", "Soltari Lancer", "Soltari Monk", "Soltari Priest",
	"Soltari Trooper", "Thalakos Dreamsower", "Thalakos Mistfolk", "Thalakos Seer",
	"Thalakos Sentry", "Soltari Champion", "Thalakos Deceiver", "Dauthi Cutthroat",
	"Dauthi Jackal", "Dauthi Warlord", "Soltari Visionary", "Thalakos Scout"]

## The creature bodies WITHOUT printed shadow (they grant or gain it).
const PLAIN := ["Soltari Emissary", "Thalakos Drifters", "Dauthi Trapper"]

## "Can block creatures with shadow as though it had shadow."
const AS_THOUGH := ["Heartwood Dryad", "Wall of Diffusion"]

## Every rules preset of the Options screen (engine/rules_options.gd).
const PRESETS := ["modern", "modern_mana_burn", "fifth"]


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _why(blocker: CardInstance, attacker: CardInstance) -> String:
	return CombatState.block_illegality(g, blocker, attacker, blocker.controller_id)


## P0 attacks with [param attacker_ids]; P1 is to declare blockers.
func _to_blockers(attacker_ids: Array) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, attacker_ids))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_true(g.awaiting_blockers)


func test_every_b1_card_is_claimed_and_not_pending() -> void:
	assert_eq(CLAIMED.size(), 36)
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending", card_name)


func test_printed_shadow_is_on_every_shade_and_on_nothing_else() -> void:
	for card_name in SHADES:
		var c := CardRegistry.get_card(card_name)
		assert_true(c.keywords.has(Mtg.Keyword.SHADOW), card_name)
		assert_eq(c.keywords.count(Mtg.Keyword.SHADOW), 1, "%s: printed once" % card_name)
		assert_true(put_battlefield(0, card_name).has_keyword(Mtg.Keyword.SHADOW), card_name)
	for card_name in PLAIN + AS_THOUGH:
		assert_false(CardRegistry.get_card(card_name).keywords.has(Mtg.Keyword.SHADOW), card_name)
		var body := put_battlefield(0, card_name)
		assert_false(body.has_keyword(Mtg.Keyword.SHADOW), card_name)
	# The protection the scaffold prints rides along.
	assert_eq(put_battlefield(0, "Soltari Monk").cur_protection, Mtg.ManaColor.B)
	assert_eq(put_battlefield(0, "Soltari Priest").cur_protection, Mtg.ManaColor.R)


## The whole matrix through the declaration's own predicate, both ways,
## under both presets.
func test_the_blocking_matrix_both_ways_under_both_presets() -> void:
	for preset in PRESETS:
		g.rules.set_preset(preset)
		var bears := put_battlefield(1, "Grizzly Bears")
		var their_bears := put_battlefield(0, "Grizzly Bears")
		# A blue shade blocks every shade here: none is pro-blue, and
		# Dauthi Horror's "can't be blocked by white creatures" spares blue.
		var sentry := put_battlefield(1, "Thalakos Sentry")
		var their_sentry := put_battlefield(0, "Thalakos Sentry")
		var dryad := put_battlefield(1, "Heartwood Dryad")
		for card_name in SHADES:
			var shade := put_battlefield(0, card_name)
			var blocker := put_battlefield(1, card_name)
			assert_string_contains(_why(bears, shade), "shadow", "%s/%s: bears can't block it" % [preset, card_name])
			assert_eq(_why(sentry, shade), "", "%s/%s: a shade blocks it" % [preset, card_name])
			assert_eq(_why(dryad, shade), "", "%s/%s: the Dryad blocks it as though" % [preset, card_name])
			assert_string_contains(_why(blocker, their_bears), "shadow", "%s/%s: it can't block bears" % [preset, card_name])
			assert_eq(_why(blocker, their_sentry), "", "%s/%s: it blocks a shade" % [preset, card_name])
		for card_name in PLAIN + AS_THOUGH:
			var body := put_battlefield(1, card_name)
			assert_eq(_why(body, their_bears), "", "%s/%s: blocks ordinary creatures" % [preset, card_name])
			var verdict := _why(body, their_sentry)
			if AS_THOUGH.has(card_name):
				assert_eq(verdict, "", "%s/%s: blocks a shade as though it had shadow" % [preset, card_name])
			else:
				assert_string_contains(verdict, "shadow", "%s/%s: can't block a shade" % [preset, card_name])
		for card_name in PLAIN:
			var attacker := put_battlefield(0, card_name)
			assert_eq(_why(bears, attacker), "", "%s/%s: blocked normally" % [preset, card_name])
			assert_string_contains(_why(sentry, attacker), "shadow", "%s/%s: a shade can't block it" % [preset, card_name])


## Real declarations, a sample from each module, under each preset.
func _declared_combat(preset: String) -> void:
	g.rules.set_preset(preset)
	var marauder := put_battlefield(0, "Dauthi Marauder")
	var monk := put_battlefield(0, "Soltari Monk")
	var bears := put_battlefield(1, "Grizzly Bears")
	var sentry := put_battlefield(1, "Thalakos Sentry")
	var wall := put_battlefield(1, "Wall of Diffusion")
	_to_blockers([marauder.id, monk.id])
	assert_refused(g.declare_blockers(1, {bears.id: marauder.id}), "shadow")
	assert_refused(g.declare_blockers(1, {bears.id: monk.id}), "shadow")
	assert_ok(g.declare_blockers(1, {sentry.id: marauder.id, wall.id: monk.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "both shades were blocked")
	assert_eq(marauder.zone, Mtg.Zone.GRAVEYARD, "3/1 meets the 1/2 Sentry")
	assert_eq(sentry.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(wall.damage, 2, "the Wall took the Monk's 2")


func test_declared_blocks_under_the_modern_preset() -> void:
	_declared_combat("modern")


func test_declared_blocks_under_the_modern_mana_burn_preset() -> void:
	_declared_combat("modern_mana_burn")


func test_declared_blocks_under_the_fifth_edition_preset() -> void:
	_declared_combat("fifth")


## The other direction in a real declaration: a shade defends only
## against shades, under both presets.
func test_a_shade_cannot_be_declared_against_an_ordinary_attacker() -> void:
	for preset in PRESETS:
		g.rules.set_preset(preset)
		var life := g.players[1].life
		var bears := put_battlefield(0, "Grizzly Bears")
		var foot := put_battlefield(0, "Soltari Foot Soldier")
		var ghoul := put_battlefield(1, "Dauthi Ghoul")
		var scout := put_battlefield(1, "Thalakos Scout")
		_to_blockers([bears.id, foot.id])
		assert_refused(g.declare_blockers(1, {ghoul.id: bears.id}), "shadow")
		assert_ok(g.declare_blockers(1, {scout.id: foot.id}))
		advance_to_step(Mtg.Step.COMBAT_END)
		assert_eq(g.players[1].life, life - 2, "%s: the bears were unblockable for them" % preset)
		assert_eq(foot.zone, Mtg.Zone.GRAVEYARD, "%s: 1/1 meets the 2/1 Scout" % preset)
		advance_to_next_turn()
		advance_to_next_turn()


## An unblocked shade connects: under both presets the bears stand idle.
func test_an_unblocked_shade_deals_its_damage_under_both_presets() -> void:
	for preset in PRESETS:
		g.rules.set_preset(preset)
		var life := g.players[1].life
		var lancer := put_battlefield(0, "Soltari Lancer")
		put_battlefield(1, "Craw Wurm")
		_to_blockers([lancer.id])
		assert_ok(g.declare_blockers(1, {}))
		advance_to_step(Mtg.Step.COMBAT_END)
		assert_eq(g.players[1].life, life - 2, preset)
		advance_to_next_turn()
		advance_to_next_turn()
