module dio.file;

import dio.core;
import std.utf;
version(Windows)
{
    import dio.sys.windows;
}

debug
{
    static import std.stdio;
}

/**
File is seekable device.
*/
struct File
{
private:
    HANDLE hFile;
    size_t* pRefCounter;

public:
    /**
    */
    this(string fname, in char[] mode = "r")
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

        auto h = CreateFileW(toUTFz!(const(wchar)*)(fname),
                             access, share, null, createMode, 0, null);
        import std.exception;
        enforce(h !is INVALID_HANDLE_VALUE, sysErrorString(GetLastError()));
        attach(h);
    }
    package this(HANDLE h)
    {
        attach(h);
    }
    this(this) nothrow
    {
        if (pRefCounter)
            ++(*pRefCounter);
    }
    ~this() nothrow
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
    void detach() nothrow
    {
        try
        {
            if (pRefCounter && *pRefCounter > 0)
            {
                if (--(*pRefCounter) == 0)
                {
                    //delete pRefCounter;   // trivial: delegate management to GC.
                    CloseHandle(cast(HANDLE)hFile);
                }
                //pRefCounter = null;       // trivial: do not need
            }
        }
        catch (Throwable e)
            return;
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
        debug(File)
            std.stdio.writefln("ReadFile : buf.ptr=%08X, len=%s", cast(uint)buf.ptr, buf.length);

        DWORD size = void;

        if (ReadFile(hFile, buf.ptr, cast(DWORD)buf.length, &size, null))
        {
            debug(File)
                std.stdio.writefln("pull ok : hFile=%08X, buf.length=%s, size=%s, GetLastError()=%s",
                    cast(uint)hFile, buf.length, size, GetLastError());
            debug(File)
                std.stdio.writefln("F buf[0 .. %d] = [%(%02X %)]", size, buf[0 .. size]);
            buf = buf[size.. $];
            return (size > 0);  // valid on only blocking read
        }

        {
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
        DWORD size = void;
        if (WriteFile(hFile, buf.ptr, cast(DWORD)buf.length, &size, null))
        {
            buf = buf[size .. $];
            return true;    // (size == buf.length);
        }

        {
            throw new Exception("push error");  //?
        }
    }

    bool flush()
    {
        return FlushFileBuffers(hFile) != FALSE;
    }

    /**
    */
    @property bool seekable()
    {
        return GetFileType(hFile) != FILE_TYPE_CHAR;
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
