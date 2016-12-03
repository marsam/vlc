--[[
 $Id$

 Copyright © 2012, 2015 the VideoLAN team

 Authors: Cheng Sun <chengsun9atgmail.com>
          Pierre Ynard

 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
--]]

-- Probe function.
function probe()
    local path = vlc.path
    path = path:gsub("^www%.", "")
    return ( vlc.access == "http" or vlc.access == "https" )
        and string.match( path, "^soundcloud%.com/.+" )
end

function parse_json(url)
    vlc.msg.dbg("Trying to parse JSON from " .. url)
    local json = require ("dkjson")

    -- Use vlc.stream to grab a remote json file, place it in a string,
    -- decode it and return the decoded data.
    local stream = vlc.stream(url)
    local string = ""
    local line   = ""

    if not stream then return false end

    while true do
        line = stream:read(65536)
        if not line then break end

        string = string .. line
    end

    return json.decode(string)
end

-- Create a playlist item from a soundcloud track resource
function create_track(item, client_id)
    local url = item.downloadable and item.download_url or item.stream_url
    return { path = url .. "?client_id=" .. client_id,
             name = item.user.username .. " - " .. item.title,
             title = item.title,
             artist = item.user.username,
             date = item.created_at,
             genre = item.genre,
             arturl = item.artwork_url or item.user.avatar_url,
             rating = item.favoritings_count,
             copyright = item.license,
             description = item.description }
end

-- Parse function.
function parse()
    -- API magic
    local client_id = "WKcQQdEZw7Oi01KqtHWxeVSxNyRzgT8M"
    -- app_version is not required by the API but we send it anyway
    -- to remain unconspicuous
    local app_version = "1505226596"
    local response = parse_json(vlc.access.."://api.soundcloud.com/resolve?url="..vlc.access.."://"..vlc.path.."&_status_code_map[302]=200&_status_format=json&client_id="..client_id.."&app_version="..app_version)
    local data = parse_json(response.location)
    local playlist = {}
    if not data.kind then
        for _, track in ipairs(data) do
            table.insert(playlist, create_track(track, client_id))
        end
    elseif data.kind == "track" then
        table.insert(playlist, create_track(data, client_id))
    elseif data.kind == "user" then
        local tracks = parse_json(vlc.access.."://api.soundcloud.com/users/"..data.id.."/tracks".."?client_id="..client_id.."&app_version="..app_version)
        for _, track in ipairs(tracks) do
            table.insert(playlist, create_track(track, client_id))
        end
    elseif data.kind == "playlist" then
        for _, track in ipairs(data.tracks) do
            table.insert(playlist, create_track(track, client_id))
        end
    end
    return playlist
end
