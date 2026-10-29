# Poly Haven texture sources

The following 1K texture maps are from Poly Haven and are licensed CC0:

- [Forest Ground 04](https://polyhaven.com/a/forest_ground_04), photography and processing by Rob Tuytel, minor adjustment by Rico Cilliers. `forest_ground_tinted.png` is a desaturated, green-tinted derivative of the supplied diffuse image, made to preserve the game's biome colors. `forest_ground_04-nor_gl.jpg` provides normal detail.
- [Rock Face 03](https://polyhaven.com/a/rock_face_03), photography by Dario Barresi and processing by Rico Cilliers. Its diffuse and OpenGL normal maps are shared by the Blender-built rock and stone meshes.
- [Jolcham Oak Bark 01](https://polyhaven.com/a/jolcham_oak_bark_01), by Charlotte Baglioni. Its 1K diffuse and OpenGL normal maps are used for the camp seating logs and firewood.

See [Poly Haven's CC0 license](https://polyhaven.com/license). The original diffuse is retained for reproducible tinting. Attribution is included for the team's records.

The five rock and stone GLBs contain the rock maps so they can be opened textured in Blender. Their Godot import settings discard those embedded copies because the world builder assigns the single shared rock material above; changing that import setting can create redundant extracted images.
