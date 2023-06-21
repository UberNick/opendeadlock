/**
* Copyright (C) 2013-2015 Tggtt <tggtt at users.sourceforge.net>
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

#ifndef HDX_HPP_
#define HDX_HPP_

#include<iostream>
#include<stdint.h>
#include<stdlib.h>

 /** file record structure.
 **/
 typedef
 struct hdxfilerecord
 {
   char file_name[9];
   uint32_t offset;
   void print()
   {
     std::cout << "File Name= " << file_name << " offset= " << std::hex << offset << '.' << std::endl;
   }
 } hdxfilerecord_t;
 
static bool bigEndian(false);
 
void littleEndianOnly()
{
   uint32_t test = 0x12345678;
   uint8_t * bytes = (uint8_t*)(&test);
   // little endian.
   bool littleEndian = 
     (
	(bytes[3] == 0x12)
	&&
	(bytes[2] == 0x34)
	&&
	(bytes[1] == 0x56)
	&&
	(bytes[0] == 0x78)	
      );
   bigEndian = 
     (
	(bytes[0] == 0x12)
	&&
	(bytes[1] == 0x34)
	&&
	(bytes[2] == 0x56)
	&&
	(bytes[3] == 0x78)	
      );
   if (!littleEndian)
   {
     if (bigEndian)
     {
      std::cerr << "This tool was only tested on a little endian system. Please report the result." << std::endl;     
     }
     else
     {
       std::cerr << "Unsupported endianess. Please report what happened." << std::endl;     
       exit(-1);
     }
   }
}

void swapBytes(uint8_t * pToSwap, const size_t size)
{
  const size_t limit(size/2);
  for (size_t i(0); i < limit ; i++)
    {
      const uint8_t temp(pToSwap[i]);
      const size_t otherSide(size-(i+1));
      pToSwap[i] = pToSwap[otherSide];
      pToSwap[otherSide] = temp;
    }
}

inline void fixEndianness(uint32_t &intToSwap)
{
    if (bigEndian)
    {
      const size_t size(sizeof(intToSwap));
      uint8_t * pToSwap((uint8_t*)(&intToSwap));
      
      swapBytes(pToSwap,size);      
    }    
}

#endif // HDX_HPP_
