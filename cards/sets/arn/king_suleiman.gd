extends CardScript
## King Suleiman — {1}{W} — Creature — Human Noble — 1/1 — (arn, rare)
## Oracle: {T}: Destroy target Djinn or Efreet.
##
## Implementation: subtype-hate on a stick — a tap-activated DestroyEffect
## filtered to the two genie tribes (live subtypes).


func build() -> CardData:
	var spec := TargetSpec.creature("target Djinn or Efreet", _genie)
	return CardData.new("King Suleiman", "{1}{W}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["human", "noble"]) \
		.activated(ActivatedAbility.new(
			"", true,
			[DestroyEffect.new(spec)],
			"{T}: Destroy target Djinn or Efreet.")) \
		.oracle("{T}: Destroy target Djinn or Efreet.")


static func _genie(inst: CardInstance) -> bool:
	return inst.has_subtype("djinn") or inst.has_subtype("efreet")
