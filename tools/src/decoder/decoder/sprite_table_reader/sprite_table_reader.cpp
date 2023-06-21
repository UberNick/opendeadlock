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

#include <string>
#include <stdint.h>
#include <fstream>
#include "../sprite_info/sprite_info.h"

void
invertEndianness(uint8_t * data, const size_t dataSize)
{
  const size_t lastOffset(dataSize-1);
  for (size_t i(0); i < dataSize; i++)
  {
      const uint8_t aux (data[i]);
      data[i] = data[lastOffset-i];
      data[lastOffset-i] = aux;
  }
}


void
invertEndianness(spriteinfo_t & spriteinfo)
{
    invertEndianness((uint8_t *)(&spriteinfo.width),sizeof(spriteinfo.width));
    invertEndianness((uint8_t *)(&spriteinfo.height),sizeof(spriteinfo.height));
    invertEndianness((uint8_t *)(&spriteinfo.x),sizeof(spriteinfo.x));
    invertEndianness((uint8_t *)(&spriteinfo.y),sizeof(spriteinfo.y));
    invertEndianness((uint8_t *)(&spriteinfo.offset),sizeof(spriteinfo.offset));
    invertEndianness((uint8_t *)(&spriteinfo.padding),sizeof(spriteinfo.padding));
}

void
readRawSpriteTableFile(std::ifstream & inputFile, const size_t length, const bool invert, spriteinfo_t rawdataoutput[])
{
    const std::streamsize readBlockSize(length * sizeof(spriteinfo_t));
    
    char * s ((char *)(rawdataoutput));
    inputFile.readsome(s,readBlockSize);
    
    if (invert)
    {
      size_t pos(0);    
      while (pos < length)
      {
	spriteinfo_t * current (&(rawdataoutput[pos]));      
	pos++;

	invertEndianness(*current);
      }
    }
}

bool
openRawSpriteTableFile(const std::string & fileName, const size_t start, const size_t length, const bool invert, spriteinfo_t * rawdataoutput[])
{
    std::ifstream is(fileName.c_str()); 
    is.seekg (0, is.end);
    size_t fileLength (is.tellg());
   
    bool success(true);
    
    if (
         (fileLength > (start + (length*sizeof(spriteinfo_t))))
       )
    {
      is.seekg (start, is.beg);
      
      *rawdataoutput = new spriteinfo_t[length];
      
      readRawSpriteTableFile(is, length, invert, *rawdataoutput);
    }
    else
    {
      success = false;
    }
    is.close();              
    
    return success;
}