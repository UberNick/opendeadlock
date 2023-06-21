/**
* Copyright (C) 2013-2014 Tggtt <tggtt at users.sourceforge.net>
* and other OpenDeadlock members.
* 
* This file is part of OpenDeadlock (Decode/Encode Tools).
*
* OpenDeadlock is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* OpenDeadlock is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with OpenDeadlock. If not, see <http://www.gnu.org/licenses/>.
*/ 

#ifndef XPM_WRITER_H
#define XPM_WRITER_H
#define COLOR_MAP_ITEM_LENGTH 18
#define XPM_EXT "xpm"
void
generateImageColorMap(uint8_t colorPalette[], char colorMap[][COLOR_MAP_ITEM_LENGTH], const size_t palette_size, const size_t matte=0);

bool
writeImage(const uint16_t width, const uint16_t height, const char filename[], const std::string fullname, char colorMap[][COLOR_MAP_ITEM_LENGTH], const size_t palette_size, uint8_t data[], const size_t matte=0);

#endif