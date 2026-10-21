extends CardScript
## Titania's Song — {3}{G} — Enchantment — (4ed, rare)
## Oracle: Each noncreature artifact loses all abilities and becomes an
##         artifact creature with power and toughness each equal to its
##         mana value. If this enchantment leaves the battlefield, this
##         effect continues until end of turn.
##
## Implementation: TWO statics. The first, for every artifact that isn't
## already a creature, adds CREATURE to its live type mask (a CR 613
## layer-4 change, tagged .changing_types()), CLEARS its live
## mana/activated lists and raises CardInstance.cur_abilities_silenced
## for the triggered and static ones the engine reads off the printed
## data — the .silencing_abilities() tag, which is what decides WHEN it
## runs: ContinuousEffects runs every silencer in its early SILENCE pass
## (layer 6, before the type and base-P/T passes, so a silenced Sol
## Ring's own statics never get a turn). So a silenced Sol Ring stops
## making mana, an Icy Manipulator stops tapping things, an Ankh of
## Mishra stops stinging and a Meekstone stops locking. Symmetric: your
## own Moxen become 0/0s and die.
##
## The second is the SIZE, a layer-7b set (.setting_base_pt(), the shape
## Animate Artifact has): it applies in timestamp order with Humility's
## 1/1 and the other 7b setters (CR 613.7), so a Song newer than a
## Humility makes a Jayemdae Tome a 4/4 and an older one leaves it 1/1.
## Until the bug hunt of 2026-10-21 the first static wrote the size too,
## in the early pass, and any Humility overwrote it whatever its age.
## The artifacts it sizes are the ones the first static animated: those
## that are not creatures by their own types (printed, or granted for
## good — Ashnod's Transmogrant) — the early pass runs before every other
## type change. One that an animation of its own made a creature this
## turn (Jade Statue, Xenic Poltergeist's "until your next upkeep" sizes
## it the same) keeps that animation's size.
##
## THE RIDER — "if this enchantment leaves the battlefield, this effect
## continues until end of turn" — is the same two statics, handed to
## ContinuousEffects as FLOATING ones (add_floating_static) by the
## immediate leave hook (CardData.as_it_leaves). A trigger cannot express
## it: a trigger resolves off the stack, by which time recalculate() has
## already recomputed the world without the Song and there is nothing left
## to continue. The hook runs at the instant the Song leaves, whichever
## exit it takes — destroyed, exiled, bounced or anted.
##
## The continuation is the ABILITY, not a snapshot of what it was doing.
## CR 611.3a: a continuous effect from a static ability is never locked in,
## and the printed rider lifts CR 611.3b (the source's presence) and
## nothing else — so an artifact that arrives LATER in the same turn is
## animated too, exactly as it would have been with the Song still on the
## table. mage-go reads it the same way (cards/antiquities/enchantments.go
## re-registers `AnimateArtifact(ForAll(EndOfTurn))` on leave).


func build() -> CardData:
	return CardData.new("Titania's Song", "{3}{G}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(_animate_every_artifact()) \
		.static_ability(_size_every_animated_artifact()) \
		.as_it_leaves(_linger) \
		.oracle("Each noncreature artifact loses all abilities and becomes an artifact "
			+ "creature with power and toughness each equal to its mana value. If this "
			+ "enchantment leaves the battlefield, this effect continues until end of turn.")


## The card's two statics, built here rather than inline so the leave hook
## can hand the very same abilities to the floating registry.
static func _animate_every_artifact() -> StaticAbility:
	return StaticAbility.new(
		_apply,
		"Each noncreature artifact loses all abilities and becomes an artifact "
		+ "creature.") \
		.changing_types().silencing_abilities()


static func _size_every_animated_artifact() -> StaticAbility:
	return StaticAbility.new(
		_size,
		"Each artifact it animated has power and toughness each equal to its "
		+ "mana value.") \
		.setting_base_pt()


static func _apply(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if not inst.is_type(Mtg.CardType.ARTIFACT) or inst.is_creature():
			continue
		inst.cur_types |= Mtg.CardType.CREATURE
		inst.cur_mana_abilities = []
		inst.cur_activated_abilities = []
		# Triggered and static abilities are read off the printed CardData,
		# so they need the silencing FLAG rather than a cleared list.
		inst.cur_abilities_silenced = true


## Layer 7b: the size of every artifact [method _apply] animated — an
## artifact creature now that is no creature by its own types, and that no
## animation of its own made one this turn.
static func _size(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if not inst.is_creature() or not inst.is_type(Mtg.CardType.ARTIFACT):
			continue
		if ((inst.data.types | inst.added_types) & Mtg.CardType.CREATURE) != 0 \
				or game.continuous.creature_until_end_of_turn(inst.id):
			continue
		var mv := inst.data.cost.mana_value()
		inst.cur_power = mv
		inst.cur_toughness = mv


## "If this enchantment leaves the battlefield, this effect continues until
## end of turn." The Song is already off the battlefield here and its own
## floating effects have been dropped (CR 400.7); MtgGame recalculates the
## moment this returns, so the board never shows a frame without the
## animation. A second Song still on the table changes nothing — the two
## effects are idempotent and the survivor keeps applying its own.
static func _linger(game: MtgGame, source: CardInstance, _controller: int,
		_parting: Dictionary) -> void:
	game.continuous.add_floating_static(source, _animate_every_artifact())
	game.continuous.add_floating_static(source, _size_every_animated_artifact())
	game.log_line("Titania's Song lingers until end of turn")
