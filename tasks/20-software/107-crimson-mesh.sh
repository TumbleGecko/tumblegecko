#!/usr/bin/env bash
# name:     Crimson Mesh
# summary:  Installs Crimson Mesh, and opens 3D models such as glTF, FBX, OBJ and STL files in it.
# default:  on
# group:    Image software
#
# Crimson Mesh is our own project at https://github.com/Crimson-Org/crimson-mesh, followed at its newest release
# It becomes the default for every model type its own .desktop declares, read when the step runs
# Its release brings file types for FBX, COLLADA and PLY, which the desktop has none for

task() {
	want::packages libadwaita-1-0 libassimp6 libepoxy0 libgdk_pixbuf-2_0-0
	want::github_app Crimson-Org/crimson-mesh '-linux-{arch}\.tar\.gz$' crimson-mesh
	want::mime_default io.github.CrimsonOrg.CrimsonMesh.desktop '@io.github.CrimsonOrg.CrimsonMesh.desktop'
}
