#include <Windows.h>
#include "GLERROR.h"
#include "GLFILE.H"

static char slash = 92;

int GLFILE::GetGLFILEError(void)
{
    int error = GetLastError();
    GLERROR::SetError(error);

    return error > 0 ? ~error : error;
}

HANDLE GLFILE::POpen(const std::string& name, int mode)
{   
    DWORD shareMode = 0;
    DWORD desiredAccess = GENERIC_WRITE;
    switch (mode & 0x7FFF)
    {
    case GLFILE_MODES::READ_ONLY:
        desiredAccess = GENERIC_READ;
        shareMode = FILE_SHARE_READ;
        break;
    case GLFILE_MODES::READ_WRITE:
        desiredAccess = GENERIC_WRITE | GENERIC_READ;
        break;
    default:
        break;
    }

    DWORD flags = FILE_FLAG_SEQUENTIAL_SCAN;
    if ((desiredAccess & 0x8000) == 0)
        flags = 0;

    HANDLE hFile = CreateFile(name.c_str(), desiredAccess, shareMode, nullptr, OPEN_EXISTING, flags | FILE_ATTRIBUTE_NORMAL, nullptr);
    if (hFile == INVALID_HANDLE_VALUE)
    {
        GetGLFILEError();
        
        if (GLERROR::CheckErrorLevel(1))
            GLERROR::WriteErrLog("Error opening, %s (%s)\r\n", name.c_str(), GLERROR::GetStr());
        
    }
    else if (GLERROR::CheckErrorLevel(2))
        GLERROR::WriteErrLog("Opened, %s\r\n", name.c_str());
    
    return hFile;
}

HANDLE GLFILE::PCreate(const std::string& name, int mode)
{

    HANDLE hFile = CreateFile(name.c_str(), GENERIC_WRITE | GENERIC_READ, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (hFile == INVALID_HANDLE_VALUE)
    {
        GetGLFILEError();
        if (GLERROR::CheckErrorLevel(1))
            GLERROR::WriteErrLog("Error creating, %s (%s)\r\n", name.c_str(), GLERROR::GetStr());
        
    }
    else if (GLERROR::CheckErrorLevel(2))
        GLERROR::WriteErrLog("Created and opened, %s ref = %d\r\n", name.c_str(), hFile);
    
    return hFile;
}

void GLFILE::PClose(HANDLE hFile)
{
    if (CloseHandle(hFile))
    {
        if (GLERROR::CheckErrorLevel(2))
            GLERROR::WriteErrLog("Closed, %d\r\n", hFile);
    }
    else
    {
        GetGLFILEError();
        if (GLERROR::CheckErrorLevel(1))
            GLERROR::WriteErrLog("Error closing file, %d, (%s)\r\n", hFile, GLERROR::GetStr());
        
        GetGLFILEError();
    }
}

int GLFILE::PDelete(const std::string& name)
{
    if (DeleteFile(name.c_str()))
        return 0;

    GetGLFILEError();
    if (GLERROR::CheckErrorLevel(1))
        GLERROR::WriteErrLog("Error deleting file, %s, (%s)\r\n", name.c_str(), GLERROR::GetStr());
    
    return GetGLFILEError();
}

int GLFILE::PMakeDir(const std::string& name)
{
    _SECURITY_ATTRIBUTES security;

    security.nLength = sizeof(security);
    security.lpSecurityDescriptor = nullptr;
    security.bInheritHandle = FALSE;
    if (CreateDirectory(name.c_str(), &security))
        return 0;

    GetGLFILEError();

    if (GLERROR::CheckErrorLevel(1))
        GLERROR::WriteErrLog("Error creating directory, %s, (%s)\r\n", name.c_str(), GLERROR::GetStr());

    return GetGLFILEError();
}

DWORD GLFILE::PRead(HANDLE fd, void* buff, DWORD len)
{
    DWORD nBytes;

    if (ReadFile(fd, buff, len, &nBytes, nullptr))
    {
        if (GLERROR::CheckErrorLevel(4))
            GLERROR::WriteErrLog("Read from file, ref = %d, buff = %d, size = %d\r\n", fd, buff, nBytes);
        return nBytes;
    }

    GetGLFILEError();
    if (GLERROR::CheckErrorLevel(1))
        GLERROR::WriteErrLog("Error reading from file, ref = %d, buff = %d, size = %d, (%s)\r\n", fd, buff, len, GLERROR::GetStr());
    
    return GetGLFILEError();

}

int GLFILE::PWrite(HANDLE fd, const void* buf, DWORD bufSize)
{
    DWORD nBytes;

    if (WriteFile(fd, buf, bufSize, &nBytes, nullptr))
    {
        if (GLERROR::CheckErrorLevel(8))
            GLERROR::WriteErrLog("Write to file, ref = %d, buff = %d, size = %d\r\n", fd, buf, nBytes);
        return nBytes;
    }

    GetGLFILEError();
    if (GLERROR::CheckErrorLevel(1))
        GLERROR::WriteErrLog("Error writing to file, ref = %d, buff = %d, size = %d, (%s)\r\n", fd, buf, bufSize, GLERROR::GetStr());

    return GetGLFILEError();
}

DWORD GLFILE::PLSeek(HANDLE fd, LONG lDistanceToMove, DWORD dwMoveMethod)
{
    DWORD fp = SetFilePointer(fd, lDistanceToMove, nullptr, dwMoveMethod);
    if (fp == INVALID_SET_FILE_POINTER)
    {
        GetGLFILEError();
        if (GLERROR::CheckErrorLevel(1))
        {
            GLERROR::WriteErrLog(
                "Error seeking in file, ref = %d, pos = %d, mode = %d, (%s)\r\n",
                fd,
                lDistanceToMove,
                dwMoveMethod,
                GLERROR::GetStr());
        }
    }
    return fp;
}

DWORD GLFILE::PSize(HANDLE fd)
{
    DWORD size = GetFileSize(fd, 0);
    if (size == -1)
    {
        GetGLFILEError();
        if (GLERROR::CheckErrorLevel(1))
            GLERROR::WriteErrLog("Error getting file size, ref = %d, (%s)\r\n", fd, GLERROR::GetStr());
        
    }
    return size;
}

int GLFILE::PRename(const std::string& currFileName, const std::string& newFileName)
{
    if (MoveFile(currFileName.c_str(), newFileName.c_str()))
        return 0;

    GetGLFILEError();

    if (GLERROR::CheckErrorLevel(1))
        GLERROR::WriteErrLog("Error renaming %s to %s, (%s)\r\n", currFileName.c_str(), newFileName.c_str(), GLERROR::GetStr());
    
    return GetGLFILEError();
}

void GLFILE::PGetApplicationPath(std::string& dest)
{
    if (dest.length() < MAX_PATH)
        dest.resize(MAX_PATH);

    std::string fileName;
    fileName.resize(MAX_PATH);

    dest.at(0) = '\0';
    if (GetModuleFileName(nullptr, fileName.data(), fileName.length()))
        PGetDir(fileName.c_str(), dest.data());
}

BOOL GLFILE::PFileExists(const std::string& name)
{
    HANDLE hFile = POpen(name, READ_ONLY);

    if (hFile == INVALID_HANDLE_VALUE)
        return FALSE;

    PClose(hFile);
    return TRUE;
}

void GLFILE::PStarClose(GLFILE_DATA& fl)
{
    if (fl.hFile && fl.hFile != INVALID_HANDLE_VALUE)
        FindClose(fl.hFile);
    fl.hFile = nullptr;
}

BOOL GLFILE::PStarInit(const std::string& iname, int attrib, GLFILE_DATA& fl)
{
    const char* pFileName = iname.c_str();
    ZeroMemory(&fl, sizeof(GLFILE_DATA));

    const char* pIName = iname.data() - 1;
    do
        ++pIName;
    while (*pIName);

    do
        --pIName;
    while (iname <= pIName && *pIName != ':' && *pIName != '/' && *pIName != '\\');
    
    ++pIName;

    std::string fileName;
    char* pBuffer = fl.pathBuffer;
    while (1)
    {
        if (!*pIName)
        {
            fl.hasDot = FALSE;
            fileName = iname + ".*";
            *pBuffer++ = '.';
            *pBuffer++ = '*';
            pFileName = fileName.c_str();
            goto finish;
        }
        if (*pIName == '.')
            break;
        if (pBuffer < &fl.pathBuffer[8])
            *pBuffer++ = *pIName;
        ++pIName;
    }

    fl.hasDot = TRUE;
    {
        char* tmp = pBuffer;
        while (*pIName && pBuffer < tmp + 4)
            *pBuffer++ = *pIName++;
    }

finish:
    *pBuffer = '\0';
    fl.hFile = FindFirstFileA(pFileName, &fl.find_data);

    if (fl.hFile == INVALID_HANDLE_VALUE)
        return FALSE;

    fl.validHandle = TRUE;
    return TRUE;
}

BOOL GLFILE::PStarMatch(char* name, char* starname)
{
    char* pStarName; // ebx
    char* i; // esi
    int numCharsUppered; // edi

    pStarName = starname;
    for (i = name; ; ++i)
    {
        if (!*pStarName)
            return (unsigned int)*i < 1;
        if (*pStarName == '*')
            break;
        if (*pStarName == '?')
        {
            if (!*i)
                return FALSE;
        }
        else
        {
            numCharsUppered = toupper(*pStarName);
            if (numCharsUppered != toupper(*i))
                return FALSE;
        }
        ++pStarName;
    }
    if (!pStarName[1])
        return TRUE;
    if (pStarName[1] == '.' && !pStarName[2])
        return TRUE;
    if (pStarName[1] == '.' && pStarName[2] == '*' && !pStarName[3])
        return TRUE;
    while (*i)
    {
        if (PStarMatch(i, pStarName + 1))
            return TRUE;
        ++i;
    }
    return FALSE;
}

void GLFILE::PGdot(GLFILE_DATA& fl)
{
    if (!(fl.find_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY))
    {
        char* pc = sindex(fl.find_data.cFileName, '.');
        if (!*pc)
        {
            *pc = '.';
            pc[1] = '\0';
        }
    }
}

char* GLFILE::PStarNext(GLFILE_DATA& fl)
{
    do
    {
        if (!fl.validHandle && !FindNextFileA(fl.hFile, &fl.find_data))
            return nullptr;

        fl.validHandle = FALSE;
        if (fl.hasDot)
            PGdot(fl);

    } while (!PStarMatch(fl.find_data.cFileName, fl.pathBuffer));

    if (!fl.hasDot)
        PGdot(fl);

    return fl.find_data.cFileName;
}

char* GLFILE::PGetStart(char* str)
{
    char* pc = &str[strlen(str)];
    do
        --pc;
    while (str <= pc && *pc != ':' && *pc != '/' && *pc != '\\');
    if (*pc == '/')
        slash = '/';
    return pc + 1;
}

BOOL GLFILE::PIsDir(const std::string& dir)
{
    if ((dir.find('/')) != dir.npos || (dir.find('\\')) != dir.npos || (dir.find(':')) != dir.npos)
            return TRUE;
    
    return FALSE;
}

void GLFILE::PGetDir(const char* name, char* dir)
{
    char* pDest = dir;
    strcpy(dir, name);
    char* pStart = PGetStart(dir);
    if (pStart >= dir + 2 && dir[1] == ':')
        pDest = dir + 2;
    if (pStart > pDest + 1)
        --pStart;
    *pStart = '\0';
}

void GLFILE::PGetBase(char* name, std::string& base)
{
    char* start = PGetStart(name);
    base = start;
    *sindex(base.data(), '.') = '\0';
}

void GLFILE::PGetExt(char* name, std::string& ext_buffer)
{
    char* start = PGetStart(name);
    char* index = sindex(start, '.');
    if (*index)
        ++index;

    ext_buffer = index;
}

BOOL GLFILE::PSetExt(std::string& name, const std::string& ext, BOOL force)
{
    auto pEnd = name.rbegin();
    
    for (auto it = name.rbegin(); it != name.rend(), *it != '\\'; --it)
    {
        if (*it == '.')
        {
            if (!force)
                return FALSE;
            pEnd = it;
            break;
        }
        if (*it == '/')
        {
            slash = '/';
            break;
        }
    }

    *pEnd = '.';
    pEnd++;

    for (; pEnd != name.rbegin(); --pEnd)
        *pEnd = '\0';
    
    name += ext;

    return TRUE;
}

void GLFILE::PGetName(char* name, std::string& to)
{
    char* start = PGetStart(name);
    to = start;
}

void GLFILE::PSetDir(std::string& name, std::string& dir, BOOL force)
{
    if (force || !PIsDir(name))
    {
        std::string dest(dir);
        PSetName(dest.data(), name.data());
        name = dest;
    }
}

void GLFILE::PSetName(char* dir, char* name)
{
    char* pChar = &dir[strlen(dir)];
    if (*dir && (dir[1] != ':' || dir[2]) && *(pChar - 1) != '/' && *(pChar - 1) != '\\')
        *pChar++ = slash;
    char* pStart = PGetStart(name);
    strcpy(pChar, pStart);
}

char* GLFILE::sindex(char* str, char chr)
{
    if (!str)
        return nullptr;

    char c;
    char* start = str;
    do
        c = *start++;
    while (c != chr && c);

    return start - 1;
}