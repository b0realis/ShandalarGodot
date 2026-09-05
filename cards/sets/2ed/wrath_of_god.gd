extends CardScript
## Wrath of God — {2}{W}{W} — Sorcery (2ed, rare)
## Oracle: Destroy all creatures. They can't be regenerated.
##
## Implementation: DestroyAllEffect with the default all-creatures filter
## and can_regenerate=false. Because mass destruction neither targets nor
## deals damage, protection is no defense (a pro-white Black Knight still
## dies) — that falls out of the engine's DEBT model with no special code,
## and the tests pin it.


func build() -> CardData:
	return CardData.new("Wrath of God", "{2}{W}{W}", Mtg.CardType.SORCERY) \
		.spell(DestroyAllEffect.new("all creatures", Callable(), false)) \
		.oracle("Destroy all creatures. They can't be regenerated.")
