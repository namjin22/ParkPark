--!strict

return {
	Models = {
		Entrance = "RuinedEntrance",
		Carousel = "BrokenCarousel",
		Debris = "EntranceDebris",
		Teacups = "TeacupsRide",
	},
	EntranceSign = "SignPanel",
	CarouselStates = {
		NeglectedCanopy = "CanopyNeglected",
		RestoredCanopy = "CanopyRestored",
	},
	-- Palette textures for the authored meshes (see assets/models/parkpark/MeshAssets.json).
	-- The game shows Neglected until an area is restored; an empty Neglected skips the swap.
	Palettes = {
		Restored = "rbxassetid://101072742922175",
		Neglected = "rbxassetid://126600526194678",
	},
}
