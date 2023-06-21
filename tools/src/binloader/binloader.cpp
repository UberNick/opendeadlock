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

/*
*
* BinLoader is a simple tool to replace binary data of files. It was written
* to ease the task of replacing data of executable files, sprite files and
* archives.
*
* With BinLoader, it is possible to overwrite a specific part of a binary file
* using another binary file, useful for patching, replacing media data, such
* as sprites and sounds.
*
*
* Usage:
*
* binloader <inputfile> <outputfile> [hex offset]
*
* If the offset is not provided via command line, the program will expect it
* via standard input.
*
*/

#define _CRT_SECURE_NO_WARNINGS

#include<stdio.h>
#include<string>
#include<iostream>
#include<sstream>

int main(int argc, char* argv[])
{

	if (argc >= 2)
	{

		FILE* in = fopen(argv[1], "r");
		FILE* out = fopen(argv[2], "r+");
		bool exit(false);

		signed long long int position(-1);
		std::stringstream ss("");
		if (argc == 4)
		{
			ss << std::hex << (argv[3]);
		}
		else
		{
			std::string par(argv[1]);
			bool offset(false);
			std::stringstream sst("");

			for (size_t p(0); par[p] != '\0' && par[p] != '.'; p++)
			{
				const char c(par[p]);
				if (c != '_')
				{
					if (offset)
					{
						sst << c;
					}
				}
				else
				{
					offset = true;
				}

			}
			ss << std::hex << sst.str();

		}


		ss >> position;

		if (position < 0)
		{
			std::cout << ("offset parse error.\n");
		}
		else
			if (!in || !out)
			{
				std::cout << ("Read error.\n");
			}
			else
			{
				size_t l1;
				char buffer[1024];
				fseek(out, (size_t)position, SEEK_SET);
				printf("Writing at %x\n", position);

				while ((l1 = fread(buffer, 1, sizeof(buffer), in)) > 0)
				{
					size_t l2 = fwrite(buffer, 1, l1, out);
					if (l2 < 0)
						std::cout << ("write error.\n");
					else if (l2 < l1)
						std::cout << ("disk full.\n");
				}
			}
		fclose(in);
		fclose(out);

		return 0;
	}
	else
	{
		std::cout << ("Usage:\n\nbinloader <inputfile> <outputfile> [hex offset]\n");
	}

}