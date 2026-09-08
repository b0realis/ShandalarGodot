extends GameTest
## THE WRONG SIDE OF THE TABLE (2026-09-08). The owner's playtest:
## *"Opponent cast Detonate on its own artifact?? (Artifact was not
## harming, it was Mana Vault)"* — {1}{R} paid to destroy its own untapped
## Mana Vault and take one damage for it.
##
## TWO FAULTS, PINNED SEPARATELY. The reader had no row for Detonate
## ([constant EffectIntent.CARD_LOCAL]), so a card-local destroy read as
## `unknown`, and the target picker's 2026-09-04 fallback for an
## unclassified effect with a source filter — written for "creature you
## control" (Simulacrum) — shopped the AI's OWN artifacts when theirs held
## nothing of mana value X: with a Mana Vault the only artifact of cost
## one on the table, X=1 found it, and the cast was priced as a plain
## spell's worth with nothing charged for the Vault or the damage. The row
## closes that. The RULE the fallback was the one exception to — a
## permanent of ours is not offered to a harmful reading unless the
## evaluator prices giving it up below zero — is [member
## AiProfile.spares_own], and it acts where a variable-count spell's
## slots are padded ([method AiPlayer._extra_targets]): a Winter Blast for
## four with one enemy creature to tap used to be filled out with three of
## our own (112 of the 293 creatures it named in sixty Ape Lord games
## were the caster's). Each behaviour is pinned with the knob and without.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.spares_own = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.spares_own = false
	return profile


func _mountains(pid: int, n: int) -> void:
	for _i in n:
		put_battlefield(pid, "Mountain")


## Lands this seat still has untapped — a cast refused after the taps
## would leave this smaller for nothing (CR 500.4).
func _untapped_lands(pid: int) -> int:
	var n := 0
	for inst in g.players[pid].battlefield:
		if inst.is_land() and not inst.tapped:
			n += 1
	return n


## Act until the AI casts [param card_name] or has nothing to do.
func _act_for(ai: AiPlayer, card_name: String, rounds := 6) -> String:
	for _i in rounds:
		var did := ai.act(g)
		if did == "" or did.contains(card_name):
			return did
	return ""


## The targets of the spell on top of the stack, split by whose they are.
func _targets_by_side(item: StackItem, pid: int) -> Dictionary:
	var out := {"own": 0, "theirs": 0}
	for t in item.targets:
		if t is TargetRef and not t.is_player:
			var inst := g.find_instance(t.instance_id)
			if inst != null:
				out["own" if inst.controller_id == pid else "theirs"] += 1
	return out


# ------------------------------------------------ Detonate and the reader --

func test_the_reader_knows_detonate_is_removal() -> void:
	# The fault at the root: a card-local destroy the reader called
	# `unknown`, which is the one word the picker's own-side fallback
	# gates on.
	var data := CardRegistry.get_card("Detonate")
	var intent := EffectIntent.read(data.spell_effects, data.card_name)
	assert_false(intent.unknown, "Detonate is read, not guessed")
	assert_true(intent.removes, "it destroys")
	assert_true(intent.removal_ignores_regeneration, "and the artifact cannot regenerate")
	assert_true(intent.is_harmful())


func test_does_not_detonate_its_own_mana_vault() -> void:
	# The owner's board: our untapped Mana Vault the only artifact on the
	# table, {1}{R} and more to spare, Detonate in hand. X=1 finds the
	# Vault and nothing else; the card stays in hand.
	var ai := _ai(_on())
	_mountains(0, 4)
	var vault := put_battlefield(0, "Mana Vault")
	var detonate := give_hand(0, "Detonate")
	advance_to_step(Mtg.Step.MAIN1)
	var did := _act_for(ai, "Detonate")
	assert_false(did.contains("Detonate"), "not cast: " + did)
	assert_eq(detonate.zone, Mtg.Zone.HAND, "Detonate waits")
	assert_eq(vault.zone, Mtg.Zone.BATTLEFIELD, "the Vault is still ours")
	assert_eq(_untapped_lands(0), 4, "and no land was tapped for a refused cast")


func test_does_not_detonate_its_own_tapped_mana_vault_either() -> void:
	# A Vault it cannot untap is a liability in a human's eyes (one damage
	# a turn), but the evaluator has no reading that prices a permanent
	# below zero, so the rule holds and the card waits — the honest
	# answer until the evaluator learns the liability, not a special case
	# for a tapped Vault.
	var ai := _ai(_on())
	_mountains(0, 2)
	var vault := put_battlefield(0, "Mana Vault")
	vault.tapped = true
	var detonate := give_hand(0, "Detonate")
	advance_to_step(Mtg.Step.MAIN1)
	_act_for(ai, "Detonate")
	assert_eq(detonate.zone, Mtg.Zone.HAND)
	assert_eq(vault.zone, Mtg.Zone.BATTLEFIELD)


func test_still_detonates_an_enemy_artifact_of_the_right_cost() -> void:
	# Their Sol Ring (mana value 1) beside our own Mana Vault: the Ring is
	# the target, X is one, the Vault is untouched.
	var ai := _ai(_on())
	_mountains(0, 4)
	var vault := put_battlefield(0, "Mana Vault")
	var ring := put_battlefield(1, "Sol Ring")
	give_hand(0, "Detonate")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(_act_for(ai, "Detonate"), "Detonate")
	var item: StackItem = g.stack.back()
	assert_eq(item.x_value, 1, "sized to the Ring")
	assert_eq(item.targets[0].instance_id, ring.id, "at their Ring")
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(vault.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[1].life, 19, "and the Ring's controller took the damage")


func test_the_row_and_not_the_knob_closes_detonate() -> void:
	# With the knob OFF the Vault is still spared: the reader's row keeps
	# Detonate out of the fallback that shopped our side, and the picker
	# never offers our permanents to a KNOWN harmful effect. The knob's
	# own measurement is the padding, below.
	var ai := _ai(_off())
	_mountains(0, 4)
	var vault := put_battlefield(0, "Mana Vault")
	var detonate := give_hand(0, "Detonate")
	advance_to_step(Mtg.Step.MAIN1)
	_act_for(ai, "Detonate")
	assert_eq(detonate.zone, Mtg.Zone.HAND)
	assert_eq(vault.zone, Mtg.Zone.BATTLEFIELD)


# --------------------------------------- the padding of an X-count spell --

func test_winter_blast_is_not_filled_out_with_our_own_creatures() -> void:
	# {X}{G}, "Tap X target creatures": five lands make X=4, their board
	# has one creature and ours has three. The three used to be the
	# padding; now the slots stay empty and the engine's refusal keeps
	# the card in hand, with every land still untapped.
	var ai := _ai(_on())
	for _i in 5:
		put_battlefield(0, "Forest")
	for _i in 3:
		put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	var blast := give_hand(0, "Winter Blast")
	advance_to_step(Mtg.Step.MAIN1)
	var did := _act_for(ai, "Winter Blast")
	assert_false(did.contains("Winter Blast"), "not cast: " + did)
	assert_eq(blast.zone, Mtg.Zone.HAND)
	assert_eq(_untapped_lands(0), 5, "no land tapped for a refused cast")
	for inst in g.players[0].battlefield:
		if inst.is_creature():
			assert_false(inst.tapped, "our creatures are untouched")


func test_winter_blast_still_taps_their_board() -> void:
	# The same hand against four enemy creatures: cast for four, every
	# slot theirs.
	var ai := _ai(_on())
	for _i in 5:
		put_battlefield(0, "Forest")
	for _i in 3:
		put_battlefield(0, "Grizzly Bears")
	for _i in 4:
		put_battlefield(1, "Hill Giant")
	give_hand(0, "Winter Blast")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(_act_for(ai, "Winter Blast"), "Winter Blast")
	var item: StackItem = g.stack.back()
	assert_eq(item.x_value, 4)
	var sides := _targets_by_side(item, 0)
	assert_eq(sides["theirs"], 4, "four of theirs")
	assert_eq(sides["own"], 0, "none of ours")


func test_the_null_pads_with_our_own_creatures() -> void:
	# The knob's null is the 2026-09-04 padding, so the Deck Lab's sweep
	# has something to measure against: one of theirs and three of ours
	# fill the four slots.
	var ai := _ai(_off())
	for _i in 5:
		put_battlefield(0, "Forest")
	for _i in 3:
		put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	give_hand(0, "Winter Blast")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(_act_for(ai, "Winter Blast"), "Winter Blast")
	var sides := _targets_by_side(g.stack.back(), 0)
	assert_eq(sides["theirs"], 1)
	assert_eq(sides["own"], 3, "the old padding")


# ------------------------------------------- what the rule does not touch --

func test_simulacrum_is_still_aimed_at_our_own_creature() -> void:
	# The fallback for an effect the reader could not classify is not this
	# rule's: "target creature you control" still finds our Bears.
	var ai := _ai(_on())
	for land in ["Forest", "Island", "Mountain", "Plains", "Swamp"]:
		for _i in 4:
			put_battlefield(0, land)
	var mine := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	give_hand(0, "Simulacrum")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(_act_for(ai, "Simulacrum"), "Simulacrum")
	var item: StackItem = g.stack.back()
	assert_eq(item.targets[0].instance_id, mine.id, "at our own creature")
