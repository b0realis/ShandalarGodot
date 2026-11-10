extends CardScript
## Titania's Song — {3}{G} — Enchantment — (4ed, rare)
## Oracle: Each noncreature artifact loses all abilities and becomes an
##         artifact creature with power and toughness each equal to its
##         mana value. If this enchantment leaves the battlefield, this
##         effect continues until end of turn.
##
## Implementation: ONE effect in three layers (CR 613.1, 613.6), printed as
## three statics that share the key "song" ([method StaticAbility.part_of]):
##
## - LAYER 4, the type ([method StaticAbility.changing_types]): every
##   artifact that is not a creature when it applies becomes an artifact
##   creature, and is named as one of the effect's objects
##   ([method ContinuousEffects.lock_in]) — CR 613.6, "the same set of
##   objects" in every later layer.
## - LAYER 6, the removal ([method StaticAbility.silencing_abilities]): those
##   artifacts lose all abilities — the flag the engine reads for their
##   printed triggers and statics, and the timestamped strip of their mana,
##   activated and granted abilities ([method ContinuousEffects._layer_six]).
##   So a silenced Sol Ring stops making mana, an Icy Manipulator stops
##   tapping things, an Ankh of Mishra stops stinging and a Meekstone stops
##   locking. Symmetric: your own Moxen become 0/0s and die. The removal is
##   layer 6, so an artifact's own layer-4 and layer-5 effects have applied
##   by then: a Kormus Bell under the Song still makes the Swamps 1/1 black
##   creatures (the owner's ruling of 2026-11-10, CR 613; until then the Song
##   ran ahead of layer 4 and the Bell's Swamps stayed lands).
## - LAYER 7b, the size ([method StaticAbility.setting_base_pt]): power and
##   toughness each equal to the mana value, in timestamp order with
##   Humility's 1/1 and the other 7b setters (CR 613.7) — a Song newer than a
##   Humility makes a Jayemdae Tome a 4/4, an older one leaves it 1/1.
##
## The key keeps the later halves going after the Song itself loses its
## abilities (Opalescence made it a creature, Humility humbled it): its
## effect started in layer 4, so it still removes and sizes (CR 613.6).
##
## WHOM IT REACHES is decided in layer 4, among the other type changes in
## timestamp order. An artifact that a one-shot animation made a creature
## (Jade Statue's own {2}, Xenic Poltergeist, Karn) is a creature before any
## static applies, so the Song skips it and it keeps its abilities and that
## animation's size. Animate Artifact and the Song depend on each other (the
## Aura's "as long as enchanted artifact isn't a creature" against the
## Song's "noncreature artifact") — a dependency loop, so the older one
## applies first (CR 613.8b): an Aura older than the Song keeps its artifact
## the Aura's creature with its abilities; one younger than the Song finds
## the Song's creature and adds nothing.
##
## THE RIDER — "if this enchantment leaves the battlefield, this effect
## continues until end of turn" — is the same three statics, handed to
## ContinuousEffects as FLOATING ones (add_floating_static) by the
## immediate leave hook (CardData.as_it_leaves). A trigger cannot express
## it: a trigger resolves off the stack, by which time recalculate() has
## already recomputed the world without the Song and there is nothing left
## to continue. The hook runs at the instant the Song leaves, whichever
## exit it takes — destroyed, exiled, bounced or anted. The continuing
## effect keeps the Song's own timestamp (CR 613.7a; gap review 2026-11-10,
## r2-2 — it used to take a new one): a Humility that arrived after the
## Song is still the newer effect, and a Jump cast after the Song keeps the
## Tome flying once the Song is gone.
##
## The continuation is the ABILITY, not a snapshot of what it was doing.
## CR 611.3a: a continuous effect from a static ability is never locked in,
## and the printed rider lifts CR 611.3b (the source's presence) and
## nothing else — so an artifact that arrives LATER in the same turn is
## animated too, exactly as it would have been with the Song still on the
## table. mage-go reads it the same way (cards/antiquities/enchantments.go
## re-registers `AnimateArtifact(ForAll(EndOfTurn))` on leave).

const KEY := &"song"


func build() -> CardData:
	return CardData.new("Titania's Song", "{3}{G}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(_animate_every_artifact()) \
		.static_ability(_silence_every_animated_artifact()) \
		.static_ability(_size_every_animated_artifact()) \
		.as_it_leaves(_linger) \
		.oracle("Each noncreature artifact loses all abilities and becomes an artifact "
			+ "creature with power and toughness each equal to its mana value. If this "
			+ "enchantment leaves the battlefield, this effect continues until end of turn.")


## The card's three statics, built here rather than inline so the leave hook
## can hand the very same abilities to the floating registry.
static func _animate_every_artifact() -> StaticAbility:
	return StaticAbility.new(
		_apply, "Each noncreature artifact becomes an artifact creature.") \
		.changing_types().part_of(KEY)


static func _silence_every_animated_artifact() -> StaticAbility:
	return StaticAbility.new(
		_silence, "Each artifact it animated loses all abilities.") \
		.silencing_abilities().part_of(KEY)


static func _size_every_animated_artifact() -> StaticAbility:
	return StaticAbility.new(
		_size,
		"Each artifact it animated has power and toughness each equal to its "
		+ "mana value.") \
		.setting_base_pt().part_of(KEY)


## Layer 4: every artifact that is no creature as this applies.
static func _apply(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if not inst.is_type(Mtg.CardType.ARTIFACT) or inst.is_creature():
			continue
		inst.cur_types |= Mtg.CardType.CREATURE
		game.continuous.lock_in(source, KEY, inst)


## Layer 6: the artifacts [method _apply] animated lose all abilities —
## the flag only (the StaticAbility.silencing_abilities contract); the
## engine strips the rest at the Song's timestamp.
static func _silence(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if game.continuous.locked_in(source, KEY, inst):
			inst.cur_abilities_silenced = true


## Layer 7b: the size of every artifact [method _apply] animated.
static func _size(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if not game.continuous.locked_in(source, KEY, inst):
			continue
		var mv := inst.data.cost.mana_value()
		inst.cur_power = mv
		inst.cur_toughness = mv


## "If this enchantment leaves the battlefield, this effect continues until
## end of turn." The Song is already off the battlefield here and its own
## floating effects have been dropped (CR 400.7); MtgGame recalculates the
## moment this returns, so the board never shows a frame without the
## animation. A second Song still on the table changes nothing — the two
## effects are idempotent and the survivor keeps applying its own. The
## continuing effect keeps the Song's timestamp (CR 613.7a).
static func _linger(game: MtgGame, source: CardInstance, _controller: int,
		_parting: Dictionary) -> void:
	var stamp := source.layer_timestamp
	for ability in [_animate_every_artifact(), _silence_every_animated_artifact(),
			_size_every_animated_artifact()]:
		game.continuous.add_floating_static(source, ability,
			ContinuousEffects.Duration.END_OF_TURN, -1, false, -1, {}, stamp)
	game.log_line("Titania's Song lingers until end of turn")
