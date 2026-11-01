# Installed race assets

Original classic Lineage 2 inspired characters generated from the project references.
Human male was rebuilt from scratch in human_male/ on 2026-11-01. The old
human_fighter/head_revision asset is retained as an inactive historical source.

| Model | Exported vertices | PBR atlas | Runtime bones |
|---|---:|---:|---:|
| human_male | 48,942 | 2048 | 55 |
| human_female | 50,175 | 2048 | 55 |
| orc_male | 49,943 | 2048 | 55 |
| orc_female | 50,371 | 2048 | 55 |
| elf_male | 50,234 | 2048 | 55 |
| elf_female | 50,589 | 2048 | 55 |
| dark_elf_male | 50,958 | 2048 | 55 |
| dark_elf_female | 50,778 | 2048 | 55 |
| dwarf_male | 50,779 | 2048 | 55 |
| dwarf_female | 49,992 | 2048 | 55 |

Each folder retains source_pbr.glb (geometry generation), provider_rig.glb
(unmodified rig export), rigged.glb (four-weight cleanup), and the Godot
body.res/character.tscn runtime assets. Texture images are embedded in GLB and
retained in the generated Godot materials. Sources use Gen-2.5-High, Quad 50000,
de-lighting enabled. The API did not supply the requested 4K maps.

Use scripts/dev/characters tools and Documentation/Characters/RACE_AND_ARMOR_WORKFLOW.md
to rebuild and fit armor. No per-bone vertex shifting or human neck shader is
applied. Runtime normal_strength=0 prevents exaggerated generated surface bumps.
The Human female cleanup additionally corrects a pale ponytail-tip artifact.

Job IDs are checkpointed in ignored logs/race_build/jobs.json; signed download
URLs and authentication tokens must never be committed. These assets are not
represented as hand-authored topology, facial rigs or simulated hair.
