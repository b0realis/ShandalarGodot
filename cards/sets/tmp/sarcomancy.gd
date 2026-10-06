extends CardScript
## Sarcomancy — {B} — Enchantment (rare, tmp).
## Oracle: When this enchantment enters, create a 2/2 black Zombie creature token.
##         At the beginning of your upkeep, if there are no Zombies on the battlefield, this enchantment deals 1 damage to you.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sarcomancy", "{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("When this enchantment enters, create a 2/2 black Zombie creature token.\nAt the beginning of your upkeep, if there are no Zombies on the battlefield, this enchantment deals 1 damage to you.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
