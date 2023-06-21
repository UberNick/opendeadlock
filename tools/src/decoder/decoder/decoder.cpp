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

#include <iostream>
#include <string>

#ifndef __STDC_LIMIT_MACROS
#define __STDC_LIMIT_MACROS
#endif

#include <stdint.h>
#ifdef __WITH_MAGICKPP__
#include <Magick++.h>
#include "magick/magick.h"
#endif

#include "sprite_info/sprite_info.h"
#include "palette_reader/palette_reader.h"
#include "sprite_table_reader/sprite_table_reader.h"
#include "image_decoder/image_decoder.h"

#ifndef BIG_ENDIAN_INPUT
#define BIG_ENDIAN_INPUT "bigendian"
#endif

#include<sstream>

#include "decoder.h"

const size_t 
readSize(char in[])
{
  size_t result;
  size_t start (0);
  
  if (
      (in[0] == '0')
      &&
      (in[1] == 'x')
     )
  {
    start = 2;
  }
  
  std::stringstream ss("");  
  
  if (start == 0)
  {
    ss << in;
  }
  else
  {
    std::string inStr(in);
    ss << std::hex << inStr.substr(start);
  }
  
  ss >> result;
  return result;
}

bool 
checkEndianness(bool &isBigEndian)
//check endianness
{//endianness defines are not in standard, checking it at runtime.
  const uint32_t integer (0x12345678);
  const uint8_t * intbytes = ((uint8_t*)(&integer));
  
  const bool littleEndianSystem
    (
      (intbytes[0]==0x78) &&
      (intbytes[1]==0x56) &&
      (intbytes[2]==0x34) &&
      (intbytes[3]==0x12)	
    );
  const bool bigEndianSystem
    (
      (intbytes[0]==0x12) &&
      (intbytes[1]==0x34) &&
      (intbytes[2]==0x56) &&
      (intbytes[3]==0x78)	
    );
  isBigEndian = bigEndianSystem;
  return (littleEndianSystem || bigEndianSystem);
}

bool  
decodeStages(
  const std::string &paletteFileName,
  const std::string &spriteInfoFileName,
  const size_t offset,
  const size_t length,
  const std::string &spriteFileName,
  const std::string &outputDirName,
  const std::string &outputFormat,
  const bool invertEndianness,
  const uint8_t matte)
{
  std::cout << "Stage 1: Read Palette." << std::endl;
  uint8_t * paletteARGB (NULL);
  size_t palette_size;
  bool decodeSuccess(false);
  const bool paletteOpen(openPalette(paletteFileName, &paletteARGB, palette_size));
  if (paletteOpen)
  {
    std::cout << "Stage 2: Read SpriteInfo." << std::endl;
    spriteinfo_t * spriteData(NULL);
    const bool spriteTableOpen(openRawSpriteTableFile(spriteInfoFileName, offset, length, invertEndianness, &spriteData));
    if (spriteTableOpen)
    { 
      std::cout << "Stage 3: decode into image files." << std::endl;
      decodeSuccess = decodeAllImages(paletteARGB,spriteData,palette_size,length,spriteFileName,outputDirName,outputFormat,matte);
    }
    if (spriteData != NULL)
    {
      delete[] spriteData;
    }
  }
  
  if (paletteARGB != NULL)
  {
     delete[] paletteARGB;
  }
  return decodeSuccess;
}

int 
main( int argc, char * argv[])
{
  bool bigEndianSystem;
  bool supportedEndianness(checkEndianness(bigEndianSystem));
  bool invertEndianness(false);
  int result (-1);
  
  if (supportedEndianness)
  {
    if (argc < 7)
    {
      std::cout << "Tggtt's Sprite Decoder (now part of OpenDeadlock project)" << std::endl;
#ifdef __WITH_MAGICKPP__      
      std::cout << "Compiled with ImageMagick library." << std::endl;
#endif
      std::cout << "Requirements: " << std::endl;
      std::cout << "1 - Palette File: A palette file, use the palette tool to convert it if needed;" << std::endl;
      std::cout << "2 - Sprite Table File: A memory dump or an (unencoded) executable container of the original Deadlock;" << std::endl;
      std::cout << "3 - Sprite File: A sprite file, SPRITE*.DAT;" << std::endl;
      std::cout << "4 - Output directory: output with enough disk space." << std::endl;
      std::cout << std::endl;
      std::cout << "Usage:" << std::endl;
      std::cout << argv[0] << " <palette file> <sprite table file> <sprite table start position> <sprite table length> <sprite file> <output directory> <output format> ["
	<<  BIG_ENDIAN_INPUT << "]" 
	<< " [matte index] "
	<< std::endl;      
      std::cout << std::endl;
      std::cout << "Supported formats: " << std::endl;
      std::cout << "Palette: " << std::endl;
      std::cout << " Raw Binary Palettes: Combinations of R,G,B,X and A. ex: RGB, RGBA, ARGB, BGRX." << std::endl;
#ifdef __WITH_MAGICKPP__  
      std::cout << " Image file Palettes: Several formats read by ImageMagick. Warning: this may cause precision loss." << std::endl;
#endif      
      std::cout << "Output:" << std::endl;
      std::cout << " XPM" << std::endl;
#ifdef __WITH_MAGICKPP__    
      std::cout << " PNG" << std::endl;
      std::cout << " GIF" << std::endl;
      std::cout << " BMP" << std::endl;
      std::cout << " And several other formats supported by ImageMagick." << std::endl;
#else
      std::cout << "Recompile with ImageMagick and Magick++ for more formats." << std::endl;
#endif
      std::cout << std::endl;
      std::cout << "Sprite Table File is assumed to be little endian unless \"" <<   BIG_ENDIAN_INPUT << "\" is stated." << std::endl;
      std::cout << "Matte index is assumed to be 0 unless other value (between "<< 0 <<" and "<< UINT8_MAX <<") is stated." << std::endl;
      std::cout << std::endl;
      std::cout << "Use \"0x\" prefix to define hexadecimal number input." << std::endl;
      std::cout << std::endl;      
    }
    else
    {
#ifdef WITH_MAGICKPP
      Magick::InitializeMagick(argv[0]);
#endif    
      std::string paletteFileName(argv[1]);
      std::string spriteInfoFileName(argv[2]);      
      size_t offset (readSize(argv[3]));
      size_t length (readSize(argv[4]));
      std::string spriteFileName(argv[5]);
      std::string outputDirName(argv[6]);
      std::string outputFormat("");    
      uint8_t matte (0);

      if (argc >= 8)
      {
	outputFormat = std::string(argv[7]);
	if (argc >= 9)
	{
	  const std::string bigEndianInputStr(argv[8]);
	  const bool bigEndianInput ((bigEndianInputStr.compare(BIG_ENDIAN_INPUT)==0));
	  invertEndianness = bigEndianInput ^ bigEndianSystem;
	}
	if (argc >= 10)
	{
	  size_t matteSize_t(readSize(argv[9]));
	  if (matteSize_t > UINT8_MAX)
	  {
	    std::cout << "Invalid matte was ignored." << std::endl;
	  }
	  else
	  {
	    matte = ((uint8_t) matteSize_t);
	  }
	}
      }
      if (decodeStages(paletteFileName,spriteInfoFileName,offset,length,spriteFileName,outputDirName,outputFormat,invertEndianness,matte))
      {
	  std::cout << "Decoding finished successfuly." << std::endl;
	  result = 0;
      }
      else
      {
	  std::cout << "Decoding finished with errors." << std::endl;	
	  result = 1;
      }
    }
  }
  else
  {
      std::cout << "This is probably a bug. If you are really using a mixed-endian system, please tell us!" << std::endl;
  }
  
  if (bigEndianSystem)
  {
    std::cout << "This software was not tested on big endian systems. Please report the outcome." << std::endl;
  }
  std::cout << "Thank you for using this tool." << std::endl;
  return result;
}