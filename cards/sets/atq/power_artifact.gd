extends CardScript
## Power Artifact — {U}{U} — Enchantment — Aura — (atq, uncommon)
## Oracle: Enchant artifact
##         Enchanted artifact's activated abilities cost {2} less to
##         activate. This effect can't reduce the mana in that cost to less
##         than one mana.
##
## Implementation: a static that rewrites the HOST's LIVE activated
## abilities with {2}-cheaper copies (ActivatedAbility.discounted) — the
## same live-abilities list Zombie Master appends to. Coloured pips are
## never touched, only the generic part. MANA abilities are rewritten too,
## because a mana ability IS an activated ability (CR 605.1a) — Celestial
## Prism's five "{2}, {T}: Add one mana of any color" cost {1} under this
## Aura.
##
## The printed FLOOR is real: *"This effect can't reduce the mana in that
## cost to less than one mana"*, passed as `discounted(2, 1)`. It is a
## floor on the whole cost, so {1}{U} still loses its generic and a {2}
## ability only falls to {1}; nothing the Aura touches ever becomes free.
##
## That does NOT disarm the card. Basalt Monolith's "{3}: Untap this
## artifact" becomes {1} while the Monolith still taps for {C}{C}{C}, so
## the classic loop nets two mana a cycle exactly as it did in 1997 — the
## floor only closes the extra line where a {2}-or-cheaper ability could be
## activated for nothing at all.


static func _is_artifact(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT)


func build() -> CardData:
	return CardData.new("Power Artifact", "{U}{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact", _is_artifact)) \
		.static_ability(StaticAbility.new(_discount_the_host,
			"Enchanted artifact's activated abilities cost {2} less to activate.")) \
		.oracle("Enchant artifact\nEnchanted artifact's activated abilities cost {2} less to activate. This effect can't reduce the mana in that cost to less than one mana.")


static func _discount_the_host(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return
	var cheaper: Array[ActivatedAbility] = []
	for ability in host.cur_activated_abilities:
		cheaper.append(ability.discounted(2, 1))
	host.cur_activated_abilities = cheaper
	var cheaper_mana: Array[ManaAbility] = []
	for mana in host.cur_mana_abilities:
		cheaper_mana.append(mana.discounted(2, 1))
	host.cur_mana_abilities = cheaper_mana
