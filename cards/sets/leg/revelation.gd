extends CardScript
## Revelation — {G} — World Enchantment — (leg, rare)
## Oracle: Players play with their hands revealed.
##
## Implementation: like Field of Dreams, a pure information effect with no
## hidden information to reveal in a headless engine. It is a real WORLD
## enchantment, so it fights the rest of the Legends world cycle (CR
## 704.5k) — which is the whole of its mechanical presence here.


func build() -> CardData:
	return CardData.new("Revelation", "{G}", Mtg.CardType.ENCHANTMENT) \
		.with_supertypes(Mtg.Supertype.WORLD) \
		.oracle("Players play with their hands revealed.")
