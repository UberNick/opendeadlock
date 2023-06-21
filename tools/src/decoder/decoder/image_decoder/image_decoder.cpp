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
 
#include <algorithm>
#include <stdio.h>
#include <fstream>
#include <sstream>
#include <string>
#include <iostream>
#ifndef __STDC_LIMIT_MACROS
#define __STDC_LIMIT_MACROS
#endif
#include <stdint.h>
#include "../xpm_writer/xpm_writer.h"
#include "../magick/magick.h"
#include "image_decoder.h"



inline char separator()
{
#ifdef _WIN32
    return '\\';
#else
    return '/';
#endif
}

template <typename SS,typename COLORMAP>
inline
bool 
decodeAllImages(uint8_t colorPalette[], const SS spritetable[], const size_t palette_size, const size_t table_rows, const std::string spritefilename, const std::string dirname, const std::string ext, const size_t matte)
{
  bool success (true);
  COLORMAP *colorMap = new COLORMAP[palette_size];

  if (colorMap != NULL)
  {
    generateImageColorMap(colorPalette,colorMap,palette_size,matte);

    std::fstream in(spritefilename.c_str(), std::ios_base::in);
    
    size_t allocLength(0);
    uint8_t * spriteData(NULL);
    
    std::cout<< "Writing images in " << ext << " format." << std::endl;
    std::cout<< "Info output: " << std::endl;
    std::cout<< "file name; offset; x; y; width; height; " << std::endl;
    
    for (size_t i = 0; i < table_rows; i++)
    {
	const SS *infos = (SS*)spritetable;
	SS info(infos[i]);

	char fileName[64];
	unsigned char * blockInt = ((unsigned char *)(&(info.offset)));      
	sprintf(fileName,"%04d_%02x_%02x_%02x_%02x",i,blockInt[3],blockInt[2],blockInt[1],blockInt[0]);

	printf("%s; %d;%d;%d;%d;%d;\n",fileName,info.offset,info.x,info.y,info.width,info.height);      
	size_t length(info.width*info.height);

	if (length > 0)
	{  
	  try
	  {
	    in.seekg((size_t)info.offset);
	    
	    if (length > allocLength)
	    {
	      if (spriteData != NULL)
	      {
		delete spriteData;
	      }
	      allocLength = length;
	      spriteData = new uint8_t[allocLength];
	      if (spriteData == NULL)
	      {
		success = false;
		break;
	      }
	    }
	    
	    if (spriteData != NULL)
	    {
	      in.readsome((char *)spriteData,length);
	      std::stringstream fullName("");
	      fullName << (dirname)
		      << (separator())
		      << fileName
		      << '.'
		      << ext;
      
	      success &= writeImage(info.width,info.height,fileName,fullName.str(),colorMap,palette_size,spriteData,matte);	    
	    }
	  }
	  catch (std::bad_alloc & e)
	  {
	    spriteData = NULL;
	    allocLength = (0);
	    success = false;
	    std::cout << "Could not load sprite " << i << '.' << std::endl;
	  }
	}
    }
    in.close();
    
    if (spriteData != NULL)
    {
      delete[] spriteData;
    }  
    
    delete[] colorMap;  
  }
  
  return success;
}

bool
decodeAllImages(uint8_t colorPalette[], const spriteinfo_t spritetable[], const size_t palette_size, const size_t table_rows, const std::string spritefilename, const std::string dirname, const std::string ext, const size_t matte)
{
  std::string lowerExt(ext);
  std::transform(lowerExt.begin(), lowerExt.end(), lowerExt.begin(), ::tolower);
  bool success(false);
  if (lowerExt.compare(XPM_EXT)==0)
  {
    success = decodeAllImages<spriteinfo_t, char[COLOR_MAP_ITEM_LENGTH]>(colorPalette,spritetable,palette_size,table_rows,spritefilename,dirname,lowerExt,matte);
  }
  else
  {
#ifdef __WITH_MAGICKPP__
    try
    {
      success = decodeAllImages<spriteinfo_t, Magick::Color>(colorPalette,spritetable,palette_size,table_rows,spritefilename,dirname,lowerExt,matte);    
    }
    catch (Magick::ErrorMissingDelegate & e)
    {
	std::cout << "This output format is not supported by your ImageMagick configuration." << std::endl;
	std::cout << "If you believe that \""<< ext <<"\" should be supported, update your ImageMagick and recompile this decoder." << std::endl;
	std::cout << "Magick++ error:" << std::endl;	
	std::cout << e.what() << std::endl;
    }
#else
    std::cout << "This decoder was compiled without ImageMagick." << std::endl;
    std::cout << "Only XPM output is supported." << std::endl;
#endif
  }
  return success;
}

