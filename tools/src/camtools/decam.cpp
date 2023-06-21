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

#include <Windows.h>
#include <memory>
#include <algorithm>
#include <optional>
#include <stdio.h>
#include <iostream>
#include <sstream>
#include <stdint.h>

#include "GLERROR.h"
#include "GLFILE.H"
#include "cam.hpp"

#define SHOW_NAMES "-d"

CYLIB_TABLE CYLibTable;

//=========================================================================
// Function: ValidateCyLib
//
// Purpose:
//=========================================================================
int ValidateCyLib(CyLibDataHeader& pCyLibHeader)
{
	return pCyLibHeader.magicNumbers[0].iNum == 'BLYC'
		&& pCyLibHeader.magicNumbers[1].iNum == '  CP'
		&& pCyLibHeader.format >= 65536;
}

//=========================================================================
// Function: FindCyLibDescEntry
//
// Purpose:
//=========================================================================
std::optional<std::deque<CYLIB_DESC_ENTRY>::iterator> FindCyLibDescEntry(CYLIB_DHANDLE_EXPANDED& pExpandedDHandle)
{
	int numLoaded = CYLibTable.numLibsLoaded;

	if (numLoaded <= 0)
		return std::nullopt;

	auto cyLib = CYLibTable.cyLibDescEntries.begin();
	while (&pExpandedDHandle != cyLib->pExpandedDHandle.get())
	{
		++cyLib;
		if (--numLoaded <= 0)
			return std::nullopt;
	}
	return cyLib;
}

//=========================================================================
// Function: CreateCyLibFilePointer
//
// Purpose:
//=========================================================================
HANDLE CreateCyLibFilePointer(CYLIB_DHANDLE_EXPANDED& pExpandedDHandle, int stream)
{
	auto descEntry = FindCyLibDescEntry(pExpandedDHandle);
	if (!descEntry.has_value())
		return INVALID_HANDLE_VALUE;

	int mode = (stream) ? 0x8000 : 0;

	return GLFILE::POpen(descEntry.value()->fileName, mode);
}


//=========================================================================
// Function: OpenCyLibFile
//
// Purpose:
//=========================================================================
HANDLE OpenCyLibFile(CYLIB_DHANDLE_EXPANDED& pExpandedDHandle)
{
	auto descEntry = FindCyLibDescEntry(pExpandedDHandle);

	if (!descEntry.has_value())
		return INVALID_HANDLE_VALUE;

	if (descEntry.value()->hFile != INVALID_HANDLE_VALUE)
		return descEntry.value()->hFile;

	descEntry.value()->hFile = CreateCyLibFilePointer(pExpandedDHandle, FALSE);
	return descEntry.value()->hFile;
}

//=========================================================================
// Function: CloseCyLibFile
//
// Purpose:
//=========================================================================
void CloseCyLibFile(CYLIB_DHANDLE_EXPANDED& pExpandedDHandle)
{
	auto cylibDescEntry = FindCyLibDescEntry(pExpandedDHandle);
	if (cylibDescEntry.has_value())
	{
		if (cylibDescEntry.value()->hFile != INVALID_HANDLE_VALUE)
		{
			GLFILE::PClose(cylibDescEntry.value()->hFile);
			cylibDescEntry.value()->hFile = INVALID_HANDLE_VALUE;
		}
	}
}

//=========================================================================
// Function: LoadCyLibDataToPtr
//
// Purpose:
//=========================================================================
int LoadCyLibDataToPtr(CYLIB_DHANDLE_EXPANDED& pExpandedDHandle, LONG lDistanceToMove, DWORD nBytes, void* pBuff)
{
	HANDLE hFile = OpenCyLibFile(pExpandedDHandle);
	if (hFile == INVALID_HANDLE_VALUE
		|| lDistanceToMove != -1 && (GLFILE::PLSeek(hFile, lDistanceToMove, FILE_BEGIN) == INVALID_SET_FILE_POINTER))
	{
		return 1; //error
	}

	if (nBytes == GLFILE::PRead(hFile, pBuff, nBytes))
		return 0;

	GLERROR::SetError(E_UNEXPECTED_EOF);
	return E_UNEXPECTED_EOF;
}


//=========================================================================
// Function: ExpandCyLibHeader
//
// Purpose: takes a basic CAM file header and expands it
// i.e. it creates a kind of map that has the full file offsets
// for the header data.
//=========================================================================
std::shared_ptr<CYLIB_DHANDLE_EXPANDED> ExpandCyLibHeader(FILE_CYLIB_DATA_HANDLE& ptr)
{
	CyLibDataHandle* pCyLibDHandle = (CyLibDataHandle*)ptr.data();
	size_t headerSize = (sizeof(CyLibDHandleSet) * pCyLibDHandle->header.numFileFormats) + sizeof(CyLibDataHeader);
	size_t memSizeNeeded = headerSize;

	unsigned int count = 0;
	{
		for (int i = 0; i < pCyLibDHandle->header.numFileFormats; i++)
		{
			//magicNumbers must be char[8] for this to work.
			int tmp = *(int*)&pCyLibDHandle->header.magicNumbers[pCyLibDHandle->sets[i].fileOffset];
			// Loops through the number of fileFormats. Each loop goes to an offset
			// location, multiplies 36 by the dword found at that offset, and adds that value to the memSizeNeeded sum.
			//int value = 40 * *(int*)((char*)(*ppCyLibDHandle)) + (*ppCyLibDHandle)->sets28[i].fileOffset4;
			count += tmp;
			memSizeNeeded += sizeof(CyLibDataEntry) * tmp;
		}
	}

	auto p = std::make_shared<CYLIB_DHANDLE_EXPANDED>();
	if (p)
	{
		p->resize(memSizeNeeded + headerSize);
		unsigned int offset = 0;
		CyLibDataHandleExpanded* expandedDHandle = (CyLibDataHandleExpanded*)p->data();

		memcpy(expandedDHandle, pCyLibDHandle, sizeof(CyLibDataHeader));

		expandedDHandle->header.chunkSize = memSizeNeeded;

		offset = headerSize;

		for (int j = 0; j < pCyLibDHandle->header.numFileFormats; j++)
		{
			CyLibDataEntry* dataEntry = (CyLibDataEntry*)&pCyLibDHandle->header.magicNumbers[pCyLibDHandle->sets[j].fileOffset];
			memcpy(&expandedDHandle->sets[j], &pCyLibDHandle->sets[j], sizeof(CyLibEntryHeaderSet));

			expandedDHandle->sets[j].memoryOffset = offset;

			CyLibDataEntryHeader* pExpandedDHandleChunk = (CyLibDataEntryHeader*)((char*)expandedDHandle + expandedDHandle->sets[j].memoryOffset);

			memcpy(pExpandedDHandleChunk, dataEntry, sizeof(CyLibEntryHeaderSet));
			offset += sizeof(CyLibEntryHeaderSet);

			CyLibDataEntrySubsetChunk* pDataEntrySubset = dataEntry->subSet;
			CyLibDataEntry* pChunkDataEntry = pExpandedDHandleChunk->dataEntry;

			for (int k = 0; k < pExpandedDHandleChunk->set.numSets; k++)
			{
				memset(pChunkDataEntry, 0, sizeof(CyLibDataEntry));

				memcpy(pChunkDataEntry, pDataEntrySubset, sizeof(CyLibDataEntrySubsetChunk));

				offset += sizeof(CyLibDataEntry);
				pDataEntrySubset++;
				pChunkDataEntry++;
			}
		}

		return p;
	}
	return nullptr;
}

//=========================================================================
// Function: ConvertCyLibHeader
//
// Purpose: Calls ExpandCyLibHeader. None of the CAM files released
// with Deadlock 2 have the 65536 format, so the function to convert
// them to 65537 is not included.
//=========================================================================
std::shared_ptr<CYLIB_DHANDLE_EXPANDED> ConvertCyLibHeader(FILE_CYLIB_DATA_HANDLE& pCyLibDHandle)
{
	CyLibDataHeader* hdr = (CyLibDataHeader*)pCyLibDHandle.data();
	if (hdr->format == 65536)
	{
		//shouldn't happen.
		return nullptr;
	}
	if (hdr->format == 65537)
		return ExpandCyLibHeader(pCyLibDHandle);
}

//=========================================================================
// Function: ClearCyLibDataEntry
//
// Purpose:
//=========================================================================
void ClearCyLibDataEntry(CyLibDataEntry* dataEntry)
{
	dataEntry->subSet[0].chnk.mpPtr = nullptr;
	dataEntry->subSet[0].refCount = 0;
	dataEntry->type = 0;
}

//=========================================================================
// Function: ResetCyLibDataHandles
//
// Purpose:
//=========================================================================
void ResetCyLibDataHandles(std::shared_ptr<CYLIB_DHANDLE_EXPANDED>& ptr)
{
	CyLibDataHandleExpanded* pExpandedHeader = (CyLibDataHandleExpanded*)ptr->data();

	CyLibDataEntryType* pEntry = (CyLibDataEntryType*)&pExpandedHeader->sets[pExpandedHeader->header.numFileFormats];
	for (int i = pExpandedHeader->header.numFileFormats; i > 0; i--)
	{
		CyLibDataEntry* dEntry = pEntry->dataEntries;
		for (int numEntries = pEntry->numEntries; numEntries > 0; numEntries--)
			ClearCyLibDataEntry(dEntry++);

		pEntry = (CyLibDataEntryType*)dEntry;
	}
}

//=========================================================================
// Function: LoadCyLibHeader
//
// Purpose: Loads the basic CyLib header from a CAM file.
// Then calls a function that expands the header.
//=========================================================================
std::shared_ptr<CYLIB_DHANDLE_EXPANDED> LoadCyLibHeader(HANDLE hFile)
{
	auto pCyLibDHandle = std::make_shared<FILE_CYLIB_DATA_HANDLE>();

	if (pCyLibDHandle)
	{
		CyLibDataHeader hdr;

		int nBytes = GLFILE::PRead(hFile, &hdr, sizeof(CyLibDataHeader));
		if (nBytes != sizeof(CyLibDataHeader))
		{
			if (nBytes >= 0)
				nBytes = E_UNEXPECTED_EOF;
			GLERROR::SetError(nBytes);
			return nullptr;
		}

		if (!ValidateCyLib(hdr))
			return nullptr;

		int sizeNeeded = hdr.chunkSize + (sizeof(CyLibDHandleSet) * hdr.numFileFormats);

		pCyLibDHandle->resize(sizeNeeded + sizeof(CyLibDataHeader));

		CyLibDataHandle* ptr = (CyLibDataHandle*)pCyLibDHandle->data();
		memcpy(&ptr->header, &hdr, sizeof(ptr->header));

		nBytes = GLFILE::PRead(hFile, ptr->sets, sizeNeeded);
		if (nBytes != sizeNeeded)
		{
			if (nBytes >= 0)
				nBytes = E_UNEXPECTED_EOF;
			GLERROR::SetError(nBytes);
			return nullptr;
		}

		auto p = ConvertCyLibHeader(*pCyLibDHandle);

		if (p)
			ResetCyLibDataHandles(p);

		return p;
	}
	return nullptr;
}

//=========================================================================
// Function: AddCyLibDesciptor
//
// Purpose: Loads the basic CyLib header from a CAM file.
// Then calls a function that expands the header.
//=========================================================================
BOOL AddCyLibDesciptor(const char* name)
{
	auto StrUpr = [](std::string& str)
	{
		std::for_each(str.begin(), str.end(), [](char& c) {
			c = ::toupper(c);
			});
	};

	std::string fileName(name);
	StrUpr(fileName);

	auto findLib = [&fileName, &StrUpr](void) -> BOOL
	{
		for (int i = CYLibTable.numLibsLoaded; i > 0; i--)
		{
			std::string tmp = CYLibTable.cyLibDescEntries[i].fileName;
			StrUpr(tmp);
			
			if (fileName.find(tmp) == 0)
				return TRUE;
		}
		return FALSE;
	};


	if (CYLibTable.numLibsLoaded > 0)
	{
		if (findLib())
			return TRUE;
	}

	if (CYLibTable.numLibsLoaded < CYLibTable.maxNumDescEntries)
	{
		HANDLE hFile = CreateFile(name, GENERIC_READ, 0, nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
		if (hFile != INVALID_HANDLE_VALUE)
		{
			auto ptr = LoadCyLibHeader(hFile);
			if (ptr != nullptr)
			{
				CYLibTable.cyLibDescEntries.emplace_front();
				auto descEntry = CYLibTable.cyLibDescEntries.begin();
				CYLibTable.numLibsLoaded++;

				descEntry->fileName = name;
				descEntry->pExpandedDHandle = ptr;
				descEntry->short0 = 0;
				descEntry->hFile = hFile;
				std::cout << "Library added: " << name << "\r\n";

				return ptr != nullptr;
			}

			//if File is open and could not load cylib header, close it.
			CloseHandle(hFile);
		}
	}

	return FALSE;
}

BOOL AddCyLibDesciptorEx(const char* name, BOOL mandatory)
{
	if (AddCyLibDesciptor(name))
		return TRUE;
	if (mandatory)
		GLERROR::ErrorMsg("Unable to load needed CAM, %s", name);
	return FALSE;
}

void RemoveCyLibDesciptor(std::shared_ptr<CYLIB_DHANDLE_EXPANDED>& ptr)
{
	auto cyLibDescEntry = FindCyLibDescEntry(*ptr);
	if (cyLibDescEntry.has_value())
	{
		if (GLERROR::CheckErrorLevel(0x10))
			GLERROR::WriteErrLog("Library closed: %s\r\n", cyLibDescEntry.value()->fileName.c_str());
		CloseCyLibFile(*ptr);

		ptr.reset();

		CYLibTable.cyLibDescEntries.erase(cyLibDescEntry.value());

		CYLibTable.numLibsLoaded--;
	}
}

void InitCyLibProcessing(int count)
{
	CYLibTable.numLibsLoaded = 0;
	CYLibTable.maxNumDescEntries = count;

	//CYLibTranslators[0].type = 0;
	//CYLibTranslators[0].translationProc = nullptr;
	//CYLibRegisterTranslator('ELIT', (CyLibTransProc*)CYLibTILETranslator);
	//CYLibRegisterTranslator('GLIT', (CyLibTransProc*)CYLibTILGTranslator);
	//CYLibRegisterTranslator('GAMI', (CyLibTransProc*)CYLibIMGTranslator);

	if (GLERROR::CheckErrorLevel(0x10))
		GLERROR::WriteErrLog("CYLib Manager inited, max libraries: %d\r\n", count);
}

void ShutdownCyLibProcessing()
{
	while (CYLibTable.numLibsLoaded > 0)
		RemoveCyLibDesciptor(CYLibTable.cyLibDescEntries[0].pExpandedDHandle);
}

int main(int argc, char *argv[])
{
	littleEndianOnly();
	InitCyLibProcessing(10);

	if (argc >= 2)
	{
		bool exit(false);
		bool showNames(false);
		if (argc >=3)
		{
		  showNames = (strcmp(argv[2],SHOW_NAMES)==0);
		}
		FILE *in = fopen(argv[1], "r");
		//check header
		uint8_t header[9];
		header[8]='\0';
		fseek ( in , (size_t)HEADER_OFFSET , SEEK_SET );
		if (fread(header, 1, sizeof(header)-1, in)>0)
		{
		  if (strcmp(((char*)header),MAGIC_NUMBERS) != 0)
		  {
		      puts("Unrecognized header: ");
		      puts((char*)header);
		      puts("\n");
		      exit = true;
		  }
		}
		else
		{
		  exit = true;
		}		
		
		//check format count
		uint32_t formatcount(0);
		fseek ( in , (size_t)FORMAT_COUNT_OFFSET , SEEK_SET );
		if ((!exit) && (fread(&formatcount, sizeof(formatcount), 1, in)>0))
		{
		  if (formatcount != 0x01) //only one is (currently) supported
		  {
		    puts("Invalid format count: ");
		    printf("%i",formatcount);
		    puts("\n");		    
		    exit = true;
		  }
		}
		else
		{
		  exit = true;
		}	
		
		//fetch format name
		uint8_t format[5];
		format[3]='\0';
		format[4]='\0';
		fseek ( in , (size_t)FORMAT_NAME_OFFSET , SEEK_SET );		  
		if ((!exit) && (fread(format, 1 , sizeof(format)-1, in)>0))
		{
		  //intentionally empty to follow pattern
		}
		else
		{
		  exit = true;
		}	
		
		//load output file count offset
		uint32_t filecountoffset(0);
		fseek ( in , (size_t)OUTPUT_FILE_COUNT_OFFSET , SEEK_SET );
		if ((!exit) && (fread(&filecountoffset, sizeof(filecountoffset), 1, in)>0))
		{
		  //intentionally empty to follow pattern
		}
		else
		{
		  exit = true;
		}
		
		//load output file count
		uint32_t filecount(0);
		fseek ( in , (size_t)filecountoffset , SEEK_SET );
		if ((!exit) && (fread(&filecount, sizeof(filecount), 1, in)>0))
		{
		  if (filecount == 0)
		  {
		    puts("Invalid file count: ");
		    printf("%i",filecount);
		    puts("\n");
		    exit = true;
		  }
		}
		else
		{
		  exit = true;
		}
			
		if (!exit)
		{
		  //load offsets and lengths
		  //starts after a sequence of format definitions (length 2 uint32)
		  fseek ( in , (size_t)(filecountoffset+(formatcount*2*sizeof(uint32_t))) , SEEK_SET );		  
		  block * blocks = new block[filecount];
		  for (uint32_t i = 0; i < filecount; i++)
		  {
		    //load 7 elements of 32 bits each time
		    const size_t elements = ELEMENT_SIZE;
		    uint32_t buffer[ELEMENT_SIZE];
		    if (fread(buffer, sizeof(uint32_t), elements, in)>0)
		    {
		      const uint32_t index(buffer[INDEX_POSITION]);
		      const uint32_t offset(buffer[OFFSET_POSITION]);
		      const uint32_t length(buffer[LENGTH_POSITION]);
		      
		      blocks[i].index=index;
		      blocks[i].offset=offset;
		      blocks[i].length=length;
		    }		  
		  }
		  
		  if (showNames)
		  {
		    //output names
		    std::cout << CAM_LIST <<" Generated by decam. OpenDeadlock Decode Tools." << std::endl;
		    std::cout << "format;" << std::endl << format << ';' << std::endl;
		    block::outputNamesHeader();
		    for (uint32_t i = 0; i < filecount; i++)
		    {
		      blocks[i].outputNames((char*)format);
		    }
		  }
		  else
		  {
		    //output files.
		    std::cout << "Going to output " << filecount << " files" << std::endl;
		    for (uint32_t i = 0; i < filecount; i++)
		    {
		      const std::string filename(blocks[i].name((char*)format));		  
		      std::cout << "Creating " << filename << std::endl;
		      blocks[i].print();
		      FILE *out = fopen(filename.c_str(), "w");		  
		      fseek ( in , (size_t)(blocks[i].offset) , SEEK_SET );
		      uint8_t * buffer = new uint8_t[blocks[i].length];
		      if (fread(buffer, 1, blocks[i].length, in)>0)
		      {
			fwrite(buffer, 1, blocks[i].length, out);
		      }
		      delete[] buffer;
		      fclose(out);
		    }
		  }
		  delete[] blocks;
		}
		fclose(in);
		
		if (exit)
		{
			ShutdownCyLibProcessing();
			std::cout << ("Exiting with error.") << std::endl;
			return 1;
		}
		else
		{
			ShutdownCyLibProcessing();
			return 0;
		}
	}
	else
	{
		ShutdownCyLibProcessing();
		std::cout << ("Usage:\n") << argv[0] << " CAM file name" << std::endl;
		return 0;
	}
}
