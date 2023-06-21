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

#ifndef CAM_HPP_
#define CAM_HPP_

#include <string>
#include <vector>
#include <deque>
#include <cstring>
#include <iostream>
#include <sstream>
#include <stdint.h>
#include <cstdlib>

enum GLERRORS
{
	S_NO_ERROR = 0,
	E_GENERAL_ERROR = 1,
	E_FILE_NOT_FOUND = 2,
	E_PATH_NOT_FOUND = 3,
	E_TOO_MANY_FILES_OPEN = 4,
	E_ACCESS_DENIED = 5,
	E_INVALID_HANDLE = 6,
	E_INVALID_POINTER = 6,
	E_OUT_OF_MEMORY = 8,
	E_OUT_OF_MEMORY2 = 14,
	E_DISK_WRITE_PROTECTED = 19,
	E_SEEK_ERROR = 25,
	E_WRITE_ERROR = 29,
	E_READ_ERROR = 30,
	E_GENERAL_FAILURE = 31,
	E_SHARING_VIOLATION = 32,
	E_FILE_LOCKED = 33,
	E_PAST_EOF = 38,
	E_DISK_FULL = 39,
	E_FILE_EXISTS = 80,
	E_CANT_CREATE_FILE = 82,
	E_DRIVE_LOCKED = 108,
	E_CANT_OPEN_FILE = 110,
	E_DISK_FULL2 = 112,
	E_INVALID_NAME = 123,
	E_FILE_EXISTS2 = 183,
	E_UNEXPECTED_EOF = 0x2000000A,
};

//used to easily convert between int and char.
union MAGIC_NUMBERS
{
	char chNum[4];
	int iNum;
};

using CYLIB_DHANDLE_EXPANDED = std::vector<BYTE>;
using FILE_CYLIB_DATA_HANDLE = std::vector<BYTE>;

struct CYLIB_DESC_ENTRY
{
	short short0;
	std::shared_ptr<CYLIB_DHANDLE_EXPANDED> pExpandedDHandle;
	HANDLE hFile;
	std::string fileName;
};

struct CYLIB_TABLE
{
	short numLibsLoaded;
	short maxNumDescEntries;
	std::deque<CYLIB_DESC_ENTRY> cyLibDescEntries;
};

#pragma pack(push, 1) //make sure all structs are packed.

struct CyLibDataHeader
{
	MAGIC_NUMBERS magicNumbers[2];
	unsigned long format;
	unsigned long numFileFormats;
	unsigned long chunkSize;
};

struct CyLibDHandleSet
{
	MAGIC_NUMBERS dataID;
	int fileOffset;
};

struct CyLibDataHandle
{
	CyLibDataHeader header;
	CyLibDHandleSet sets[1];
};

struct CyLibDataEntrySubsetChunk2
{
    long fileOffset;
    unsigned long chunkSize;
    void* mpPtr;
};

struct CyLibDataEntrySubsetChunk
{
    MAGIC_NUMBERS dataID;
    MAGIC_NUMBERS data[2];
    CyLibDataEntrySubsetChunk2 chnk;
    int refCount;
};

struct CyLibDataEntry
{
	MAGIC_NUMBERS magicNumbers[2];
	CyLibDataEntrySubsetChunk subSet[1];
	int type;
};

struct CyLibDataEntryType
{
	int numEntries;
	int sizeOfChunk;
	CyLibDataEntry dataEntries[1];
};

struct CyLibEntryHeaderSet
{
	union
	{
		MAGIC_NUMBERS magicNumbers;
		int numSets;
	};
	unsigned long memoryOffset;
};

struct CyLibDataEntryHeader
{
	CyLibEntryHeaderSet set;
	CyLibDataEntry dataEntry[1];
};

struct CyLibDataHandleExpanded
{
	CyLibDataHeader header;
	CyLibEntryHeaderSet sets[1];
};

#pragma pack(pop)

#define HEADER_OFFSET 0x0
#define FORMAT_COUNT_OFFSET 0x0C
#define FORMAT_NAME_OFFSET 0x14
#define OUTPUT_FILE_COUNT_OFFSET 0x18
#define MAGIC_NUMBERS "CYLBPC  "
#define ELEMENT_SIZE 7
#define INDEX_POSITION 0
#define PADDING_1_POSITION 1
#define PADDING_2_POSITION 2
#define PADDING_3_POSITION 3
#define PADDING_4_POSITION 4
#define OFFSET_POSITION 5
#define LENGTH_POSITION 6

#define CAM_LIST "#CAMLIST"
#define INDEX_TEXT "index" 
#define FILENAME_TEXT "name"
#define FORMAT_TEXT "format"

struct block
{
public:
  uint32_t offset;
  uint32_t length;
  uint32_t index;
  block() : offset(0), length(0), index(0)
  {
  };
  block(const uint32_t off,const uint32_t len,const uint32_t ind) : offset(off), length(len), index(ind)
  {
  };
  void print()
  {
    std::cout << std::dec <<  INDEX_TEXT << " = " << index << "; offset = " << std::hex << offset << "; length = " << std::dec <<  length << ';' << std::endl; 
  };
  
  static void outputNamesHeader()
  {
    std::cout << INDEX_TEXT << ";" << FILENAME_TEXT << std::endl;    
  }
  
  const std::string name(const char format[])
  {
      std::stringstream ss("");
      ss << std::dec << (this->index)<< '_' << std::hex << (this->offset) << '.' << format;
      return ss.str();
  }
  
  void outputNames(const char format[])
  {
    std::cout << std::dec <<  index << ";" << this->name(format) << std::endl; 
  };
};

void littleEndianOnly()
{
   uint32_t test = 0x12345678;
   uint8_t * bytes = (uint8_t*)(&test);
   if (
	(bytes[3] == 0x12)
	&&
	(bytes[2] == 0x34)
	&&
	(bytes[1] == 0x56)
	&&
	(bytes[0] == 0x78)	
      )
   {
     // little endian.
   }
   else
   {
     std::cerr << "Unfortunately this tool only works on a little endian system." << std::endl;
     exit(-1);
   }
}

#endif // CAM_HPP_
