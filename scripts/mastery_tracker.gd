extends Node
## pocv4 word progress state machine.
##
## Per-word lifecycle:
##   PHASE_A              : kills 1..3 show a ja+pronunciation popup.
##                          The 4th kill (when kill_count == 3) triggers a
##                          4-choice quiz. Correct -> MASTERED_SCHEDULED.
##                          Wrong  -> kill_count resets to 0.
##   MASTERED_SCHEDULED   : word excluded from normal spawning. Reviews are
##                          queued at absolute run_time values (first mastery
##                          time + 180s and + 300s).
##   REVIEW_DUE           : a scheduled review became due, spawner has injected
##                          (or is about to inject) one enemy of this word.
##                          Any kill triggers the quiz directly.
##   FULLY_MASTERED       : both reviews passed. Word is done.
##
## Reset on each new run.

enum State { PHASE_A, MASTERED_SCHEDULED, REVIEW_DUE, FULLY_MASTERED }

const REVIEW_INTERVALS := [180.0, 300.0]  # seconds after first mastery

var _progress: Dictionary = {}  # word_id (String) -> Dictionary

signal word_mastered(word_id: String)          # quiz correct (any stage)
signal word_fully_mastered(word_id: String)    # all reviews passed
signal word_reset(word_id: String)             # quiz wrong — back to PHASE_A

func reset_run() -> void:
	_progress.clear()

# ---------- internal helpers ----------

func _ensure(word_id: String) -> Dictionary:
	if not _progress.has(word_id):
		_progress[word_id] = {
			"state": State.PHASE_A,
			"kill_count": 0,
			"reviews_passed": 0,      # 0, 1, 2
			"pending_reviews": [],    # Array[float] of absolute run_time values
		}
	return _progress[word_id]

func _p(word_id: String) -> Dictionary:
	return _progress.get(word_id, {})

# ---------- public state queries ----------

func get_state(word_id: String) -> int:
	var d: Dictionary = _p(word_id)
	if d.is_empty():
		return State.PHASE_A
	return int(d.state)

func get_kill_count(word_id: String) -> int:
	var d: Dictionary = _p(word_id)
	return int(d.get("kill_count", 0))

## True if killing the enemy now should trigger the quiz instead of the popup.
func should_trigger_quiz_on_kill(word_id: String) -> bool:
	var d: Dictionary = _p(word_id)
	if d.is_empty():
		return false
	match int(d.state):
		State.PHASE_A:
			return int(d.kill_count) >= 3
		State.REVIEW_DUE:
			return true
		_:
			return false

## True if the word is available for normal (non-review) spawning.
func is_active_for_spawning(word_id: String) -> bool:
	var s: int = get_state(word_id)
	return s == State.PHASE_A or s == State.REVIEW_DUE

func is_fully_mastered(word_id: String) -> bool:
	return get_state(word_id) == State.FULLY_MASTERED

## Word ids currently eligible for normal enemy spawns (PHASE_A only).
func get_phase_a_ids(all_word_ids: Array) -> Array:
	var out: Array = []
	for id in all_word_ids:
		var sid: String = id
		var d: Dictionary = _p(sid)
		if d.is_empty() or int(d.state) == State.PHASE_A:
			out.append(sid)
	return out

# ---------- kill event ----------

## Called from enemy.die(). Returns a dict describing what the caller should do:
##   { "action": "popup" | "quiz", "kill_count": int, "is_review": bool }
func on_kill(word_id: String) -> Dictionary:
	if word_id == "":
		return {"action": "none"}
	var d: Dictionary = _ensure(word_id)
	match int(d.state):
		State.PHASE_A:
			if int(d.kill_count) >= 3:
				# 4th kill -> quiz
				return {"action": "quiz", "is_review": false}
			d.kill_count = int(d.kill_count) + 1
			return {"action": "popup", "kill_count": int(d.kill_count), "is_review": false}
		State.REVIEW_DUE:
			return {"action": "quiz", "is_review": true}
		_:
			# Shouldn't normally happen; fall through to popup so gameplay
			# never stalls.
			return {"action": "popup", "kill_count": int(d.get("kill_count", 0)), "is_review": false}

# ---------- quiz outcomes ----------

func mark_quiz_correct(word_id: String, run_time: float) -> void:
	if word_id == "":
		return
	var d: Dictionary = _ensure(word_id)
	var was_review: bool = int(d.state) == State.REVIEW_DUE
	if was_review:
		d.reviews_passed = int(d.get("reviews_passed", 0)) + 1
		if d.pending_reviews.is_empty() and int(d.reviews_passed) >= REVIEW_INTERVALS.size():
			d.state = State.FULLY_MASTERED
			d.kill_count = 0
			word_mastered.emit(word_id)
			word_fully_mastered.emit(word_id)
			return
		# More reviews still queued — drop back to scheduled.
		d.state = State.MASTERED_SCHEDULED
		d.kill_count = 0
		word_mastered.emit(word_id)
		return
	# First mastery: schedule the two reviews relative to now.
	d.state = State.MASTERED_SCHEDULED
	d.kill_count = 0
	d.reviews_passed = 0
	d.pending_reviews = []
	for dt in REVIEW_INTERVALS:
		d.pending_reviews.append(run_time + float(dt))
	word_mastered.emit(word_id)

func mark_quiz_wrong(word_id: String) -> void:
	if word_id == "":
		return
	var d: Dictionary = _ensure(word_id)
	d.state = State.PHASE_A
	d.kill_count = 0
	d.reviews_passed = 0
	d.pending_reviews = []
	word_reset.emit(word_id)

# ---------- review scheduling ----------

## Returns the word_id of a single word whose earliest pending review is due,
## or "" if none. Moves that word into REVIEW_DUE state and pops the timestamp
## off its pending list. The spawner should then spawn one enemy of this word.
func pop_due_review(run_time: float) -> String:
	var best_id: String = ""
	var best_time: float = INF
	for id in _progress.keys():
		var d: Dictionary = _progress[id]
		if int(d.state) != State.MASTERED_SCHEDULED:
			continue
		if d.pending_reviews.is_empty():
			continue
		var t: float = float(d.pending_reviews[0])
		if t <= run_time and t < best_time:
			best_time = t
			best_id = id
	if best_id == "":
		return ""
	var d: Dictionary = _progress[best_id]
	d.pending_reviews.pop_front()
	d.state = State.REVIEW_DUE
	return best_id

## Total words that have entered PHASE_A at least once.
func total_touched_count() -> int:
	return _progress.size()

## "Mastered" as shown to the player = passed at least the first quiz.
## This is what ticks the HUD counter up and gates the clear condition.
## Reviews still happen as spaced repetition reminders but are not required
## for clear — otherwise a 20-word run would need 15+ minutes of review
## waiting to terminate.
func is_mastered(word_id: String) -> bool:
	var s: int = get_state(word_id)
	return s == State.MASTERED_SCHEDULED \
		or s == State.REVIEW_DUE \
		or s == State.FULLY_MASTERED

func mastered_count() -> int:
	var n: int = 0
	for id in _progress.keys():
		if is_mastered(id):
			n += 1
	return n

func fully_mastered_count() -> int:
	var n: int = 0
	for id in _progress.keys():
		if int(_progress[id].state) == State.FULLY_MASTERED:
			n += 1
	return n

## True if every word in the provided pool has passed at least the first
## quiz (MASTERED_SCHEDULED or beyond).
func all_mastered(all_word_ids: Array) -> bool:
	if all_word_ids.is_empty():
		return false
	for id in all_word_ids:
		if not is_mastered(id):
			return false
	return true
