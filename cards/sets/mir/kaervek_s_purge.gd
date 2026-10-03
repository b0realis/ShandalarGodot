extends CardScript
## Kaervek's Purge — {X}{B}{R} — Sorcery (uncommon, mir).
## Oracle: Destroy target creature with mana value X. If that creature dies this way, Kaervek's Purge deals damage equal to the creature's power to the creature's controller.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Kaervek's Purge", "{X}{B}{R}", Mtg.CardType.SORCERY)
	c.oracle("Destroy target creature with mana value X. If that creature dies this way, Kaervek's Purge deals damage equal to the creature's power to the creature's controller.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
