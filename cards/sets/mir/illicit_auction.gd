extends CardScript
## Illicit Auction — {3}{R}{R} — Sorcery (rare, mir).
## Oracle: Each player may bid life for control of target creature. You start the bidding with a bid of 0. In turn order, each player may top the high bid. The bidding ends if the high bid stands. The high bidder loses life equal to the high bid and gains control of the creature. (This effect lasts indefinitely.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Illicit Auction", "{3}{R}{R}", Mtg.CardType.SORCERY)
	c.oracle("Each player may bid life for control of target creature. You start the bidding with a bid of 0. In turn order, each player may top the high bid. The bidding ends if the high bid stands. The high bidder loses life equal to the high bid and gains control of the creature. (This effect lasts indefinitely.)")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
