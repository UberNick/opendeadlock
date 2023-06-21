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

#ifndef SPRITE_INFO_H
#define SPRITE_INFO_H

#include <stdint.h>

 /** spriteinfo structure,
 * Each line represents 32 bit of data.**/
 typedef
 struct spriteinfo
 {
   uint16_t width; uint16_t height;
   uint32_t padding;
   uint32_t offset;
   int16_t x; int16_t y; 
 } spriteinfo_t;

#endif