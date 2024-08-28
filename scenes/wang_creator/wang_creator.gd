class_name WangConverter extends Control

enum TileType {
	BORDER,
	INNER_CORNER,
	OUTER_CORNER,
	EDGE_CONNECTOR,
	FILL
}

@onready var file_dialog: FileDialog = $file_dialog;
@onready var tile_type_button_outer_corner: TextureButton = %tile_type_button_outer_corner
@onready var tile_type_button_edge_connector: TextureButton = %tile_type_button_edge_connector
@onready var tile_type_button_inner_corner: TextureButton = %tile_type_button_inner_corner
@onready var tile_type_button_border: TextureButton = %tile_type_button_border
@onready var tile_type_button_fill: TextureButton = %tile_type_button_fill
@onready var lbl_tile_size: Label = %lbl_tile_size
@onready var lbl_tile_set_size: Label = %lbl_tile_set_size
@onready var btn_export: Button = %btn_export
@onready var texture_preview: TextureRect = %texture_preview;


var orig_icons := {
	TileType.BORDER: preload("res://sprites/icon_border.png") as Texture2D,
	TileType.INNER_CORNER: preload("res://sprites/icon_inner_corner.png") as Texture2D,
	TileType.OUTER_CORNER: preload("res://sprites/icon_outer_corner.png") as Texture2D,
	TileType.FILL: preload("res://sprites/icon_fill.png") as Texture2D,
	TileType.EDGE_CONNECTOR: preload("res://sprites/icon_edge_connector.png") as Texture2D,
};


var placement_dict := {
	TileType.BORDER: {
		Vector2i(1, 0): 0,
		Vector2i(3, 0): 1,
		Vector2i(1, 2): 3,
		Vector2i(3, 2): 2
	},
	TileType.INNER_CORNER: {
		Vector2i(2, 0): 1,
		Vector2i(1, 1): 0,
		Vector2i(3, 1): 2,
		Vector2i(2, 2): 3
	},
	TileType.OUTER_CORNER: {
		Vector2i(0, 0): 0,
		Vector2i(0, 2): 2,
		Vector2i(3, 3): 1,
		Vector2i(1, 3): 3,
	},
	TileType.EDGE_CONNECTOR: {
		Vector2i(0, 1): 0,
		Vector2i(2, 3): 3
	},
	TileType.FILL: {
		Vector2i(2, 1): 0
	},
}

const VALID_EXTENSIONS := [
	"png",
	"jpg",
	"webp"
];

var filter_extensions: PackedStringArray;
var regex_pattern;
var save_state := false; 
var current_texture_type: TileType;
var texture_dict := {}; #[TileType]: Texture2D;
var button_dict := {}; #[TileType]: TileTypeButton;
var generated_texture: ImageTexture;
var current_texture: Texture2D;


func _ready() -> void:
	button_dict[TileType.BORDER] = tile_type_button_border;
	button_dict[TileType.INNER_CORNER] = tile_type_button_inner_corner;
	button_dict[TileType.OUTER_CORNER] = tile_type_button_outer_corner;
	button_dict[TileType.FILL] = tile_type_button_fill;
	button_dict[TileType.EDGE_CONNECTOR] = tile_type_button_edge_connector;
	
	EditorSignals.export_texture.connect(_on_export_texture);
	EditorSignals.new_texture.connect(_on_new_texture);
	EditorSignals.show_texture_file_dialog.connect(_on_show_texture_file_dialog);
	_init_form();
	
	for valid_extension: String in VALID_EXTENSIONS:
		filter_extensions.append("*.%s ; %s Images" % [valid_extension, valid_extension.to_upper()]);
		
	var pattern = "";
	for i in VALID_EXTENSIONS.size():
		pattern += VALID_EXTENSIONS[i]
		if i < VALID_EXTENSIONS.size() - 1:
			pattern += "|"
	
	regex_pattern = ".+\\.(%s)$" % pattern;
	file_dialog.filters = filter_extensions;
	pass;
	

func _import_texture(path):
	var img = Image.load_from_file(path);
	if img.detect_alpha() == Image.AlphaMode.ALPHA_NONE:
		img.convert(Image.FORMAT_RGBA8);
		img.clear_mipmaps();
		
	var texture = ImageTexture.create_from_image(img);
	
	var texture_size := texture.get_size();
	lbl_tile_size.text = "Calculated Tile Size: %s" % texture_size;
	lbl_tile_set_size.text = "Calculated TileSet Size: %s" % (texture_size * 4);
	texture_dict[current_texture_type] = texture;
	button_dict[current_texture_type].texture_normal = texture;
	
	_create_preview_texture();
	
	
	btn_export.disabled = texture_dict.size() < 5;
	pass;


func _create_preview_texture():
	var original := get_current_texture() as ImageTexture;

	var preview_image := Image.create(original.get_width() * 4, original.get_height() * 4, false, Image.FORMAT_RGBA8);
	for tile_type: TileType in texture_dict.keys():
		var texture = _get_texture(tile_type) as ImageTexture;
		if texture == null:
			continue;
		
		var texture_image := texture.get_image();
		for position: Vector2i in placement_dict[tile_type].keys():
			var rotator := texture.get_image();
			var rotations := placement_dict[tile_type][position] as int;
			var sprite = Sprite2D.new();
			sprite.texture = texture;
			
			#it doesn't fucking work with looping.
			match(rotations):
				0:
					pass;
				1:
					rotator.rotate_90(CLOCKWISE);

				2: 
					rotator.rotate_90(CLOCKWISE);
					rotator.rotate_90(CLOCKWISE);

				3:
					rotator.rotate_90(COUNTERCLOCKWISE);

			preview_image.blit_rect(rotator, Rect2i(0,0, original.get_width(), original.get_height()), position * original.get_width())

	var preview_texture = ImageTexture.create_from_image(preview_image);

	texture_preview.texture = preview_texture;
	generated_texture = preview_texture;
	

func _export_texture(path: String):
	var image = generated_texture.get_image()
	if(!_has_valid_extension(path)):
		image.save_png(path);
		return;
	
	var split = path.split(".");
	var ending = split[split.size() - 1];
	match ending:
		"webp":
			image.save_webp(path, false, 1);
		"jpg":
			image.save_jpg(path, 1);
		_:
			image.save_png(path)
	pass;


#region event listener

func _on_new_texture():
	_init_form();


func _on_export_texture():
	_show_file_dialog(true);
	

func _on_show_texture_file_dialog(texture_type: TileType):
	current_texture_type = texture_type;
	_show_file_dialog(false);	
	

func _show_file_dialog(save_mode: bool):
	save_state = save_mode;
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if save_mode else FileDialog.FILE_MODE_OPEN_FILE;
	file_dialog.title = "Save File" if save_mode else "Select File";
	
	if save_mode:
		file_dialog.current_file = "exported_tile_set.png";

	
	file_dialog.show() 


func _on_file_dialog_file_selected(path: String) -> void:
	if save_state:
		_export_texture(path);
	else:
		_import_texture(path);
		
#endregion


#region helper
func _init_form():
	lbl_tile_size.text = "";
	lbl_tile_set_size.text = "";
	texture_dict.clear();
	btn_export.disabled = true;
	for key in orig_icons.keys():
		button_dict[key].texture_normal = orig_icons[key];
		
	texture_preview.texture = null;
	generated_texture = null;


func get_current_texture():
	return _get_texture(current_texture_type);

func _get_texture(tile_type: TileType):
	if texture_dict.has(tile_type):
		return texture_dict[tile_type];



func _has_valid_extension(file_name: String) -> bool:
	var regex = RegEx.new();
	var error = regex.compile(regex_pattern);
	if error != OK:
		return false;
		
	return regex.search(file_name.to_lower()) != null
	
	
#endregion
