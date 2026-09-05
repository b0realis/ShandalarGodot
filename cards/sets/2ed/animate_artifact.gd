extends CardScript
## Animate Artifact — {3}{U} — Enchantment — Aura — (2ed, uncommon)
## Oracle: Enchant artifact
##         As long as enchanted artifact isn't a creature, it's an artifact
##         creature with power and toughness each equal to its mana value.
##
## Implementation: a base-P/T static (layer 7b) that also grants the
## CREATURE type — the same machinery Kormus Bell uses on Swamps. The
## "isn't already a creature" clause is checked live, so animating an
## artifact creature does nothing, as printed.


static func _is_artifact(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT)


func build() -> CardData:
	return CardData.new("Animate Artifact", "{3}{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact", _is_artifact)) \
		.static_ability(StaticAbility.new(_animate,
			"As long as enchanted artifact isn't a creature, it's an artifact creature with power and toughness each equal to its mana value.").setting_base_pt()) \
		.oracle("Enchant artifact\nAs long as enchanted artifact isn't a creature, it's an artifact creature with power and toughness each equal to its mana value.")


static func _animate(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return
	if host.is_creature():
		# "As long as enchanted artifact isn't a creature" is a LIVE test
		# (CONTRIBUTING.md rule 5): an artifact that something ELSE animated this
		# turn — a Jade Statue's own {2}, Titania's Song, Xenic Poltergeist
		# — is already a creature, so this Aura contributes nothing instead
		# of stamping its mana value over that body. Animations run in an
		# earlier pass of ContinuousEffects.recalculate than this
		# base-P/T static, so the live type is already settled here.
		return
	var size := host.data.cost.mana_value()
	host.cur_types |= Mtg.CardType.CREATURE
	host.cur_power = size
	host.cur_toughness = size
