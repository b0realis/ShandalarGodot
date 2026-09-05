extends CardScript
## Circle of Protection: Artifacts — {1}{W} — Enchantment — (4ed, uncommon)
## Oracle: {2}: The next time an artifact source of your choice would deal
##         damage to you this turn, prevent that damage.
##
## Implementation: the CoP cycle's sixth member, keyed on a SOURCE
## PREDICATE instead of a colour (PreventDamageShieldEffect.from_sources)
## — artifacts have no colour to match. Two mana per shield instead of
## one, because in an artifact field it answers everything.


func build() -> CardData:
	return CardData.new("Circle of Protection: Artifacts", "{1}{W}",
			Mtg.CardType.ENCHANTMENT) \
		.activated(ActivatedAbility.new(
			"{2}", false,
			[PreventDamageShieldEffect.new(0).from_sources("an artifact source", _is_artifact)],
			"{2}: Prevent the next damage from an artifact source to you this turn.")) \
		.oracle("{2}: The next time an artifact source of your choice would deal "
			+ "damage to you this turn, prevent that damage.")


## "An ARTIFACT source" is what the source IS when it would deal the damage
## (CR 109.5), so the live type mask answers it — a creature Ashnod's
## Transmogrant or Titania's Song turned into an artifact is an artifact
## source. Scarecrow's shield filter (`drk/scarecrow.gd`) reads live too.
static func _is_artifact(source: CardInstance) -> bool:
	return source.is_type(Mtg.CardType.ARTIFACT)
