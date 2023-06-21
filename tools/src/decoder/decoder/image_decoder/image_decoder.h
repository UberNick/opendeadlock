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

#ifndef IMAGE_DECODER_H
#define IMAGE_DECODER_H
#include <string>
#include <stdint.h>
#include "../sprite_info/sprite_info.h"

bool
decodeAllImages(uint8_t colorPalette[], const spriteinfo_t spritetable[], const size_t palette_size, const size_t table_rows, const std::string spritefilename, const std::string dirname, const std::string ext, const size_t matte);
#endif