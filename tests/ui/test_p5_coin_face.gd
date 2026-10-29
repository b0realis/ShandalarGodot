extends GutTest
## THE COIN'S FACE, READ BACK FROM 1997 (the polish pass, 2026-10-28).
##
## The ledger's open check: *"Coin face 'heads = your seat' was never
## checked against the decompilation."* It is checked now, and 1997 says
## the opposite. In the Shandalar 1.3 decompilation
## (`run_duel_coin_flip_dialogs`, SHANDALAR 0x00535090 / MAGIC 0x004996d0):
##
##     if (coin_flip(starting_player_value, ...) == 0) coin_winner = 1;
##     else                                             coin_winner = 0;
##
## and `coin_flip` (SHANDALAR 0x0053f510) returns the face it showed —
## result 0 is `@DIALOG_COINFLIP`'s first line, "Coin flip results:
## Heads", and `COINTOSS_Heads.AVI` (its dialog proc, SHANDALAR
## 0x0053f72a; the retail DUEL.EXE's proc at 004492ad picks the Heads movie
## on the same zero). `coin_winner` 1 is the computer — the play-or-draw
## dialog names the opponent for it and lets the AI choose. So in a 1997
## duel HEADS IS THE OTHER SEAT'S WIN and TAILS IS YOURS. Over a network
## the host wins on Tails and the guest on Heads, on both screens; this
## game's tables have no host seat, so the face is read from the seat the
## screen is drawn for — which in every single-player duel is 1997's
## exactly.


func test_tails_is_your_win_as_1997_shows_it() -> void:
	assert_eq(CoinToss.result_face(0, 0), CoinToss.TAILS,
		"you (seat 0) won the toss: 1997 shows Tails")
	assert_eq(CoinToss.result_line(0, 0), "Coin flip results: Tails")


func test_heads_is_the_other_seats_win() -> void:
	assert_eq(CoinToss.result_face(1, 0), CoinToss.HEADS,
		"the computer won the toss: 1997 shows Heads")
	assert_eq(CoinToss.result_line(1, 0), "Coin flip results: Heads")


func test_the_face_follows_the_seat_the_screen_serves() -> void:
	# A human sitting in seat 1 (the screen's `_human_seat`) is the "you"
	# of the 1997 dialog, as seat 0 is everywhere else.
	assert_eq(CoinToss.result_face(1, 1), CoinToss.TAILS)
	assert_eq(CoinToss.result_face(0, 1), CoinToss.HEADS)


func test_the_movie_is_the_face_the_caption_names() -> void:
	# The movie and the caption are one fact: the film played is the face
	# named under it (the 1997 proc picks both off the same result).
	for winner in 2:
		for seat in 2:
			var face := CoinToss.result_face(winner, seat)
			assert_eq(CoinToss.result_line(winner, seat), CoinToss.RESULT_LINES[face])
			assert_eq(String(CoinToss.VIDEO_KEYS[face]),
				"coin_toss_tails" if face == CoinToss.TAILS else "coin_toss_heads")
