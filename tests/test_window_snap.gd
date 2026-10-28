extends SceneTree
const Snap = preload("res://scripts/window_snap.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var bounds := Rect2(4, 12, 792, 584)
	var peer := Rect2(300, 100, 180, 140)
	var peers: Array[Rect2] = [peer]
	check(Snap.snap(Rect2(7, 15, 120, 80), bounds, []) == Vector2(4, 12), "Snaps to viewport edges")
	check(Snap.snap(Rect2(173, 110, 120, 80), bounds, peers) == Vector2(172, 100), "Snaps adjacent left edge with eight-pixel gap")
	check(Snap.snap(Rect2(492, 110, 120, 80), bounds, peers) == Vector2(488, 100), "Snaps adjacent right edge")
	check(Snap.snap(Rect2(300, 250, 120, 80), bounds, peers) == Vector2(300, 248), "Snaps below and aligns edges")
	var distant := Rect2(100, 400, 120, 80)
	check(Snap.snap(distant, bounds, peers) == distant.position, "No long-distance dragging teleport")
	var overlapping := Rect2(340, 120, 120, 80)
	var settled: Vector2 = Snap.settle(overlapping, bounds, peers)
	check(not Snap.overlaps(Rect2(settled, overlapping.size), peers), "Release resolves a direct overlap")
	check(settled == Vector2(340, 12), "Release chooses closest clear boundary")
	var narrow: Array[Rect2] = [Rect2(4, 12, 300, 584), Rect2(450, 12, 346, 584)]
	var gap_position: Vector2 = Snap.settle(Rect2(100, 200, 130, 100), bounds, narrow)
	check(gap_position == Vector2(312, 200), "Finds narrow available space exactly")
	check(not Snap.overlaps(Rect2(gap_position, Vector2(130,100)), narrow), "Narrow placement preserves gaps on both sides")
	var impossible: Array[Rect2] = [bounds]
	check(Snap.settle(Rect2(100,200,120,80),bounds,impossible) == Vector2(100,200), "Impossible arrangement remains stable")
	check(Snap.settle(Rect2(-10,-10,900,700),bounds,[]) == bounds.position, "Oversized window stays clamped")
	for i in range(20):
		check(Snap.settle(overlapping,bounds,peers)==settled,"Deterministic settling")
	_test_control_adapter()
	print("WINDOW SNAP: ",failures," failures")
	quit(failures)

func _test_control_adapter() -> void:
	var host := Control.new()
	root.add_child(host)
	var a := Panel.new(); a.position=Vector2(100,100); a.size=Vector2(120,80); host.add_child(a)
	var b := Panel.new(); b.position=Vector2(230,100); b.size=Vector2(100,80); host.add_child(b)
	var hidden := Panel.new(); hidden.position=Vector2(90,90); hidden.size=Vector2(500,500); hidden.hide(); host.add_child(hidden)
	check(Snap.for_control(a,Vector2(800,600),[a,b,hidden],true)==Vector2(102,100),"Adapter ignores self and hidden windows")
	host.free()
