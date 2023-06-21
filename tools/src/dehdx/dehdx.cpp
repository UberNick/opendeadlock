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

/*
* DeHDX
* 
* Description
*
* DeHDX is a HDX/HDD file extractor. It is capable of extracting a HDX/HDD 
* file pair maintaining the names of the archived files. It can also add an 
* extension if requested, since HDX/HDD have no extension or format definition.
* 
* Usage
* 
* # Usage for extracting:
* dehdx <HDX file name> <HDD file name> [output extension]
* 
* This makes dehdx extract the files to the current directory.
* 
* #Usage for listing: 
* dehdx <HDX file name> -d
* 
* This makes the dehdx list the file names without extracting.
* 
*/

#include<stdio.h>
#include<string>
#include<string.h>
#include<iostream>
#include<fstream>
#include<stdint.h>

#include "hdx.hpp"

#define SHOW_NAMES "-d"

void showHDXNames(uint32_t recordCount, hdxfilerecord records[], bool dumpFormat);
void extractFiles(uint32_t recordCount, hdxfilerecord records[], const std::string& hddFileName, const std::string& extension = std::string(""));

int main(int argc, char* argv[])
{
	littleEndianOnly();

	if (argc >= 3)
	{
		bool exit(false);
		bool showNames(false);
		showNames = (strcmp(argv[2], SHOW_NAMES) == 0);


		//check correct extension
		std::string hdxFileName(argv[1]);
		size_t dot(hdxFileName.find_last_of('.'));

		bool validExt(false);

		if (
			(dot != std::string::npos)
			&&
			(hdxFileName.length() == (dot + 4))
			)
		{
			validExt =
				(
					(hdxFileName[dot + 1] == 'h' || hdxFileName[dot + 1] == 'H')
					&&
					(hdxFileName[dot + 2] == 'd' || hdxFileName[dot + 2] == 'D')
					&&
					(hdxFileName[dot + 3] == 'x' || hdxFileName[dot + 3] == 'X')
					);
		}

		std::string hddFileName(argv[2]);
		size_t dotDD = (hddFileName.find_last_of('.'));

		if (!showNames)
		{
			if (
				(dotDD != std::string::npos)
				&&
				(hddFileName.length() == (dotDD + 4))
				)
			{
				validExt &=
					(
						(hddFileName[dotDD + 1] == 'h' || hddFileName[dotDD + 1] == 'H')
						&&
						(hddFileName[dotDD + 2] == 'd' || hddFileName[dotDD + 2] == 'D')
						&&
						(hddFileName[dotDD + 3] == 'd' || hddFileName[dotDD + 3] == 'D')
						);
			}
		}

		//open hdx and load table
		if (validExt)
		{
			std::ifstream ifsHDX;
			ifsHDX.open(hdxFileName.c_str(), std::ifstream::in | std::ifstream::binary);

			if (ifsHDX.good())
			{
				//read count
				uint32_t recordCount(0);
				ifsHDX.read((char*)(&recordCount), sizeof(recordCount));
				fixEndianness(recordCount);
				if (recordCount > 0)
				{
					hdxfilerecord* records = new hdxfilerecord[recordCount];

					for (uint32_t rC(0); rC < recordCount; rC++)
					{
						// null the 9th element for the case of fixed 8 length string
						records[rC].file_name[8] = '\0';

						ifsHDX.read((char*)(records[rC].file_name), sizeof(char) * 8);
						ifsHDX.read((char*)(&(records[rC].offset)), sizeof(uint32_t));
						fixEndianness(records[rC].offset);
					}
					ifsHDX.close();
					//show names or extract data
					if (showNames)
					{
						showHDXNames(recordCount, records, true);
					}
					else
					{
						showHDXNames(recordCount, records, false);
						//check if user wants specific output extension
						std::string extension;
						if (argc >= 4)
						{
							extension = std::string(".") + std::string(argv[3]);
						}
						extractFiles(recordCount, records, hddFileName, extension);
					}

					delete[] records;
				}
				else
				{
					std::cerr << "Invalid record count: " << recordCount << std::endl;
				}
			}
			else
			{
				std::cerr << "Error reading file name: " << hdxFileName << std::endl;
			}

			if (ifsHDX.is_open())
			{
				ifsHDX.close();
			}
		}
		else
		{
			std::cerr << "Invalid extension sequence detected: \"" << hdxFileName.substr(dot + 1) << ' ' << hddFileName.substr(dotDD + 1) << "\" expected \"hdx hdd\"." << std::endl;
		}
	}
	else
	{
		std::cout << ("Usage for extracting:\n") << argv[0] << " <HDX file name> <HDD file name> [output extension]" << std::endl;
		std::cout << ("Usage for listing:\n") << argv[0] << " <HDX file name> -d" << std::endl;
		return 0;
	}
}




void showHDXNames(uint32_t recordCount, hdxfilerecord records[], bool dumpFormat)
{
	for (uint32_t rC(0); rC < recordCount; rC++)
	{
		records[rC].print();
	}
}
void extractFiles(uint32_t recordCount, hdxfilerecord records[], const std::string& hddFileName, const std::string& extension)
{
	std::ifstream ifsHDD;
	ifsHDD.open(hddFileName.c_str(), std::ifstream::in | std::ifstream::binary);

	if (ifsHDD.good())
	{
		for (uint32_t rC(0); rC < recordCount; rC++)
		{
			//seek to offset
			ifsHDD.seekg((records[rC].offset), std::ios_base::beg);
			//read length
			uint32_t length(0);
			ifsHDD.read((char*)(&length), sizeof(length));
			fixEndianness(length);
			//load data      
			char* buffer = new char[length];
			ifsHDD.read(buffer, length);

			//write data
			std::ofstream ofs;
			std::string outfilename(records[rC].file_name);
			outfilename += extension;
			ofs.open(outfilename.c_str(), std::ofstream::out | std::ofstream::binary | std::ofstream::trunc);

			ofs.write(buffer, length);

			if (ofs.is_open())
			{
				ofs.close();
			}
			delete[] buffer;
		}
	}
	else
	{
		// hdd read error
		std::cerr << "Error reading file name: " << hddFileName << std::endl;
	}

	if (ifsHDD.is_open())
	{
		ifsHDD.close();
	}
}
