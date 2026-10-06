extends CardScript
## Reconnaissance — {W} — Enchantment (uncommon, exo).
## Oracle: {0}: Remove target attacking creature you control from combat and untap it. (If you activate during end of combat, the creature will untap after it deals combat damage.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Reconnaissance", "{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{0}: Remove target attacking creature you control from combat and untap it. (If you activate during end of combat, the creature will untap after it deals combat damage.)")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
