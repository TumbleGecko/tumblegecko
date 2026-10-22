#!/usr/bin/env bash
# name:     qBittorrent
# summary:  Installs qBittorrent for downloading torrents.
# default:  on
# group:    Internet
#
# It comes from repo-oss

task() {
	want::packages --no-recommends qbittorrent
}
