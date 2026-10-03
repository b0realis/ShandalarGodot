extends CardScript
## Bounty of the Hunt — {3}{G}{G} — Instant (uncommon, all).
## Oracle: You may exile a green card from your hand rather than pay this spell's mana cost.
##         Distribute three +1/+1 counters among one, two, or three target creatures. For each +1/+1 counter you put on a creature this way, remove a +1/+1 counter from that creature at the beginning of the next cleanup step.
## Trusted optional Pack 5 implementation; ZIPs never provide scripts.
## The delayed cleanup-step effect is a trigger on the stack with a
## response window (CR 514.3a; Pack 8 lifted the old adaptation).

func build() -> CardData:
	var c := CardData.new("Bounty of the Hunt", "{3}{G}{G}", Mtg.CardType.INSTANT)
	c.oracle("You may exile a green card from your hand rather than pay this spell's mana cost.\nDistribute three +1/+1 counters among one, two, or three target creatures. For each +1/+1 counter you put on a creature this way, remove a +1/+1 counter from that creature at the beginning of the next cleanup step.")
	return load("res://cards/sets/all/_rules.gd").apply(c)
