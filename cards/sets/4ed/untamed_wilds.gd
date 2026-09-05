extends CardScript
## Untamed Wilds — {2}{G} — Sorcery — (4ed, uncommon)
## Oracle: Search your library for a basic land card, put that card onto
##         the battlefield, then shuffle.
##
## Implementation: SearchLibraryEffect's to-battlefield variant — the
## found land arrives through the normal entry path (summoning sickness
## and all; it's an EXTRA land beyond the one-per-turn limit, which only
## gates play_land). Green's original ramp spell.


func build() -> CardData:
	return CardData.new("Untamed Wilds", "{2}{G}", Mtg.CardType.SORCERY) \
		.spell(SearchLibraryEffect.new("a basic land card", _is_basic_land)
			.to_battlefield()) \
		.oracle("Search your library for a basic land card, put that card onto the battlefield, then shuffle.")


static func _is_basic_land(inst: CardInstance) -> bool:
	return inst.is_land() and (inst.data.supertypes & Mtg.Supertype.BASIC)
