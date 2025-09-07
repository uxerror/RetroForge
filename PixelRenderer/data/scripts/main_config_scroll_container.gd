extends ScrollContainer

const RATIO_MIN: float = 1.0
const RATIO_FOLDED: float = 0.45

@onready var render_config_foldable_container: FoldableContainer = %RenderConfigFoldableContainer

func _ready() -> void:
	render_config_foldable_container.folding_changed.connect(
		func(is_folded: bool):
			size_flags_stretch_ratio = RATIO_FOLDED if is_folded else RATIO_MIN
	)
