module dio.file;

import dio.core;
version(Windows)
{
    import dio.sys.windows;
}
else version(Posix)
{
    import std.conv;
    import core.sys.posix.sys.types;
    import core.sys.posix.sys.stat;
    import core.sys.posix.fcntl;
    import core.sys.posix.unistd;
    import core.stdc.errno;
    import core.stdc.stdio : SEEK_SET;
    alias int HANDLE;
}

debug
{
    import std.stdio : writeln, writefln;
}

/**
File is seekable device.
*/
struct File
{
private:
  version(Windows)
  {
    HANDLE hFile = null;
  }
  version(Posix)
  {
    private HANDLE hFile = -1;
  }
    size_t* pRefCounter;

public:
    /**
    */
    this(string fname, in char[] mode = "r")
    {
      version(Posix)
      {
        int flags;
        int share = octal!666;

        switch (mode)
        {
            case "r":
                flags = O_RDONLY;
                break;
            case "w":
                flags = O_WRONLY | O_CREAT | O_TRUNC;
                break;
            case "a":
                flags = O_WRONLY | O_CREAT | O_TRUNC | O_APPEND;
                break;
            case "r+":
                flags = O_RDWR;
                break;
            case "w+":
                flags = O_RDWR | O_CREAT | O_TRUNC;
                break;
            case "a+":
                flags = O_RDWR | O_CREAT | O_TRUNC | O_APPEND;
                break;
            default:
                assert(0);
        }
        attach(core.sys.posix.fcntl.open(std.utf.toUTFz!(const char*)(fname),
                                         flags | O_NONBLOCK, share));
      }
      version(Windows)
      {
        int share = FILE_SHARE_READ | FILE_SHARE_WRITE;
        int access = void;
        int createMode = void;

        // fopenにはOPEN_ALWAYSに相当するModeはない？
        switch (mode)
        {
            case "r":
                access = GENERIC_READ;
                createMode = OPEN_EXISTING;
                break;
            case "w":
                access = GENERIC_WRITE;
                createMode = CREATE_ALWAYS;
                break;
            case "a":
                assert(0);

            case "r+":
                access = GENERIC_READ | GENERIC_WRITE;
                createMode = OPEN_EXISTING;
                break;
            case "w+":
                access = GENERIC_READ | GENERIC_WRITE;
                createMode = CREATE_ALWAYS;
                break;
            case "a+":
                assert(0);

            // do not have binary mode(binary access only)
        //  case "rb":
        //  case "wb":
        //  case "ab":
        //  case "rb+": case "r+b":
        //  case "wb+": case "w+b":
        //  case "ab+": case "a+b":
            default:
                break;
        }

        attach(CreateFileW(std.utf.toUTFz!(const(wchar)*)(fname),
                           access, share, null, createMode, 0, null));
      }
    }
    package this(HANDLE h)
    {
        attach(h);
    }
    this(this)
    {
        if (pRefCounter)
            ++(*pRefCounter);
    }
    ~this()
    {
        detach();
    }

    @property HANDLE handle() { return hFile; }

    //
    //@property inout(HANDLE) handle() inout { return hFile; }
    //alias handle this;

    bool opEquals(ref const File rhs) const
    {
        return hFile == rhs.hFile;
    }
    bool opEquals(HANDLE h) const
    {
        return hFile == h;
    }


    /**
    */
    void attach(HANDLE h)
    {
        if (hFile)
            detach();
        hFile = h;
        pRefCounter = new size_t;
        *pRefCounter = 1;
    }
    /// ditto
    void detach()
    {
        if (pRefCounter && *pRefCounter > 0)
        {
            if (--(*pRefCounter) == 0)
            {
                //delete pRefCounter;   // trivial: delegate management to GC.
              version(Windows)
              {
                CloseHandle(cast(HANDLE)hFile);
                hFile = null;
              }
              version(Posix)
              {
                core.sys.posix.unistd.close(hFile);
                hFile = -1;
              }
            }
            //pRefCounter = null;       // trivial: do not need
        }
    }

    //typeof(this) dup() { return this; }
    //typeof(this) dup() shared {}

    /**
    Request n number of elements.
    $(D buf) is treated as an output range.
    Returns:
        $(UL
            $(LI $(D true ) : You can request next pull.)
            $(LI $(D false) : No element exists.))
    */
    bool pull(ref ubyte[] buf)
    {
        static import std.stdio;
        debug(File)
            std.stdio.writefln("ReadFile : buf.ptr=%08X, len=%s", cast(uint)buf.ptr, buf.length);

      version(Posix)
      {
    Lagain:
        ssize_t n = core.sys.posix.unistd.read(hFile, buf.ptr, buf.length);
        if (n >= 0)
        {
            buf = buf[n .. $];
            return (n > 0);
        }
        switch (errno)
        {
            case EAGAIN:
                return true;
            case EINTR:
                goto Lagain;
            default:
                break;
        }
        throw new Exception("pull(ref buf[]) error");
      }
      version(Windows)
      {
        DWORD size = void;

        if (ReadFile(hFile, buf.ptr, buf.length, &size, null))
        {
            debug(File)
                std.stdio.writefln("pull ok : hFile=%08X, buf.length=%s, size=%s, GetLastError()=%s",
                    cast(uint)hFile, buf.length, size, GetLastError());
            debug(File)
                std.stdio.writefln("F buf[0 .. %d] = [%(%02X %)]", size, buf[0 .. size]);
            buf = buf[size.. $];
            return (size > 0);  // valid on only blocking read
        }

        switch (GetLastError())
        {
            case ERROR_BROKEN_PIPE:
                return false;
            default:
                break;
        }

            debug(File)
                std.stdio.writefln("pull ng : hFile=%08X, size=%s, GetLastError()=%s",
                    cast(uint)hFile, size, GetLastError());
            throw new Exception("pull(ref buf[]) error");

        //  // for overlapped I/O
        //  eof = (GetLastError() == ERROR_HANDLE_EOF);
        }
    }

    /**
    */
    bool push(ref const(ubyte)[] buf)
    {
      version(Posix)
      {
    Lagain:
        ssize_t n = core.sys.posix.unistd.write(hFile, buf.ptr, buf.length);
        if (n >= 0)
        {
            buf = buf[n .. $];
            return true;//(n > 0);
        }
        switch (errno)
        {
            case EAGAIN:
                return true;
            case EPIPE:
                return false;
            case EINTR:
                goto Lagain;
            default:
                break;
        }
        throw new Exception("push error");  //?
      }
      version(Windows)
      {
        DWORD size = void;
        if (WriteFile(hFile, buf.ptr, buf.length, &size, null))
        {
            buf = buf[size .. $];
            return true;    // (size == buf.length);
        }

        throw new Exception("push error");  //?
      }
    }

    bool flush()
    {
      version(Posix)
      {
        return core.sys.posix.unistd.fsync(hFile) == 0;
      }
      version(Windows)
      {
        return FlushFileBuffers(hFile) != FALSE;
      }
    }

    /**
    */
    @property bool seekable()
    {
      version(Posix)
      {
        if (core.sys.posix.unistd.lseek(hFile, 0, SEEK_SET) == -1)
        {
            switch (errno)
            {
                case ESPIPE:
                    return false;
                default:
                    break;
            }
        }
        return true;
      }
      version(Windows)
      {
        return GetFileType(hFile) != FILE_TYPE_CHAR;
      }
    }

    /**
    */
    ulong seek(long offset, SeekPos whence)
    {
      version(Windows)
      {
        int hi = cast(int)(offset>>32);
        uint low = SetFilePointer(hFile, cast(int)offset, &hi, whence);
        if ((low == INVALID_SET_FILE_POINTER) && (GetLastError() != 0))
            throw new /*Seek*/Exception("unable to seek file pointer");
        ulong result = (cast(ulong)hi << 32) + low;
      }
      else version (Posix)
      {
        auto result = lseek(hFile, cast(int)offset, whence);
        if (result == cast(typeof(result))-1)
            throw new /*Seek*/Exception("unable to seek file pointer");
      }
      else
      {
        static assert(false, "not yet supported platform");
      }

        return cast(ulong)result;
    }
}
static assert(isSource!File);
static assert(isSink!File);

version(unittest)
{
    import std.algorithm;
}
unittest
{
    auto file = File(__FILE__);
    ubyte[] buf = new ubyte[64];
    ubyte[] b = buf;
    while (file.pull(b)) {}
    buf = buf[0 .. $-b.length];

    assert(buf.length == 64);
    debug std.stdio.writefln("buf = [%(%02x %)]\n", buf);
    assert(startsWith(buf, "module dio.file;\n"));
}


/**
Wrapping array with $(I source) interface.
*/
struct ArraySource(E)
{
    const(E)[] array;

    @property auto handle() { return array; }

    bool pull(ref E[] buf)
    {
        if (array.length == 0)
            return false;
        if (buf.length <= array.length)
        {
            buf[] = array[0 .. buf.length];
            array = array[buf.length .. $];
            buf = buf[$ .. $];
        }
        else
        {
            buf[0 .. array.length] = array[];
            buf = buf[array.length .. $];
            array = array[$ .. $];
        }
        return true;
    }
}

unittest
{
    import dio.port;

    auto r = ArraySource!char("10\r\ntest\r\n").buffered.ranged;
    long num;
    string str;
    readf(r, "%s\r\n", &num);
    readf(r, "%s\r\n", &str);
    assert(num == 10);
    assert(str == "test");
}
