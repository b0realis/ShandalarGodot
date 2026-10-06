extends CardScript
## Eladamri, Lord of Leaves — {G}{G} — Legendary Creature — Elf Warrior (rare, tmp).
## Oracle: Other Elf creatures have forestwalk. (They can't be blocked as long as defending player controls a Forest.)
##         Other Elves have shroud. (They can't be the targets of spells or abilities.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Eladamri, Lord of Leaves", "{G}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["elf","warrior"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.oracle("Other Elf creatures have forestwalk. (They can't be blocked as long as defending player controls a Forest.)\nOther Elves have shroud. (They can't be the targets of spells or abilities.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
