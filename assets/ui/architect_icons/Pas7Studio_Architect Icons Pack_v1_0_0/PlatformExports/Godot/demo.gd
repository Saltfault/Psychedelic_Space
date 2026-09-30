extends Node2D

const EXAMPLE_TEXTURE_PATH := "res://assets/Animals/Animals/Animals.png"

func _ready() -> void:
    var title := Label.new()
    title.text = "Rust Explorer — Godot import example"
    title.position = Vector2(32, 24)
    title.add_theme_font_size_override("font_size", 24)
    add_child(title)

    var subtitle := Label.new()
    subtitle.text = "Loaded from: " + EXAMPLE_TEXTURE_PATH
    subtitle.position = Vector2(32, 64)
    add_child(subtitle)

    if EXAMPLE_TEXTURE_PATH == "res://":
        return
    var texture := load(EXAMPLE_TEXTURE_PATH) as Texture2D
    if texture == null:
        subtitle.text += " (texture unavailable)"
        return
    var sprite := Sprite2D.new()
    sprite.texture = texture
    sprite.position = Vector2(480, 300)
    sprite.scale = Vector2.ONE * min(320.0 / texture.get_width(), 320.0 / texture.get_height(), 1.0)
    add_child(sprite)
