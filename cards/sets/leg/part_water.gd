extends CardScript
## Part Water — {X}{X}{U} — Sorcery — (leg, uncommon)
## Oracle: X target creatures gain islandwalk until end of turn. (They
##         can't be blocked as long as defending player controls an Island.)
##
## Implementation: the doubled {X}{X} really charges twice (ManaCost.x_count),
## and the count of {X} also picks the number of targets.


func build() -> CardData:
	return CardData.new("Part Water", "{X}{X}{U}", Mtg.CardType.SORCERY) \
		.spell(GrantLandwalkEffect.new(["island"]).x_targets()) \
		.oracle("X target creatures gain islandwalk until end of turn. (They can't be blocked as long as defending player controls an Island.)")
