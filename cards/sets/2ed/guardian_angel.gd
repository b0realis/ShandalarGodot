extends CardScript
## Guardian Angel — {X}{W} — Instant — (2ed, common)
## Oracle: Prevent the next X damage that would be dealt to any target this
##         turn. Until end of turn, you may pay {1} any time you could cast
##         an instant. If you do, prevent the next 1 damage that would be
##         dealt to that permanent or player this turn.
##
## 1997 (`Duel.hlp`, Tier 1): "Prevent X damage to target creature or
## player. Until end of turn, for each {1} you pay, you may prevent 1
## damage to that creature or player." The original kept the rider as a
## floating effect (`fx_guardian_angel_903`, 0x457860) that the damage
## prevention step offered through `@GUARDIAN_EFFECT` (`promptsX1.txt`):
## "Select a damage card." / "Illegal target (damage must be on target of
## Guardian Angle)." — pay {1}, point at a damage card on the Angel's
## target, one point comes off it. Manalink's `card_guardian_angel`
## (0x474D90) is the same code; mage-go still marks the rider "XXX:
## missing".
##
## Implementation: PreventDamageEffect with X at any target, plus
## `.with_paid_rider()` — resolution grants the seat a permission
## (MtgPlayer.paid_prevention, the Channel shape) that
## MtgGame.pay_for_prevention spends: {1} for one more point in the same
## prevention pool the X filled, any time the controller has priority
## (the 1997 prevention step included; never the regeneration step),
## without using the stack. Granted even at X = 0; forgotten at cleanup,
## and dropped early if the permanent leaves the battlefield (CR 400.7).
## The AI buys exactly the points that keep a creature alive or itself
## above its panic line (AiPlayer._buy_prevention). Lifted 2026-09-02.


func build() -> CardData:
	return CardData.new("Guardian Angel", "{X}{W}", Mtg.CardType.INSTANT) \
		.spell(PreventDamageEffect.new(0).any_target().x_amount().with_paid_rider()) \
		.oracle("Prevent the next X damage that would be dealt to any target this turn. Until end of turn, you may pay {1} any time you could cast an instant. If you do, prevent the next 1 damage that would be dealt to that permanent or player this turn.")
