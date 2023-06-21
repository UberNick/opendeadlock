#pragma once
#ifndef __GLERROR__
#define __GLERROR__

#include <string>

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

class GLERROR
{
public:
	GLERROR(void) = default;
	~GLERROR(void) = default;

	static void SetError(int err);
	static int GetLastError(void);
	static const char* GetStr(int error = -1);
	static int CheckErrorLevel(int BitAndValue);
	static void MakeErrLogName(std::string& dest, const char* src);
	static void MakeErrLogName(std::string& dest, const std::string& src);
	static void WriteErrLog(const char* format, ...);
	static void SetExternalErrLog(int(*externalLog)(std::string&));
	static void ClearErrLog(void);
	static void ClearErrLogLine(void);
	static void ErrorMsg(const char* str, ...);
	static void ResErrorMsg(UINT uID);

private:
};

#endif //__GLERROR__

