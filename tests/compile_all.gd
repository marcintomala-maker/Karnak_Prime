extends Node
## Dev: force-load every script so parse/compile errors surface in headless runs.
func _ready() -> void:
	var bad := 0
	for f in _list("res://scripts"):
		var s = load(f)
		if s == null or not (s as Script).can_instantiate():
			print("FAILED: ", f); bad += 1
	print("compile check done, failures: ", bad)
	get_tree().quit()
func _list(dir: String) -> Array:
	var out := []
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_list(dir + "/" + d))
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	return out
