extends CardScript
## Torrent of Lava — {X}{R}{R} — Sorcery (rare, mir).
## Oracle: Torrent of Lava deals X damage to each creature without flying.
##         As long as Torrent of Lava is on the stack, each creature has "{T}: Prevent the next 1 damage that would be dealt to this creature by Torrent of Lava this turn."
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Torrent of Lava", "{X}{R}{R}", Mtg.CardType.SORCERY)
	c.oracle("Torrent of Lava deals X damage to each creature without flying.\nAs long as Torrent of Lava is on the stack, each creature has \"{T}: Prevent the next 1 damage that would be dealt to this creature by Torrent of Lava this turn.\"")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
