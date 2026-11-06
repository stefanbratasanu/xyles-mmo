# Steel Strike effect

The metallic slash/impact is an edited version of the CC0 `Sword1` sample by
NextSoft01 from Effekseer 1.80.7. Its three nodes have been named and retimed
for this attack, with six small impact particles. `SteelStrike.efkproj` is the
editable source and `SteelStrike.efkefc` is its Effekseer 1.80.7 export. The
two `Texture` images come from the same CC0 sample. Attribution: Effekseer and
NextSoft01 (sample license: CC0).

The game emits the effect at the target on the committed hit frame using the
guarded `EffekseerEmitter3D` path in `scripts/combat_effects.gd`.
