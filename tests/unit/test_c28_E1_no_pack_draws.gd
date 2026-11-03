extends GutTest
## A CAMPAIGN WITHOUT CARD PACKS DRAWS EXACTLY AS IT DID (0.60.14, the
## owner's pack rulings of 2026-11-03: "A campaign with no packs draws
## EXACTLY as today (byte-identical results for the same seed)"). The pack
## share ([PackShare]) is a second die only where a campaign has packs; a
## base-only hero's shops, duel spoils and lairs — every card drawn and the
## adventure's dice after it — are pinned here as 0.60.13 drew them, by a
## digest of each source. Every card is read off its printings (the 1997
## program's table set aside), with every pack switched off, so the digests
## hold on any machine.

## The digests 0.60.13 gave (recorded before the pack share was written).
const GOLDEN := {
	"shops": "5a8aa3b9a198a2a8e6ea964c4b39c89b",
	"spoils": "5b03d46f71a65b1b1cfce7936ccfdd56",
	"lairs": "3aa6e6adc788dfbcc96c2ae20b9f3755",
}

var _table: Variant
var _packs: Array[String] = []


func before_each() -> void:
	_packs = Settings.enabled_card_packs().duplicate()
	for id in CardPacks.available_ids():
		if CardPacks.is_enabled(id):
			CardPacks.set_enabled(id, false)
	CardRegistry.ensure_loaded()
	_table = GameSkin._meta_cache.get("adventure_cards")
	GameSkin._meta_cache["adventure_cards"] = {}
	_forget()


func after_each() -> void:
	if _table == null:
		GameSkin._meta_cache.erase("adventure_cards")
	else:
		GameSkin._meta_cache["adventure_cards"] = _table
	for id in CardPacks.available_ids():
		if CardPacks.is_enabled(id) != (id in _packs):
			CardPacks.set_enabled(id, id in _packs)
	_forget()


func _forget() -> void:
	CardValue.forget()
	CardShop.forget()
	CardTrade.forget()
	LairEvent.forget()
	AdventurePacks.forget()
	StarterDeck._cards.clear()


func _hero(seed_text: String, rule: String) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.seed_text = seed_text
	setup.card_rule = rule
	setup.packs = [] as Array[String]
	var record := setup.resolve({})
	return AdventurePlayer.begin(record, AdventureSetup.make_world(record))


## Every shop of three heroes (one per card rule), drawn on the first
## visit, and one place sold and drawn again.
func _shops() -> String:
	var out := PackedStringArray()
	for pair in [["48271", AdventurePlayer.RULE_MEANT], ["12345", AdventurePlayer.RULE_SHIPPED],
			["777", AdventurePlayer.RULE_CLASSIC]]:
		var player := _hero(pair[0], pair[1])
		var first := -1
		for slot in player.world.sites.size():
			if not int(player.world.sites[slot]["type"]) in [ShandalarWorld.VILLAGE, ShandalarWorld.TOWN, ShandalarWorld.CITY]:
				continue
			first = slot if first < 0 else first
			out.append("%d:%s|%d" % [slot, ",".join(CardShop.offers(player, slot)), player.dice])
		player.gold = 100000
		CardShop.buy(player, first, 1)
		player.quest_timer += 500
		player.last_town = -1
		out.append("again:%s|%d" % [",".join(CardShop.offers(player, first)), player.dice])
	return "\n".join(out)


## Forty duels' cards won and artifacts for the next duel, per card rule.
func _spoils() -> String:
	var out := PackedStringArray()
	for pair in [["48271", AdventurePlayer.RULE_MEANT], ["12345", AdventurePlayer.RULE_SHIPPED],
			["777", AdventurePlayer.RULE_CLASSIC]]:
		var player := _hero(pair[0], pair[1])
		for s in range(1, 41):
			var meeting := {"row": 1 + s % 50, "color": 1 + s % 5, "strength": 4 + s % 20, "creature_ante": []}
			var dice := MsvcRandom.new(s * 7919)
			var cards := DuelSpoils.reward_cards(player, meeting, dice)
			var artifact_dice := MsvcRandom.new(s)
			var artifact := DuelSpoils._random_artifact(artifact_dice, player)
			out.append("%d:%s|%d|%s|%d" % [s, ",".join(cards), dice.state, artifact, artifact_dice.state])
	return "\n".join(out)


## Forty lairs begun, and each lair's rare draws and duel hoards.
func _lairs() -> String:
	var out := PackedStringArray()
	for pair in [["48271", AdventurePlayer.RULE_MEANT], ["777", AdventurePlayer.RULE_CLASSIC]]:
		var player := _hero(pair[0], pair[1])
		for s in range(1, 41):
			player.dice = s * 104729
			player.monster_timer = s
			var event := LairEvent.begin(player, {"slot": s % 10, "color": s % 6})
			out.append("%d:%s|%s|%s|%d" % [s, event["name"], event["reward"], event["lair_rare"], player.dice])
			var dice := MsvcRandom.new(s)
			var classic := CardShop.classic_rule(player)
			out.append("  %s,%s,%s|%d" % [LairEvent.rare_of_any_kind(dice, classic, player),
				LairEvent._lair_rare(player, dice, s % 6), LairEvent._treasure(dice, s % 6, classic, player), dice.state])
			player.dice = s * 31
			var duel := LairDuels.begin(player, {"event": LairEvent.DUELS[s % 4]})
			out.append("  %s|%d|%d" % [",".join(PackedStringArray(duel["rares"])), int(duel["row"]), player.dice])
	return "\n".join(out)


func test_a_campaign_without_packs_draws_as_before() -> void:
	var got := {"shops": _shops(), "spoils": _spoils(), "lairs": _lairs()}
	for key in GOLDEN:
		var digest := String(got[key]).md5_text()
		if String(GOLDEN[key]) == "":
			gut.p("%s %s\n%s" % [key, digest, String(got[key]).left(600)])
		assert_eq(digest, GOLDEN[key], "%s: the same cards on the same dice" % key)
