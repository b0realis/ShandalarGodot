extends CardScript
## Amulet of Kroog — {2} — Artifact — (4ed, common)
## Oracle: {2}, {T}: Prevent the next 1 damage that would be dealt to any
##         target this turn.
##
## Implementation: a mana-and-tap Samite Healer in artifact form —
## PreventDamageEffect(1) at any target. The classic first artifact of a
## Shandalar starter deck.


func build() -> CardData:
	return CardData.new("Amulet of Kroog", "{2}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{2}", true,
			[PreventDamageEffect.new(1).any_target()],
			"{2}, {T}: Prevent the next 1 damage to any target this turn.")) \
		.oracle("{2}, {T}: Prevent the next 1 damage that would be dealt to any target this turn.")
