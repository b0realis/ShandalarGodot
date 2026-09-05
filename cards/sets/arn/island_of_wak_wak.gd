extends CardScript
## Island of Wak-Wak — Land — (arn, rare)
## Oracle: {T}: Target creature with flying has base power 0 until end of
##         turn.
##
## Implementation: SetBasePowerToughnessEffect with the toughness half
## left alone (-1). Base-P/T setting lands in CR 613 layer 7b, so a Giant
## Growth cast afterwards still pumps the grounded flier — and a
## Crusade's +1/+1 still applies. A free repeatable answer to Serra
## Angel that makes no mana of its own.


func build() -> CardData:
	var flatten := SetBasePowerToughnessEffect.new(0, -1,
		TargetSpec.creature("target creature with flying", _has_flying))
	return CardData.new("Island of Wak-Wak", "", Mtg.CardType.LAND) \
		.activated(ActivatedAbility.new(
			"", true, [flatten],
			"{T}: Target creature with flying has base power 0 until end of turn.")) \
		.oracle("{T}: Target creature with flying has base power 0 until end of turn.")


static func _has_flying(inst: CardInstance) -> bool:
	return inst.has_keyword(Mtg.Keyword.FLYING)
