extends CardScript
## Duplicity — {3}{U}{U} — Enchantment (rare, tmp).
## Oracle: When this enchantment enters, exile the top five cards of your library face down.
##         At the beginning of your upkeep, you may exile all cards from your hand face down. If you do, put all other cards you own exiled with this enchantment into your hand.
##         At the beginning of your end step, discard a card.
##         When you lose control of this enchantment, put all cards exiled with this enchantment into their owner's graveyard.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Duplicity", "{3}{U}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("When this enchantment enters, exile the top five cards of your library face down.\nAt the beginning of your upkeep, you may exile all cards from your hand face down. If you do, put all other cards you own exiled with this enchantment into your hand.\nAt the beginning of your end step, discard a card.\nWhen you lose control of this enchantment, put all cards exiled with this enchantment into their owner's graveyard.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
