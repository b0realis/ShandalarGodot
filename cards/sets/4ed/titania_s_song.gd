extends CardScript
## Titania's Song — {3}{G} — Enchantment — (4ed, rare)
## Oracle: Each noncreature artifact loses all abilities and becomes an
##         artifact creature with power and toughness each equal to its
##         mana value. If this enchantment leaves the battlefield, this
##         effect continues until end of turn.
##
## Implementation: a global static that, for every artifact that isn't
## already a creature, adds CREATURE to its live type mask (a CR 613
## layer-4 change, tagged .changing_types()), sets its base P/T to its
## mana value (layer 7b, done by the same callback), CLEARS its live
## mana/activated lists and raises CardInstance.cur_abilities_silenced
## for the triggered and static ones the engine reads off the printed
## data — the .silencing_abilities() tag, which is what decides WHEN it
## runs: ContinuousEffects runs every silencer in its early SILENCE pass
## (layer 6, before the type and base-P/T passes, so a silenced Sol
## Ring's own statics never get a turn), and the P/T set still lands
## before counters and pumps. So a silenced Sol Ring stops
## making mana, an Icy Manipulator stops tapping things, an Ankh of
## Mishra stops stinging and a Meekstone stops locking. Symmetric: your
## own Moxen become 0/0s and die.
##
## THE RIDER — "if this enchantment leaves the battlefield, this effect
## continues until end of turn" — is the same static, handed to
## ContinuousEffects as a FLOATING one (add_floating_static) by the
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
		.as_it_leaves(_linger) \
		.oracle("Each noncreature artifact loses all abilities and becomes an artifact "
			+ "creature with power and toughness each equal to its mana value. If this "
			+ "enchantment leaves the battlefield, this effect continues until end of turn.")


## The card's one static, built here rather than inline so the leave hook
## can hand the very same ability to the floating registry.
static func _animate_every_artifact() -> StaticAbility:
	return StaticAbility.new(
		_apply,
		"Each noncreature artifact loses all abilities and becomes an artifact "
		+ "creature with power and toughness each equal to its mana value.") \
		.changing_types().silencing_abilities()


static func _apply(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if not inst.is_type(Mtg.CardType.ARTIFACT) or inst.is_creature():
			continue
		inst.cur_types |= Mtg.CardType.CREATURE
		var mv := inst.data.cost.mana_value()
		inst.cur_power = mv
		inst.cur_toughness = mv
		inst.cur_mana_abilities = []
		inst.cur_activated_abilities = []
		# Triggered and static abilities are read off the printed CardData,
		# so they need the silencing FLAG rather than a cleared list.
		inst.cur_abilities_silenced = true


## "If this enchantment leaves the battlefield, this effect continues until
## end of turn." The Song is already off the battlefield here and its own
## floating effects have been dropped (CR 400.7); MtgGame recalculates the
## moment this returns, so the board never shows a frame without the
## animation. A second Song still on the table changes nothing — the two
## effects are idempotent and the survivor keeps applying its own.
static func _linger(game: MtgGame, source: CardInstance, _controller: int,
		_parting: Dictionary) -> void:
	game.continuous.add_floating_static(source, _animate_every_artifact())
	game.log_line("Titania's Song lingers until end of turn")
