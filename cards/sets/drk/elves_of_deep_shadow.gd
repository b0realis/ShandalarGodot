extends CardScript
## Elves of Deep Shadow — {G} — Creature — Elf Druid — 1/1 — (drk, uncommon)
## Oracle: {T}: Add {B}. This creature deals 1 damage to you.
##
## Implementation: a ManaAbility with a SIDE EFFECT — the damage is part
## of the mana ability itself (it never uses the stack, CR 605.3b), so it
## lands the instant the mana is produced, even mid-payment. Llanowar
## Elves' evil twin: green mana costs, black mana out, one life a turn.


func build() -> CardData:
	return CardData.new("Elves of Deep Shadow", "{G}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["elf", "druid"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.B).with_side_effect(_sting)) \
		.oracle("{T}: Add {B}. This creature deals 1 damage to you.")


static func _sting(game: MtgGame, source: CardInstance, controller: int) -> void:
	game.deal_damage(source, TargetRef.player(controller), 1)
