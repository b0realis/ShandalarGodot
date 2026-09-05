extends CardScript
## Greater Realm of Preservation — {1}{W} — Enchantment — (leg, uncommon)
## Oracle: {1}{W}: The next time a black or red source of your choice would
##         deal damage to you this turn, prevent that damage.
##
## Implementation: a two-colour Circle of Protection — one one-shot shield
## per activation, stacking with itself exactly the way the Circles do.
## "A black or red source OF YOUR CHOICE" is named as the ability
## resolves (PreventDamageShieldEffect: "Select a black or red source."),
## and only that source is shielded — so it is activated in RESPONSE.


func build() -> CardData:
	return CardData.new("Greater Realm of Preservation", "{1}{W}",
			Mtg.CardType.ENCHANTMENT) \
		.activated(ActivatedAbility.new("{1}{W}", false,
			[PreventDamageShieldEffect.new(Mtg.ManaColor.B | Mtg.ManaColor.R)],
			"{1}{W}: The next time a black or red source of your choice would deal damage to you this turn, prevent that damage.")) \
		.oracle("{1}{W}: The next time a black or red source of your choice would deal damage to you this turn, prevent that damage.")
