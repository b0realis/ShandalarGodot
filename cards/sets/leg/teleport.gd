extends CardScript
## Teleport — {U}{U}{U} — Instant — (leg, rare)
## Oracle: Cast this spell only during the declare attackers step. Target
##         creature can't be blocked this turn.
##
## Implementation: a keyword-granting PumpEffect handing out UNBLOCKABLE
## for the turn, behind the printed casting restriction ("only during the
## declare attackers step") via CardData.castable_only_when.


func build() -> CardData:
	return CardData.new("Teleport", "{U}{U}{U}", Mtg.CardType.INSTANT) \
		.castable_only_when(_declare_attackers_only) \
		.spell(PumpEffect.new(0, 0, [Mtg.Keyword.UNBLOCKABLE])) \
		.oracle("Cast this spell only during the declare attackers step. Target "
			+ "creature can't be blocked this turn.")


static func _declare_attackers_only(game: MtgGame, _pid: int) -> String:
	if game.current_step() != Mtg.Step.DECLARE_ATTACKERS:
		return "cast Teleport only during the declare attackers step"
	return ""
