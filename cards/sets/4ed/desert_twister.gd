extends CardScript
## Desert Twister — {4}{G}{G} — Sorcery — (4ed, uncommon)
## Oracle: Destroy target permanent.
##
## Implementation: green's catch-all — an unfiltered PERMANENT
## DestroyEffect. Expensive, answers anything, regeneration applies (no
## rider printed). mage-go: TargetPermanent + DestroyTargetPermanent.


func build() -> CardData:
	return CardData.new("Desert Twister", "{4}{G}{G}", Mtg.CardType.SORCERY) \
		.spell(DestroyEffect.new(
			TargetSpec.new(TargetSpec.Kind.PERMANENT, "target permanent"))) \
		.oracle("Destroy target permanent.")
