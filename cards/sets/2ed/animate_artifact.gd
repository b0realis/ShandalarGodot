extends CardScript
## Animate Artifact — {3}{U} — Enchantment — Aura — (2ed, uncommon)
## Oracle: Enchant artifact
##         As long as enchanted artifact isn't a creature, it's an artifact
##         creature with power and toughness each equal to its mana value.
##
## Implementation: TWO statics, one per CR 613 layer (Pack 9). The
## creature TYPE is a layer-4 effect ([method StaticAbility.changing_types],
## the same pass as Kormus Bell and Living Lands), so everything after
## layer 4 sees a creature — Humility, which applies after layer 4, takes
## the animated artifact's abilities and sizes it. The SIZE is a layer-7b
## effect ([method StaticAbility.setting_base_pt]) at the Aura's timestamp,
## so it and Humility's 1/1 apply in timestamp order (CR 613.7): the later
## one wins.
##
## "As long as enchanted artifact isn't a creature" is a LIVE test
## (CONTRIBUTING.md rule 5): an artifact that something ELSE animated — a
## Jade Statue's own {2}, Titania's Song, Xenic Poltergeist — is already a
## creature, and this Aura contributes nothing. The type half reads the
## live type in layer 4, after the animations and the early silencer pass.
## The size half runs in 7b, after its own type half has already made the
## host a creature, so it asks whether the host would be one WITHOUT this
## Aura: by its own types (printed or durationless) or by an
## until-end-of-turn animation (the Statue). Known limit: an artifact a
## layer-4 STATIC or a longer animation made a creature (Titania's Song,
## Xenic Poltergeist) still gets this size — the same mana-value size those
## cards give, so only its timestamp against a Humility can differ.


static func _is_artifact(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT)


func build() -> CardData:
	return CardData.new("Animate Artifact", "{3}{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact", _is_artifact)) \
		.static_ability(StaticAbility.new(_animate,
			"As long as enchanted artifact isn't a creature, it's an artifact creature.") \
			.changing_types()) \
		.static_ability(StaticAbility.new(_size,
			"As long as enchanted artifact isn't a creature, its power and toughness are each equal to its mana value.") \
			.setting_base_pt()) \
		.oracle("Enchant artifact\nAs long as enchanted artifact isn't a creature, it's an artifact creature with power and toughness each equal to its mana value.")


static func _host(game: MtgGame, source: CardInstance) -> CardInstance:
	if source.attached_to == -1:
		return null
	var host := game.find_instance(source.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return null
	return host


## Layer 4: the creature type, while the host is not a creature already.
static func _animate(game: MtgGame, source: CardInstance) -> void:
	var host := _host(game, source)
	if host == null or host.is_creature():
		return
	host.cur_types |= Mtg.CardType.CREATURE


## Layer 7b: the size, on a host this Aura animated.
static func _size(game: MtgGame, source: CardInstance) -> void:
	var host := _host(game, source)
	if host == null or not host.is_creature() or _creature_without_aura(game, host):
		return
	var size := host.data.cost.mana_value()
	host.cur_power = size
	host.cur_toughness = size


static func _creature_without_aura(game: MtgGame, host: CardInstance) -> bool:
	return ((host.data.types | host.added_types) & Mtg.CardType.CREATURE) != 0 \
		or game.continuous.creature_until_end_of_turn(host.id)
