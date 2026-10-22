#!/usr/bin/env bash
# name:     D
# summary:  Installs the D compiler and dub, the serve-d and DCD language servers, caches raylib-d and adds D and raylib-d projects to Dolphin's Create New menu.
# default:  on
#
# dmd alone cannot build anything here, checked 2026-05-26
# phobos-devel holds object.di, phobos-devel-static the libphobos2.a dub links, and dmd links through cc from gcc
#
# serve-d's stable release publishes no checksum, so it is the one download here trusted on HTTPS alone
# raylib-d is fetched into dub's cache so a new raylib project builds without waiting
#
# The raylib-d version comes from the D package registry when the file is written, so new projects start on the newest

raylib_d_cached() {
	compgen -G "${HOME}/.dub/packages/raylib-d/*" >/dev/null
}

fetch_raylib_d() {
	dub fetch raylib-d
}

TEMPLATES="${HOME}/Templates"
D_PROJECT="${TEMPLATES}/.source/d-project"
RAYLIB_PROJECT="${TEMPLATES}/.source/raylib-d-project"

d_dub_json() {
	jq -n --arg author "${USER}" '{name: "myproject", description: "A D project.", authors: [$author], license: "MIT",
		targetType: "executable", targetPath: "build", targetName: "myproject"}'
}

raylib_dub_json() {
	local raylib_version
	raylib_version="$(curl -fsS https://code.dlang.org/api/packages/raylib-d/latest | jq -r .)" || return 1
	d_dub_json | jq --arg version "~>${raylib_version}" \
		'.description = "A raylib-d project." | .dependencies = {"raylib-d": $version}'
}

d_main() {
	cat <<'D'
import std.stdio;

void main() {
	writeln("Hello, World!");
}
D
}

raylib_main() {
	cat <<'D'
import raylib;

void main() {
	validateRaylibBinding();
	enum width = 800;
	enum height = 450;
	InitWindow(width, height, "Hello, raylib");
	SetTargetFPS(60);
	scope(exit) CloseWindow();

	while (!WindowShouldClose()) {
		BeginDrawing();
		scope(exit) EndDrawing();
		ClearBackground(Colors.RAYWHITE);
		DrawText("Hello, raylib", 250, 200, 28, Colors.DARKGRAY);
	}
}
D
}

d_gitignore() {
	printf '%s\n' .dub/ build/ '*.o' '*.obj' '*.lst' __dummy.html docs.json docs/
}

raylib_gitignore() {
	d_gitignore
	printf '%s\n' '# raylib library dropped by dub run raylib-d:install' 'libraylib.*' raylib.dll
}

task() {
	want::packages --no-recommends dmd dub phobos-devel phobos-devel-static gcc
	want::github_programs Pure-D/serve-d 'linux-{arch}\.tar\.xz$' "${HOME}/.local/bin" serve-d --no-checksum
	want::github_programs dlang-community/DCD '^dcd-v[0-9.]+-linux-{arch}\.tar\.gz$' "${HOME}/.local/bin" \
		dcd-server dcd-client
	want::step "Cache raylib-d for dub" network raylib_d_cached fetch_raylib_d
	want::file "${D_PROJECT}/dub.json" d_dub_json
	want::file "${D_PROJECT}/source/app.d" d_main
	want::file "${D_PROJECT}/.gitignore" d_gitignore
	want::file "${RAYLIB_PROJECT}/dub.json" raylib_dub_json
	want::file "${RAYLIB_PROJECT}/source/app.d" raylib_main
	want::file "${RAYLIB_PROJECT}/.gitignore" raylib_gitignore
	want::dolphin_template "D Project" d-project "Empty dub project"
	want::dolphin_template "Raylib D Project" raylib-d-project "dub project with a raylib window"
}
