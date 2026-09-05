extends CardScript
## Standing Stones — {3} — Artifact — (drk, uncommon)
## Oracle: {1}, {T}, Pay 1 life: Add one mana of any color.
##
## Implementation: five ManaAbilities (one per colour, picked by ability
## index the way a dual land's are), each carrying the {1} floating-mana
## cost and the 1-life cost. Net: a colour filter that costs a life every
## turn. Being mana abilities they are stackless and usable mid-payment.


func build() -> CardData:
	var data := CardData.new("Standing Stones", "{3}", Mtg.CardType.ARTIFACT)
	for color in Mtg.WUBRG:
		data.mana(ManaAbility.new(color).with_mana_cost("{1}").with_life_cost(1))
	return data.oracle("{1}, {T}, Pay 1 life: Add one mana of any color.")
