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
#include <string>
#include <stdint.h>
#include <fstream>
#include <sstream>
#include <iostream>
#include "../magick/magick.h"
#include "palette_reader.h"

bool
validRaw(const std::string & extension, const int size)
{	
	int count = 0;
	for (int l = 0; l < size; l++)
	{
		const char c = extension.at(l);
		if (c == 'x' || c == 'a' || c == 'r' || c == 'g' || c == 'b')
		{
			count++;
		}
	}
	
	return (size >= 1) && (count == size);	
}

void 
setExtension(const std::string& source, std::string & extension)
{
	size_t pos (source.find_last_of('.'));
	if (pos < source.length())
	{	  
	    extension = (source.substr(pos+1)); 
	    std::transform(extension.begin(), extension.end(), extension.begin(), ::tolower);
	}
	else
	{
	    extension = ("");
	}
}

void
readRawPalette(const std::string & extension, std::ifstream& inputFile, const size_t length, uint8_t rawdataoutput[])
{	
    size_t pos(0);
    while (inputFile.good())
    {	    
	rawdataoutput[pos+0] = 0;
	rawdataoutput[pos+1] = 0;
	rawdataoutput[pos+2] = 0;
	rawdataoutput[pos+3] = 0;
	
	for (int l =0; inputFile.good() && (l < extension.length()); l++)
	{		
	  const int read (inputFile.get());
	  const uint8_t c ((uint8_t)read);
	  switch (extension.at(l))
	  {
	    case 'a':
	    {
		    rawdataoutput[pos+0] = c;
		    break;
	    }
	    case 'r':
	    {
		    rawdataoutput[pos+1] = c;
		    break;
	    }
	    case 'g':
	    {
		    rawdataoutput[pos+2] = c;
		    break;
	    }
	    case 'b':
	    {
		    rawdataoutput[pos+3] = c;
		    break;
	    }	
	  }	
	}
	pos += 4;
    }
}

bool
openPalette(const std::string & fileName, uint8_t * rawdataoutput[], size_t & palette_size)
{
    std::string extension;
    setExtension(fileName,extension);   
    bool success(true);
    
    if (validRaw(extension,extension.length()))
    {
      std::ifstream is(fileName.c_str(), std::ios::in); 
      is.seekg (0, is.end);
      size_t length (is.tellg());
      is.seekg (0, is.beg);
      if (length % extension.length() == 0)
      {
	palette_size = length/extension.length();
	*rawdataoutput = new uint8_t[palette_size*4];
	readRawPalette(extension, is, length, *rawdataoutput);

      }
      else
      {
	success = false;
	std::cout << "Incorrect or corrupted palette file." << std::endl;	
      }  
      is.close();
    }
    else
    {
#ifdef __WITH_MAGICKPP__   
       success = decodePaletteWithMagick(fileName,extension,rawdataoutput,palette_size);
#else
       std::cout << "Unsupported Palette format." << std::endl;
       std::cout << "This decoder was compiled without ImageMagick." << std::endl;
       std::cout << "Only binary palettes are supported." << std::endl;
       success = false;
#endif           
    }
    return success;
}
