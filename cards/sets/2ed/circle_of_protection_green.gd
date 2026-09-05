extends CardScript
## Circle of Protection: Green — {1}{W} — Enchantment (2ed, common)
## Oracle: {1}: The next time a green source of your choice would deal
##         damage to you this turn, prevent that damage.
##
## Implementation: repeatable activated ability whose payload is a
## PreventDamageShieldEffect(green) — a one-shot, this-turn shield consumed
## by MtgGame.deal_damage. Stacks with itself; see the effect class for the
## documented source-choice simplification. The CoP cycle is the backbone
## of Shandalar's white defensive decks (and its dungeon strategy).
## One of five: see the other circle_of_protection_*.gd files.


func build() -> CardData:
	return CardData.new("Circle of Protection: Green", "{1}{W}", Mtg.CardType.ENCHANTMENT) \
		.activated(ActivatedAbility.new(
			"{1}", false,
			[PreventDamageShieldEffect.new(Mtg.ManaColor.G)],
			"{1}: Prevent the next damage from a green source to you this turn.")) \
		.oracle("{1}: The next time a green source of your choice would deal damage to you this turn, prevent that damage.")
