//io.core module;
/**
core module for new I/O
*/
module dio.core;

/**
Retruns element type of device.
*/
template DeviceElementType(Dev)
{
    import std.traits;

    static if (is(ParameterTypeTuple!(typeof(Dev.init.pull)) PullArgs))
    {
        alias Unqual!(ForeachType!(PullArgs[0])) DeviceElementType;
    }
    else static if (is(typeof(Dev.init.available) AvailableType))
    {
        alias Unqual!(ForeachType!AvailableType) DeviceElementType;
    }
    else static if (is(ParameterTypeTuple!(typeof(Dev.init.push)) PushArgs))
    {
        alias Unqual!(ForeachType!(PushArgs[0])) DeviceElementType;
    }
}

/**
Returns $(D true) if $(D Dev) is a $(I source). It must define the
primitive $(D pull).

$(D pull) operation provides synchronous but non-blocking input.
*/
template isSource(Dev)
{
    enum isSource = is(typeof(
    {
        Dev d = void;
        alias DeviceElementType!Dev E;
        E[] buf;
        while (d.pull(buf)) {}
    }));
}

/**
Returns $(D true) if $(D Dev) is a $(I sink). It must define the
primitive $(D push).

$(D push) operation provides synchronous but non-blocking output.
*/
template isSink(Dev)
{
    enum isSink = is(typeof(
    {
        Dev d = void;
        alias DeviceElementType!Dev E;
        const(E)[] buf;
        do {} while (d.push(buf));
    }));
}

/**
Returns $(D true) if $(D Dev) is a buffered $(I source). It must define the
three primitives, $(D fetch), $(D available), and $(D consume).

In definition, initial state of buffered $(I source) has 0 length $(D available).
It assumes that the buffer is not $(D fetch)-ed yet.
*/
template isBufferedSource(Dev)
{
    enum isBufferedSource = is(typeof(
    {
        Dev d = void;
        alias DeviceElementType!Dev E;
        while (d.fetch())
        {
            const(E)[] buf = d.available;
            size_t n;
            d.consume(n);
        }
    }));
}

/**
Returns $(D true) if $(D Dev) is a buffered $(I sink). It must define the
three primitives, $(D flush), $(D writable), and $(D commit).
*/
template isBufferedSink(Dev)
{
    enum isBufferedSink = is(typeof(
    {
        Dev d = void;
        alias DeviceElementType!Dev E;
        d.writable[0] = E.init;
        d.commit(1);
        if (d.flush()){}
    }));
}

// seek whence...
enum SeekPos
{
    Set,
    Cur,
    End
}

/**
Check that $(D Dev) is seekable $(I source) or $(I sink).
Seekable device supports $(D seek) primitive.
*/
template isSeekable(Dev)
{
    enum isSeekable = is(typeof({
        Dev d = void;
        if (d.seekable)
            d.seek(0, SeekPos.Set);
    }()));
}

/**
Device supports both primitives of $(I source) and $(I sink).
*/
template isDevice(Dev)
{
    enum isDevice = isSource!Dev && isSink!Dev;
}


/**
Provides runtime $(I source) interface.
*/
interface Source(E)
{
    ///
    bool pull(ref E[] buf);
}

/**
Provides runtime $(I sink) interface.
*/
interface Sink(E)
{
    ///
    bool push(ref const(E)[] buf);
}

/**
Provides runtime buffered $(I source) interface.
*/
interface BufferedSource(E) : Source!E
{
    ///
    bool fetch();

    /// ditto
    @property const(E)[] available() const;

    /// ditto
    void consume(size_t n);
}

/**
Provides runtime buffered $(I sink) interface.
*/
interface BufferedSink(E) : Sink!E
{
    ///
    bool flush();

    /// ditto
    @property E[] writable();

    /// ditto
    bool commit(size_t n);
}

/**
Provides runtime seekable interface.
*/
interface Seekable
{
    ///
    @property bool seekable();

    /// ditto
    ulong seek(long offset, SeekPos whence);
}


/**
Disable sink interface of $(D device).
If $(D device) has buffered interface, keep it.
*/
template Sourced(Dev)
{
    alias typeof((Dev* d = null){ return (*d).sourced; }()) Sourced;
}

/// ditto
@property auto sourced(Dev)(Dev device)
    if (isSource!Dev && isSink!Dev)
{
    static struct Sourced
    {
    private:
        alias DeviceElementType!Dev E;
        Dev device;

    public:
        this(Dev d)
        {
            //move(d, device);
            device = d;
        }

        @property auto handle() { return device.handle; }

        bool pull(ref E[] buf)
        {
            return device.pull(buf);
        }

      static if (isBufferedSource!Dev)
      {
        bool fetch()
        {
            return device.fetch();
        }
        @property const(E)[] available() const
        {
            return device.available;
        }
        void consume(size_t n)
        {
            device.consume(n);
        }
      }
    }

    return Sourced(device);
}

/// ditto
@property auto sourced(Dev)(Dev device)
    if (isSource!Dev && !isSink!Dev)
{
    return device;
}

unittest
{
    import dio.file;

    alias typeof(File.init.sourced) InputFile;
    static assert( isSource!InputFile);
    static assert(!isSink!InputFile);

    alias typeof(InputFile.init.sourced) InputFile2;
    static assert( isSource!InputFile2);
    static assert(!isSink!InputFile2);
    static assert(is(InputFile == InputFile2));

    alias typeof(File.init.buffered.sourced) BufferedInputFile;
    static assert( isSource!BufferedInputFile);
    static assert( isBufferedSource!BufferedInputFile);
    static assert(!isSink!BufferedInputFile);
}

/**
Disable source interface of $(D device).
*/
template Sinked(Dev)
{
    alias typeof((Dev* d = null){ return (*d).sinked; }()) Sinked;
}

/// ditto
@property auto sinked(Dev)(Dev device)
    if (isSource!Dev && isSink!Dev)
{
    static struct Sinked
    {
    private:
        alias DeviceElementType!Dev E;
        Dev device;

    public:
        this(Dev d)
        {
            device = d;
        }

        @property auto handle() { return device.handle; }

        bool push(ref const(E)[] buf)
        {
            return device.push(buf);
        }

      static if (is(typeof(device.flush())))
        bool flush()
        {
            return device.flush();
        }
    }

    return Sinked(device);
}

/// ditto
@property auto sinked(Dev)(Dev device)
    if (!isSource!Dev && isSink!Dev)
{
    return device;
}

unittest
{
    import dio.file;

    alias typeof(File.init.sinked) OutputFile;
    static assert(!isSource!OutputFile);
    static assert( isSink!OutputFile);

    alias typeof(OutputFile.init.sinked) OutputFile2;
    static assert(!isSource!OutputFile2);
    static assert( isSink!OutputFile2);
    static assert(is(OutputFile == OutputFile2));

    alias typeof(File.init.buffered.sinked) BufferedOutputFile;
    static assert(!isSource!BufferedOutputFile);
    static assert(!isBufferedSource!BufferedOutputFile);
    static assert( isSink!BufferedOutputFile);
}

/**
*/
template Buffered(Dev)
{
    alias typeof((Dev* d = null){ return (*d).buffered; }()) Buffered;
}

/// ditto
@property auto buffered(Dev)(Dev device, size_t bufferSize = 4096)
    if (isSource!Dev || isSink!Dev)
{
    static struct Buffered
    {
        import std.algorithm : min, max;

    private:
        alias DeviceElementType!Dev E;

        Dev device;
        E[] buffer;
        static if (isSink  !Dev) size_t rsv_start = 0, rsv_end = 0;
        static if (isSource!Dev) size_t ava_start = 0, ava_end = 0;
        static if (isDevice!Dev) long base_pos = 0;

        int _dummy;

    public:
        /**
        */
        this(Dev d, size_t bufferSize)
        {
            device = d;
            buffer.length = bufferSize;
        }

        @property auto handle() { return device.handle; }

      static if (isSink!Dev)
        ~this()
        {
            while (reserves.length > 0)
                flush();
        }

      static if (isSource!Dev)
      {
        /**
        primitives of source.
        */
        bool pull(ref E[] buf)
        {
            auto av = available;
            if (buf.length < av.length)
            {
                buf[] = av[0 .. buf.length];
                consume(buf.length);
                buf = buf[$ .. $];
                return true;
            }
            else
            {
                buf[0 .. av.length] = av[];
                buf = buf[av.length .. $];
                consume(av.length);
                return fetch();
            }
        }

        /**
        primitives of buffered $(I source).
        */
        bool fetch()
        body
        {
          static if (isDevice!Dev)
            bool empty_reserves = (reserves.length == 0);
          else
            enum empty_reserves = true;

            if (empty_reserves && available.length == 0)
            {
                static if (isDevice!Dev) base_pos += ava_end;
                static if (isDevice!Dev) rsv_start = rsv_end = 0;
                                         ava_start = ava_end = 0;
            }

          static if (isDevice!Dev)
          {
            if (device.seekable)
                device.seek(base_pos + ava_end, SeekPos.Set);
          }

            auto v = buffer[ava_end .. $];
            auto result = device.pull(v);
            if (result)
            {
                ava_end = buffer.length - v.length;
            }
            return result;
        }

        /// ditto
        @property const(E)[] available() const
        {
            return buffer[ava_start .. ava_end];
        }

        /// ditto
        void consume(size_t n)
        in { assert(n <= available.length); }
        body
        {
            ava_start += n;
        }
      }

      static if (isSink!Dev)
      {
        /**
        primitive of sink.
        */
        bool push(ref const(E)[] data)
        {
        //  return device.push(data);

            while (data.length > 0)
            {
                if (writable.length == 0)
                    if (!flush()) goto Exit;
                auto len = min(data.length, writable.length);
                writable[0 .. len] = data[0 .. len];
                data = data[len .. $];
                commit(len);
            }
            if (writable.length == 0)
                if (!flush()) goto Exit;

            return true;
          Exit:
            return false;
        }

        /*
        primitives of buffered $(I sink).
        */
        bool flush()
        {
            if (reserves.length == 0)
                return true;

          static if (isDevice!Dev)
          {
            if (device.seekable)
                device.seek(base_pos + rsv_start, SeekPos.Set);
          }

            const(E)[] rsv = buffer[rsv_start .. rsv_end];
            auto result = device.push(rsv);
            if (result)
            {
                rsv_start = rsv_end - rsv.length;

              static if (isDevice!Dev)
                bool empty_available = (available.length == 0);
              else
                enum empty_available = true;

                if (reserves.length == 0 && empty_available)
                {
                    static if (isDevice!Dev)    base_pos += ava_end;
                    static if (isDevice!Dev)    ava_start = ava_end = 0;
                                                rsv_start = rsv_end = 0;
                }
            }
            return result;
        }

        /// ditto
        @property E[] writable()
        {
          static if (isDevice!Dev)
            return buffer[ava_start .. $];
          else
            return buffer[rsv_end .. $];
        }

        private @property const(E)[] reserves()
        {
            return buffer[rsv_start .. rsv_end];
        }

        /// ditto
        void commit(size_t n)
        {
          static if (isDevice!Dev)
          {
            assert(ava_start + n <= buffer.length);
            ava_start += n;
            ava_end = max(ava_end, ava_start);
            rsv_end = ava_start;
          }
          else
          {
            assert(rsv_end + n <= buffer.length);
            rsv_end += n;
          }
        }
      }
    }

    import std.typecons;
    return RefCounted!Buffered(device, bufferSize);
}

version(unittest)
{
    import dio.file;
    import std.algorithm;
}
unittest
{
    auto file = File(__FILE__).buffered;
    file.fetch();
    assert(startsWith(file.available, "//io.core module;\n"));
}

/**
Change device element type from $(D ubyte) to $(D E).
While device operation, remain bytes are cached.
*/
template Coerced(E, Dev)
{
    alias typeof((Dev* d = null){ return (*d).coerced!E; }()) Coerced;
}

/// ditto
@property auto coerced(E, Dev)(Dev device)
    if ((isSource!Dev || isSink!Dev) &&
        is(DeviceElementType!Dev == ubyte))
{
    static struct Coerced
    {
    private:
        Dev device;
      static if (E.sizeof > 1)
      {
        ubyte[E.sizeof] remain;
        size_t begin, end;
      }

    public:
        this(Dev d)
        {
            device = d;
        }

        @property auto handle() { return device.handle; }

      static if (isSource!Dev)
        bool pull(ref E[] buf)
        {
            auto v = cast(ubyte[])buf;
            auto w = v;

          static if (E.sizeof > 1)
            if (auto r = end - begin)
                v = v[r .. $];

            auto result = device.pull(v);
            if (result)
            {
                //static import std.stdio;
                //std.stdio.writefln("encoded.pull : buf = %(%02X %)", cast(ubyte[])buf);
              static if (E.sizeof > 1)
              {
                if (auto r = end - begin)
                {
                    w[0 .. r] = remain[begin .. end];
                    begin = end = 0;
                }
                auto nread = w.length - v.length;
                if (auto r = nread % E.sizeof)
                {
                    remain[0..r] = w[nread-r .. nread];
                    v = w[nread .. $];
                    begin = 0, end = r;
                }
              }
                buf = cast(E[])v;
            }
            return result;
        }

      static if (isBufferedSource!Dev)
      {
        bool fetch()
        {
            return device.fetch();
        }
        @property const(E)[] available() const
        {
            return cast(const(E)[])device.available;
        }
        void consume(size_t n)
        {
            device.consume(E.sizeof * n);
        }
      }

      static if (isSink!Dev)
        bool push(ref const(E)[] data)
        {
          static if (E.sizeof > 1)
            if (auto r = end - begin)
            {
                const(ubyte)[] v = remain[begin .. end];
                auto result = device.push(v);
                begin = end - v.length;
                if (v.length)
                    return result;
            }
            auto v = cast(const(ubyte)[])data;
            auto result = device.push(v);
            data = data[$ - v.length / E.sizeof .. $];
            return result;
        }

      static if (isSeekable!Dev)
      {
        @property bool seekable()
        {
            return device.seekable;
        }

        ulong seek(long offset, SeekPos whence)
        {
            return device.seek(offset, whence);
        }
      }

      static if (is(typeof(device.flush())))
        bool flush()
        {
            return device.flush();
        }
    }

    return Coerced(device);
}

unittest
{
    import dio.file;

    alias typeof(File.init.coerced!char) CharFile;
    static assert(is(DeviceElementType!CharFile == char));

    alias typeof(File.init.buffered.coerced!char) BufferedFile;
    static assert(is(DeviceElementType!BufferedFile == char));
}

/**
Generate possible range interface from $(D device).

If $(D device) is a buffered $(I source), input range interface is available.
If $(D device) is a $(I sink), output range interface is available.

If original $(D device) element is Unicode character, supports decoding and
encoding.
*/
template Ranged(Dev)
{
    alias typeof((Dev* d = null){ return (*d).ranged; }()) Ranged;
}

/// ditto
@property auto ranged(Dev)(Dev device)
    if (isBufferedSource!Dev || isSink!Dev)
{
    static struct Ranged
    {
    private:
        import std.traits;

        template isNarrowChar(T)
        {
            enum isNarrowChar = is(Unqual!T == char) || is(Unqual!T == wchar);
        }

        alias Unqual!(DeviceElementType!Dev) B;
        alias Select!(isNarrowChar!B, dchar, B) E;

        Dev device;
        bool eof;
        E front_val; bool front_ok;

    public:
        this(Dev d)
        {
            device = d;
        }

      static if (isBufferedSource!Dev)
      {
        @property bool empty()
        {
            /* Block in here if device is console */
            while (device.available.length == 0 && !eof)
                eof = !device.fetch();
            assert(eof || device.available.length > 0);
            return eof;
        }
        @property E front()
        {
            size_t i = 0;
            if (front_ok)
                return front_val;

            static if (isNarrowChar!B)
            {
                import std.utf;
                auto c = device.available[0];
                auto n = stride((&c)[0..1], 0);
                if (n == 1)
                {
                    device.consume(1);
                    front_ok = true;
                    front_val = c;
                    return c;
                }

                B[B.sizeof == 1 ? 6 : 2] ubuf;
                B[] buf = ubuf[0 .. n];
                while (buf.length > 0 && device.pull(buf)) {}
                i = 0;
                if (buf.length)
                    goto err;
                front_val = decode(ubuf[0 .. n], i);
            }
            else
            {
                front_val = device.available[0];
                device.consume(1);
            }
            front_ok = true;
            return front_val;

        err:
            throw new Exception("Unexpected failure of fetching value form underlying device");
        }
        void popFront()
        {
            //device.consume(1);
            front_ok = false;
        }
      }

      static if (isSink!Dev)
      {
        void put()(const(B)[] data)
        {
            // direct push
            while (device.push(data) && data.length) {}
            if (data.length)
                throw new Exception("");
        }

        void put()(const(dchar)[] data) if (isNarrowChar!B)
        {
            // with encoding
            import std.utf;
            foreach (c; data)
            {
                B[B.sizeof == 1 ? 4 : 2] ubuf;
                const(B)[] buf = ubuf[0 .. encode(ubuf, c)];
                while (device.push(buf) && buf.length) {}
                if (buf.length)
                    throw new Exception("");
            }
        }

        void put(C)(const(C)[] data) if (isNarrowChar!C && !is(B == C))
        {
            // with transcoding from narrows
            import std.utf;
            size_t i = 0;
            while (i < data.length)
            {
                dchar c = decode(data, i);
                B[B.sizeof == 1 ? 4 : 2] ubuf;
                const(B)[] buf = ubuf[0 .. encode(ubuf, c)];
                while (device.push(buf) && buf.length) {}
                if (buf.length)
                    throw new Exception("");
            }
        }
      }

      static if (is(typeof(device.flush())))
        bool flush()
        {
            return device.flush();
        }
    }

    return Ranged(device);
}

unittest
{
    import dio.file;
    import std.algorithm;

    auto file = File(__FILE__).buffered.coerced!char.ranged;
    assert(startsWith(file, "//io.core module;\n"));
}


private template _DeviceInterfaces(Dev)
{
    import std.typetuple;
    static if (isSource!Dev)
    {
        alias TypeTuple!(Source!(DeviceElementType!Dev)) T1;
    }
    else
    {
        alias TypeTuple!() T1;
    }
    static if (isSink!Dev)
    {
        alias TypeTuple!(T1, Sink!(DeviceElementType!Dev)) T2;
    }
    else
    {
        alias T1 T2;
    }
    static if (isBufferedSource!Dev)
    {
        alias TypeTuple!(T2, BufferedSource!(DeviceElementType!Dev)) T3;
    }
    else
    {
        alias T2 T3;
    }
    static if (isBufferedSink!Dev)
    {
        alias TypeTuple!(T3, BufferedSink!(DeviceElementType!Dev)) T4;
    }
    else
    {
        alias T3 T4;
    }
    static if (isSeekable!Dev)
    {
        alias TypeTuple!(T4, Seekable) T5;
    }
    else
    {
        alias T4 T5;
    }
    
    
    alias T5 _DeviceInterfaces;
}


/**
Change $(D device) type to interface.
*/
template Interfaced(Dev)
{
    alias typeof((Dev* d = null){ return (*d).interfaced; }()) Interfaced;
}

/// ditto
@property auto interfaced(Dev)(Dev device)
{
    alias DeviceElementType!Dev E;
    static class _DeviceAdapterClass: _DeviceInterfaces!Dev
    {
    private:
        Dev _dev;
    public:
        this(Dev dev)
        {
            _dev = dev;
        }
        
        static if (isSource!Dev)
        {
            bool pull(ref E[] buf) { return _dev.pull(buf); }
        }
        static if (isSink!Dev)
        {
            bool push(ref const(E)[] buf) { return _dev.push(buf); }
        }
        static if (isBufferedSource!Dev)
        {
            bool fetch() { return _dev.fetch(); }
            const const(E)[] available() { return _dev.available(); }
            void consume(size_t n) { return _dev.consume(n); }
        }
        static if (isBufferedSink!Dev)
        {
            bool flush() { return _dev.flush(); }
            E[] writable() { return _dev.writable(); }
            bool commit(size_t n) { return _dev.commit(n); }
        }
        static if (isSeekable!Dev)
        {
            @property bool seekable() { return _dev.seekable(); }
            ulong seek(long offset, SeekPos whence) { return _dev.seek(offset, whence); }
        }
    }
    return new _DeviceAdapterClass(device);
}

unittest
{
    import dio.file;
    import std.algorithm;
    
    Source!char[] sources;
    sources ~= File(__FILE__).coerced!char.interfaced;
    sources ~= File(__FILE__).buffered.coerced!char.interfaced;
    
    auto buf = "//xx.xxxx module;\n".dup;
    foreach (src; sources)
    {
        auto resume = buf[];
        while (resume.length)
        {
            auto res = src.pull(resume);
            assert(res);
        }
        assert(buf == "//io.core module;\n", buf);
    }
}
