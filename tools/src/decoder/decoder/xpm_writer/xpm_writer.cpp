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

#include <stdio.h>
#include <fstream>
#include <sstream>
#include <string>
#ifndef __STDC_LIMIT_MACROS
#define __STDC_LIMIT_MACROS
#endif
#include <stdint.h>
#include "xpm_writer.h"

void
generateImageColorMap(uint8_t colorPalette[], char colorMap[][COLOR_MAP_ITEM_LENGTH], const size_t palette_size, const size_t matte)
{
  const char transparent[] = "%02x s mask c none";
  for (size_t bytes (0); bytes < palette_size; bytes++)
  {  
    char * colorStr =  colorMap[bytes];
    sprintf(colorStr, "%02x c #%02x%02x%02x", bytes,colorPalette[(bytes*4)+1],colorPalette[(bytes*4)+2],colorPalette[(bytes*4)+3]);
  }  
  sprintf(colorMap[matte],transparent, matte);  
}



bool
writeImage(const uint16_t width, const uint16_t height, const char filename[], const std::string fullname, char colorMap[][COLOR_MAP_ITEM_LENGTH], const size_t palette_size, uint8_t data[], const size_t matte)
{
    if ((palette_size) <= (UINT8_MAX+1))
    {
      std::ofstream outfile;
      outfile.open (fullname.c_str(),std::ios::out);
      outfile << "/* XPM */" << std::endl;
      outfile << "/* By Tggtt's Decoder - XPM edition */" << std::endl;
      outfile << "static char * i"<< filename << "[] = {" << std::endl;
      outfile << "/* <Values> */" << std::endl;
      outfile << "/* <width/cols> <height/rows> <colors> <char on pixel>*/" << std::endl;
      outfile << '"' << width << ' ' << height << ' '  << palette_size << ' ' << 2 << '"'<<',' << std::endl;
      outfile << "/* <Colors> */" << std::endl;
      for (size_t bytes(0); bytes < palette_size ; bytes++)
      {
	outfile << '"' << colorMap[bytes] << '"' << ',' << std::endl;
      }
      outfile << "/* <Pixels> */" << std::endl;
      
      size_t pos(0);
      for (size_t col(0); col < height;)
      {
	outfile << '"';
	for (size_t row(0); row < width; row++ )
	{
	  uint8_t pix = data[pos];	
	  pos++;
	  char pixstr[3];
	  sprintf(pixstr,"%02x",pix);
	  outfile << pixstr;
	}
	outfile << '"';
	col++;
	if (col < height)
	{
	  outfile << ',';
	}
	outfile << std::endl;
      }
      outfile << "};"  << std::endl;
      outfile.close();
      return true;
    }
    else
    {
      return false;
    }
}
