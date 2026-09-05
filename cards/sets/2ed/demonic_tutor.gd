extends CardScript
## Demonic Tutor — {1}{B} — Sorcery (2ed, uncommon)
## Oracle: Search your library for a card, put it into your hand, then
##         shuffle.
##
## Implementation: SearchLibraryEffect with no filter — any card. The
## controller's DecisionAgent picks (AI: best-valued card; human: the UI's
## pre-cast library picker). Restricted, and per the dos486 guide the glue
## of every powered deck — "fetch Ancestral, or the Time Walk that wins".


func build() -> CardData:
	return CardData.new("Demonic Tutor", "{1}{B}", Mtg.CardType.SORCERY) \
		.spell(SearchLibraryEffect.new("a card")) \
		.oracle("Search your library for a card, put it into your hand, then shuffle.")
