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

#include<string>
#include<iostream>
#include<fstream>
#include<vector>

#include "cam.hpp"

#define OUT_FILENAME "output.cam"

enum stage
{
  invalid,
  header,
  format,
  filesHeader,
  files
};

struct blockFileName : public block
{
  public:
    std::string fileName;
    void print()
    {
      block::print();
      std::cout << "file name = " << fileName << std::endl;
    }
};

std::ifstream::pos_type filesize(const std::string& filename)
{
    std::ifstream in(filename.c_str(), std::ifstream::ate | std::ifstream::binary);
    return in.tellg(); 
}

int main(int argc, char *argv[])
{
	littleEndianOnly();

	std::istream * in = (&std::cin);
	if (argc >= 2)
	{
	  std::ifstream * infile = new std::ifstream();
	  infile->open(argv[1], std::ifstream::in);
	  in = infile;
	}
	else
	{
	  std::cout << argv[0] << " is reading from standard input." << std::endl;
	}
	bool exit(false);
	
	std::string formatName;
	std::string line;
	//check header;
	if (std::getline((*in),line))	
	{
	  std::istringstream ss(line);
	  std::string header;
	  if (!(ss >> header))
	  {
	      exit = true;
	      std::cout << "Error parsing header." << std::endl;
	  }
	  else
	  {
	    if (header != std::string(CAM_LIST))
	    {
	      exit = true;
	      std::cout << "Invalid header: " << header << '.' << std::endl;
	    }
	  }
	  
	}
	unsigned int lineNumber(2);
	bool filenameFirst(false);	
	stage mode(header);
	std::vector<blockFileName*> blockVector;
	
	while (std::getline((*in),line))
	{	  
	  std::string tokens[2];
	  if (line[0] != '#')
	  {
	    size_t delimiter= line.find_first_of(';');	    
	    {
	      if (delimiter != std::string::npos)
	      {
		tokens[0] = line.substr(0,delimiter);
		tokens[1] = line.substr(delimiter+1);
		stage previousMode(mode);
		switch (mode)
		{
		  case header:
		  {
		    if (tokens[0] == FORMAT_TEXT )
		    {
		      mode = format;
		    }
		    else
		    {
		      mode = invalid;
		    }
		    break;
		  }
		  
		  case format:
		  {
		    formatName = tokens[0];
		    if (!formatName.empty())
		    {
		      mode = filesHeader;  
		    }
		    else
		    {
		      mode = invalid;
		    }
		    
		    break;
		  }		  
		  
		  case filesHeader:
		  {
		    bool validStage(false);
		    for (bool x(false); !x; x=!x)
		    {
		      if (
			  (tokens[(int)(x)] == std::string(INDEX_TEXT))
			  &&
			  (tokens[(int)(!x)] == std::string(FILENAME_TEXT))
			)
		      {
			filenameFirst = x;
			validStage = true;
			mode = files;
			break;
		      }
		    }
		    if (!validStage)
		    {
		      exit = true;
		      std::cout << "Invalid file table header at line number " << lineNumber << '.' << std::endl;
		    }
		    break;
		  }
		    
		  case files:
		  {
		    blockFileName * block = new blockFileName();
		    {
		      std::stringstream input(tokens[(int)(filenameFirst)]);
		      input >> (block->index);
		    }
		    (block->fileName) = tokens[(int)(!filenameFirst)];
		    blockVector.push_back(block);
		    break;
		  }		  
		}
		
		if (mode == invalid)
		{
		  exit = true;
		  std::cout << "Invalid text at line number " << lineNumber << '.' << std::endl;
		}		
	      }
	      else
	      {
		exit = true;
		std::cout << "Missing delimiter at line number " << lineNumber << '.' << std::endl;
	      }
	      
	    }
	  }
	  lineNumber++;
	}
	
	if (!exit)
	{
	  //calculate baseOffset
	  const uint16_t firstword(1);
	  const uint16_t secondword(1);
	  const uint32_t formatcount(1);
	  uint32_t lastblockoffset;
	  const uint32_t filecountoffset(
	    (sizeof(MAGIC_NUMBERS) -1)+
	    sizeof(firstword) + sizeof(secondword) +
	    sizeof(formatcount) +
	    sizeof(lastblockoffset)+
	    formatName.length()+
	    sizeof(filecountoffset)
	  );
	  const uint32_t filecount(blockVector.size());
	  const uint32_t formatindex(1);
	  const uint32_t baseOffset(
	    filecountoffset+
	    sizeof(filecount) +
	    sizeof(formatindex) +
	    (ELEMENT_SIZE * sizeof(uint32_t) * (filecount))
	  );
	  lastblockoffset = baseOffset-(ELEMENT_SIZE * sizeof(uint32_t));
	  
	  uint32_t accumulatedLength(baseOffset);
	  //load length
	  std::cout << "Going to write " << OUT_FILENAME << "." << std::endl;
	  std::cout << "Loading input file sizes." << std::endl;
	  for (std::vector<blockFileName *>::iterator it = blockVector.begin() ; 
		it != blockVector.end(); 
		++it)
	  {
	    blockFileName * block = (*it);
	    const uint32_t size = filesize(block->fileName);
	    block->length = size;
	  //load offset
	    block->offset = accumulatedLength;
	    accumulatedLength+= size;
	    block->outputNames(formatName.c_str());
	  }
	  
	  //write output
	  std::ofstream ofs;
	  std::cout << "Opening output." << std::endl;
	  ofs.open (OUT_FILENAME, std::ofstream::out | std::ofstream::binary | std::ofstream::trunc);
	  //write header	
	  std::cout << "Writing new header." << std::endl;
	  ofs.write ((const char*)MAGIC_NUMBERS, 	(sizeof(MAGIC_NUMBERS) -1));
	  ofs.write ((const char*)&firstword, 	sizeof(firstword));
	  ofs.write ((const char*)&secondword, 	sizeof(secondword));
	  ofs.write ((const char*)&formatcount, 	sizeof(formatcount));
	  ofs.write ((const char*)&lastblockoffset, 	sizeof(lastblockoffset));
	  ofs.write ((const char*)formatName.c_str(), 	formatName.length());
	  ofs.write ((const char*)&filecountoffset,	sizeof(filecountoffset));
	  ofs.write ((const char*)&filecount, 	sizeof(filecount));
	  ofs.write ((const char*)&formatindex, 	sizeof(formatindex));
	  //write blocks
	  std::cout << "Writing offset table." << std::endl;
	  for (std::vector<blockFileName *>::iterator it = blockVector.begin() ; 
		it != blockVector.end(); 
		++it)
	  {
	    blockFileName * block = (*it);
	    //load
	    const uint32_t index(block->index);
	    const uint32_t offset(block->offset);
	    const uint32_t length(block->length);
	    //prepare
	    uint32_t outputBlocks[ELEMENT_SIZE];
	    outputBlocks[INDEX_POSITION] = index; //0
	    outputBlocks[PADDING_1_POSITION] = 0; //1
	    outputBlocks[PADDING_2_POSITION] = 0; //2
	    outputBlocks[PADDING_3_POSITION] = 0; //3
	    outputBlocks[PADDING_4_POSITION] = 0;	//4
	    outputBlocks[OFFSET_POSITION] = offset; //5
	    outputBlocks[LENGTH_POSITION] = length; //6
	    //write
	    ofs.write ((const char*)outputBlocks, sizeof(outputBlocks));
	    ofs.flush();
	  }
	  
	  //write data
	  std::cout << "Writing data." << std::endl;
	  for (std::vector<blockFileName *>::iterator it = blockVector.begin() ; 
		it != blockVector.end(); 
		++it)
	  {
	    blockFileName * block = (*it);
	    const uint32_t offset(block->offset);
	    const uint32_t length(block->length);
	    const std::string* name(&block->fileName);
	    
	    char* buffer = new char[length];
	    
	    std::ifstream fileinput(name->c_str(), std::ios::binary);
	    
	    if (fileinput.read(buffer, length))
	    {
		ofs.write ((const char*)buffer, length);    
	    }  
	    else
	    {
	      std::cout << "Error opening file " << name << std::endl;
	    }
	    fileinput.close();
	    delete buffer;
	  }
	  std::cout << "Finished." << std::endl;
	  ofs.close();
	  
	  std::cout << "Cleaning up." << std::endl;
	  if (in != (&std::cin) && (in != NULL))
	  {
	    if(std::ifstream * v = dynamic_cast<std::ifstream*>(in)) 
	    {
		if (v != NULL)
		  v->close();	   
		delete in;
	    }
	  }
	  
	  while (!blockVector.empty())
	  {
	    blockFileName * block = blockVector.back();
	    delete block;
	    blockVector.pop_back();
	  }
	  std::cout << "Successful." << std::endl;
	  return 0;
	}
	else
	{
	  std::cout << "Exiting with errors." << std::endl;
	}
	
}
