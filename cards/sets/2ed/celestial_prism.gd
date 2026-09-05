extends CardScript
## Celestial Prism — {3} — Artifact — (2ed, uncommon)
## Oracle: {2}, {T}: Add one mana of any color.
##
## Implementation: five mana abilities, one per colour, all carrying the
## same {2} cost — the engine's way of writing "of any color" (the caller
## picks by ability index, exactly like a dual land's two choices).


func build() -> CardData:
	var prism := CardData.new("Celestial Prism", "{3}", Mtg.CardType.ARTIFACT)
	for color in Mtg.WUBRG:
		prism.mana(ManaAbility.new(color).with_mana_cost("{2}"))
	return prism.oracle("{2}, {T}: Add one mana of any color.")
