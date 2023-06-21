#include <Windows.h>
#include <string>
#include <map>
#include "GLFILE.H"
#include "GLERROR.h"

static int LastGLError = 0;
static int GLErrLogLevel = 0;
static std::string sgUnknownStr;
static int (*sgpExternalOut)(std::string&) = nullptr;
static std::string sgErrPath;

extern HINSTANCE thisInstance;
//
//struct ERROR_LOG
//{
//	int error;
//	const char* errorMessage;
//};

std::map<int, const std::string> KnownGLErrors =
{
  { 1, "General error" },
  { 8, "Out of memory" },
  { 14, "Out of memory" },
  { 6, "Invalid handle" },
  { 6, "Invalid pointer" },
  { 0x2000000A, "Unexpected EOF" },
  { 2, "File not found" },
  { 3, "Path not found" },
  { 4, "Too many files open" },
  { 5, "Access denied" },
  { 19, "Disk write protected" },
  { 25, "Seek error" },
  { 29, "Write error" },
  { 30, "Read error" },
  { 31, "General failure" },
  { 32, "Sharing violation" },
  { 33, "File locked" },
  { 38, "Past EOF" },
  { 39, "Disk full" },
  { 80, "File exists" },
  { 82, "Can't create file" },
  { 108, "Drive locked" },
  { 110, "Can't open file" },
  { 112, "Disk full" },
  { 123, "Invalid name" },
  { 183, "File exists" },
  { 0, "No Error" }
};

//
//ERROR_LOG KnownGLErrors[] =
//{
//  { 1, "General error" },
//  { 8, "Out of memory" },
//  { 14, "Out of memory" },
//  { 6, "Invalid handle" },
//  { 6, "Invalid pointer" },
//  { 0x2000000A, "Unexpected EOF" },
//  { 2, "File not found" },
//  { 3, "Path not found" },
//  { 4, "Too many files open" },
//  { 5, "Access denied" },
//  { 19, "Disk write protected" },
//  { 25, "Seek error" },
//  { 29, "Write error" },
//  { 30, "Read error" },
//  { 31, "General failure" },
//  { 32, "Sharing violation" },
//  { 33, "File locked" },
//  { 38, "Past EOF" },
//  { 39, "Disk full" },
//  { 80, "File exists" },
//  { 82, "Can'nt create file" },
//  { 108, "Drive locked" },
//  { 110, "Can't open file" },
//  { 112, "Disk full" },
//  { 123, "Invalid name" },
//  { 183, "File exists" },
//  { 0, "No Error" }
//};

void GLERROR::SetError(int err)
{
	LastGLError = err | 0xC0000000;
}

int GLERROR::GetLastError(void)
{
	return LastGLError;
}

const char* GLERROR::GetStr(int error)
{
	if (error == -1)
		error = GLERROR::GetLastError();

	int val = (error & 0x3FFFFFFF);

	auto m = KnownGLErrors.find(val);
	if (m != KnownGLErrors.end())
		return m->second.c_str();

	sgUnknownStr.clear();
	sgUnknownStr = "Unknown error " + std::to_string(val);

	return sgUnknownStr.c_str();
}


int GLERROR::CheckErrorLevel(int BitAndValue)
{
	return GLErrLogLevel & BitAndValue;
}

void GLERROR::MakeErrLogName(std::string& dest, const char* src)
{
	dest = src;

	if (!sgErrPath[0])
		GLFILE::PGetApplicationPath(sgErrPath);
	GLFILE::PSetDir(dest, sgErrPath, TRUE);
}

void GLERROR::MakeErrLogName(std::string& dest, const std::string& src)
{
	dest = src;

	if (!sgErrPath[0])
		GLFILE::PGetApplicationPath(sgErrPath);
	GLFILE::PSetDir(dest, sgErrPath, TRUE);
}

void GLERROR::WriteErrLog(const char* format, ...)
{
	va_list arglist;

	va_start(arglist, format);
	if (GLErrLogLevel < 0 && format)
	{
		std::string buffer;
		buffer.resize(1024);

		int numCharsWritten = vsprintf(buffer.data(), format, arglist);
		if (GLErrLogLevel & 0x1000 && sgpExternalOut)
			sgpExternalOut(buffer);

		GLErrLogLevel &= 0x7FFFFFFFu;
		if (numCharsWritten <= 0)
		{
			GLErrLogLevel |= 0x80000000;
			return;
		}
		
		std::string fileName;
		MakeErrLogName(fileName, "err.log");

		HANDLE hFile = GLFILE::POpen(fileName, WRITE_ONLY);
		if (hFile != INVALID_HANDLE_VALUE 
			|| (hFile = GLFILE::PCreate(fileName, 0), hFile != INVALID_HANDLE_VALUE))
		{
			GLFILE::PLSeek(hFile, 0, FILE_END);
			GLFILE::PWrite(hFile, buffer.data(), numCharsWritten);
			GLFILE::PClose(hFile);
			GLErrLogLevel |= 0x80000000;
		}
	}
}

void GLERROR::SetExternalErrLog(int(*externalLog)(std::string&))
{
	sgpExternalOut = externalLog;
}

void GLERROR::ClearErrLog(void)
{
	std::string name;
	std::string out;
	name.resize(MAX_PATH);
	out.resize(MAX_PATH);
	_SYSTEMTIME sysTime;

	if (GLErrLogLevel < 0)
	{
		GLErrLogLevel &= 0x7FFFFFFFu;
		GLERROR::MakeErrLogName(out, "err.bak");
		GLERROR::MakeErrLogName(name, "err.log");
		GLFILE::PDelete(out);
		GLFILE::PRename(name, out);
		GLFILE::PDelete(name);
		GLErrLogLevel |= 0x80000000;
		GetSystemTime(&sysTime);
		GLERROR::WriteErrLog(
			"Error log started, %d/%d/%d, %d:%d:%d\r\n",
			sysTime.wMonth,
			sysTime.wDay,
			sysTime.wYear,
			sysTime.wHour,
			sysTime.wMinute,
			sysTime.wSecond);
	}
}

void GLERROR::ClearErrLogLine(void)
{
	if (GLErrLogLevel < 0)
	{
		GLErrLogLevel &= 0x7FFFFFFF;
		std::string dest;
		dest.resize(MAX_PATH);
		GLERROR::MakeErrLogName(dest, "err.log");
		HANDLE hFile = GLFILE::POpen(dest, WRITE_ONLY);
		if (hFile != INVALID_HANDLE_VALUE)
		{
			int fp = GLFILE::PLSeek(hFile, 0, FILE_END);
			BOOL breakNextLoop = FALSE;
			while (fp > 0)
			{
				fp = GLFILE::PLSeek(hFile, fp - 1, 0);
				char buff;
				GLFILE::PRead(hFile, &buff, sizeof(buff));
				if (buff != '\r' && buff != '\n')
				{
					breakNextLoop = TRUE;
				}
				else if (breakNextLoop)
				{
					break;
				}
			}
			SetEndOfFile(hFile);
			GLFILE::PClose(hFile);
		}
		GLErrLogLevel |= 0x80000000;
	}
}

void GLERROR::ErrorMsg(const char* str, ...)
{
	va_list arglist;

	va_start(arglist, str);
	if (str)
	{
		std::string text;
		text.resize(1024);
		vsprintf(text.data(), str, arglist);
		GLERROR::WriteErrLog(text.c_str());
		MessageBox(nullptr, text.c_str(), "GLERROR", MB_ICONERROR | MB_TASKMODAL);
	}
}

void GLERROR::ResErrorMsg(UINT uID)
{
	std::string stringBuf;
	stringBuf.resize(1024);

	if (LoadStringA(thisInstance, uID, stringBuf.data(), stringBuf.length()))
	{
		std::string vsprintBuf;
		vsprintBuf.resize(1024);
		vsprintf(vsprintBuf.data(), stringBuf.c_str(), vsprintBuf.data());
		GLERROR::WriteErrLog(vsprintBuf.c_str());
		MessageBox(nullptr, vsprintBuf.c_str(), "GLERROR", MB_ICONERROR | MB_TASKMODAL);
	}
}