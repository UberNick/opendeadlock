#pragma once
#ifndef __GLFILE__
#define __GLFILE__

#include <string>

enum GLFILE_MODES
{
	READ_ONLY,
	READ_WRITE,
	WRITE_ONLY,
};

struct GLFILE_DATA
{
	char validHandle;
	char hasDot;
	char pathBuffer[MAX_PATH];
	WIN32_FIND_DATA find_data;
	HANDLE hFile;
};

class GLFILE
{
public:
	GLFILE(void) = default;
	~GLFILE(void) = default;

	static int GetGLFILEError(void);
	static HANDLE POpen(const std::string& name, int mode);
	static HANDLE PCreate(const std::string& name, int mode);
	static void PClose(HANDLE hFile);
	static int PDelete(const std::string& name);
	static int PMakeDir(const std::string& name);
	static DWORD PRead(HANDLE fd, void* buff, DWORD len);
	static int PWrite(HANDLE fd, const void* buf, DWORD bufSize);
	static DWORD PLSeek(HANDLE fd, LONG lDistanceToMove, DWORD dwMoveMethod);
	static DWORD PSize(HANDLE fd);
	static int PRename(const std::string& currFileName, const std::string& newFileName);
	static void PGetApplicationPath(std::string& dest);
	static BOOL PFileExists(const std::string& name);
	static void PStarClose(GLFILE_DATA& fl);
	static BOOL PStarInit(const std::string& iname, int attrib, GLFILE_DATA& fl);
	static BOOL PStarMatch(char* name, char* starname);
	static void PGdot(GLFILE_DATA& fl);
	static char* PStarNext(GLFILE_DATA& fl);
	static char* PGetStart(char* str);
	static BOOL PIsDir(const std::string& dir);
	static void PGetDir(const char* name, char* dir);
	static void PGetBase(char* name, std::string& base);
	static void PGetExt(char* name, std::string& ext_buffer);
	static BOOL PSetExt(std::string& name, const std::string& ext, BOOL force);
	static void PGetName(char* name, std::string& to);
	static void PSetDir(std::string& name, std::string& dir, BOOL force);
	static void PSetName(char* dir, char* name);
	static char* sindex(char* pStart, char chr);

private:
	
};

#endif //__GLFILE__