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

#ifdef __WITH_MAGICKPP__
#include <Magick++.h>
#ifndef __STDC_LIMIT_MACROS
#define __STDC_LIMIT_MACROS
#endif
#include <stdint.h>
#include <iostream>
#include "magick.h"

void
generateImageColorMap(uint8_t colorPalette[], Magick::Color colorMap[], const size_t palette_size, const size_t matte)
{
  for (size_t bytes (0); bytes < palette_size; bytes++)
  {  
    char scolor[10];
    sprintf(scolor, "#%02x%02x%02x",colorPalette[(bytes*4)+1],colorPalette[(bytes*4)+2],colorPalette[(bytes*4)+3]);
    colorMap[bytes] = Magick::Color(scolor);
  }
  
  //Set Matte forcefully
  colorMap[matte] = Magick::Color("#00000000");
}



bool
writeImage(const uint16_t width, const uint16_t height, const char filename[], const std::string fullname, Magick::Color colorMap[], const size_t palette_size, uint8_t data[], const size_t matte)
{
    if ((palette_size) <= (UINT8_MAX+1))
    {
      Magick::Geometry geo(width,height);

      Magick::Image magickImage; 

      magickImage.size(geo);
      magickImage.comment(std::string("By Tggtt's Decoder"));
      // Ensure that there are no other references to this image.
      magickImage.modifyImage();
      // Set the image type to indexed color.
      // Does not work with some versions.
      //magickImage.type(Magick::PseudoColorType);
      
      try
      {
	magickImage.colorMapSize(palette_size);
	magickImage.matte(true);
	magickImage.matteColor(colorMap[matte]);
	for (size_t bytes (0); bytes < palette_size; bytes++)
	{
	  magickImage.colorMap(bytes, colorMap[bytes]);
	}
	
	// set pixels from data
	{
	  size_t pos(0);
	  for (size_t y(0); y < height; y++)
	  {
	    for (size_t x(0); x < width; x++)
	    {
	      const size_t pixIndex (data[pos]);
	      // set pixel color
	      magickImage.pixelColor(x,y,colorMap[pixIndex]);
	      
	      //data position
	      pos++;
	    }
	  }
	}
	magickImage.write(fullname.c_str());

	return true;
      }
      catch (Magick::WarningCorruptImage & e)
      {
	std::cerr << "Warning: invalid image, skipping." << std::endl;
	std::cerr << "Magick++ error:" << std::endl;	
	std::cerr << e.what() << std::endl;
	return false;
      }
    }
    else
    {
      return false;
    }
}


bool
decodePaletteWithMagick(const std::string fileName, const std::string extension, uint8_t * rawdataoutput[], size_t & palette_size)
{
    try
    {
      Magick::Image paletteImage;
      paletteImage.read(fileName);
      const size_t width(paletteImage.columns());
      const size_t height(paletteImage.rows());   
      paletteImage.type(Magick::TrueColorMatteType);
      Magick::PixelPacket *pixel_cache = paletteImage.getPixels(0,0,width,height);
      const size_t paletteLength(width*height);
      uint8_t * data = new uint8_t[paletteLength*4];
      for (size_t pos(0); pos < paletteLength; pos++ )
      {	
	
	const uint8_t alpha ((UINT8_MAX+1)*((pixel_cache[pos]).opacity)/(UINT16_MAX+1));
	const uint8_t red ((UINT8_MAX+1)*((pixel_cache[pos]).red)/(UINT16_MAX+1));
	const uint8_t green ((UINT8_MAX+1)*((pixel_cache[pos]).green)/(UINT16_MAX+1));
	const uint8_t blue ((UINT8_MAX+1)*((pixel_cache[pos]).blue)/(UINT16_MAX+1));
	
	data[(pos*4)+0] = alpha;
	data[(pos*4)+1] = red;
	data[(pos*4)+2] = green;
	data[(pos*4)+3] = blue;
	
      }
      palette_size = paletteLength;
      *rawdataoutput = data;
      std::cerr << "Warning: Non binary palettes may lose data precision." << std::endl;
      return true;
    }
    catch (Magick::ErrorMissingDelegate & e)
    {
	std::cerr << "This palette input format is not supported by your ImageMagick configuration." << std::endl;
	std::cerr << "If you believe that \""<< extension <<"\" should be supported, update your ImageMagick and recompile this decoder." << std::endl;
	std::cerr << "Magick++ error:" << std::endl;	
	std::cerr << e.what() << std::endl;
	return false;
    }
    catch (Magick::WarningOption & e)
    {
	std::cerr << "This palette could not be decoded." << std::endl;
	std::cerr << "Magick++ error:" << std::endl;	
	std::cerr << e.what() << std::endl;
	return false;
    }
    catch (std::bad_alloc & e)
    {
	std::cerr << "Could not load palette into memory." << std::endl;
	return false;
    }
   
}


#endif
