extends CardScript
## Roots of Life — {1}{G}{G} — Enchantment (uncommon, mir).
## Oracle: As this enchantment enters, choose Island or Swamp.
##         Whenever a land of the chosen type an opponent controls becomes tapped, you gain 1 life.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Roots of Life", "{1}{G}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("As this enchantment enters, choose Island or Swamp.\nWhenever a land of the chosen type an opponent controls becomes tapped, you gain 1 life.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
