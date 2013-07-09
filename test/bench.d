import dio.port, dio.file;
import std.algorithm, std.range, std.random, std.datetime, std.file;

void main()
{
	auto results = map!(f => f())([
        &benchReadCharsFromFile,
        &benchReadLinesFromFile,
        &benchWriteCharsToFile,
        &benchWriteCharsToStdout,
    ]).array();

    writefln("rate\tdio\t\t\tstd.stdio");
    foreach (t; results)
    {
        writefln("%1.4f\t%s\t%s",
            cast(real)t[1].length / cast(real)t[0].length,
            t[0],
            t[1]);
    }
}

auto benchReadCharsFromFile()
{
    enum count = 4096;
    auto fname = genXorshiftFile(count);
    scope(exit) remove(fname);

    return benchmark!(
        () @trusted
        {
            import dio.port, dio.file;
            auto f = textPort(File(fname));
            string s;
            foreach (i; 0 .. count)
            {
                readf(f, "%s\n", &s);
            }
        },
        () @trusted
        {
            import std.stdio;
            auto f = File(fname);
            string s;
            foreach (i; 0 .. count)
            {
                f.readf("%s\n", &s);
            }
        }
    )(500);
}

auto benchReadLinesFromFile()
{
    enum count = 4096;
    auto fname = genXorshiftFile(count);
    scope(exit) remove(fname);

    return benchmark!(
        () @trusted
        {
            foreach (ln; File(fname).textPort().lines)
            {}
        },
        () @trusted
        {
            import std.stdio;
            foreach (ln; File(fname).byLine())
            {}
        }
    )(20);  // cannot repeat 500
}

auto genXorshiftFile(size_t linecount)
{
    import std.path, std.conv, std.stdio;
    string fname = "xorshift.txt";

    auto rng = Xorshift(1);
    auto f = File(fname, "w");
    foreach (i; 0 .. linecount)
    {
        f.writeln(rng.front);
        rng.popFront();
    }

    return fname;
}

auto benchWriteCharsToFile()
{
    enum count = 4096;
    auto fname = "charout.txt";
    scope(exit) remove(fname);

    return benchmark!(
        () @trusted
        {
            auto f = File(fname, "w").textPort();
            foreach (i; 0 .. count)
            {
                writef(f, "%s,", i);
            }
            writeln(f);     // flush buffer
        },
        () @trusted
        {
            import std.stdio;
            auto f = File(fname, "w");
            foreach (i; 0 .. count)
            {
                f.writef("%s,", i);
            }
            f.writeln();    // flush buffer
        }
    )(500);
}

auto benchWriteCharsToStdout()
{
    enum count = 4096;

    return benchmark!(
        () @trusted
        {
            foreach (i; 0 .. count)
            {
                writef("%s,", i);
            }
            writeln();      // flush buffer
        },
        () @trusted
        {
            import std.stdio;
            foreach (i; 0 .. count)
            {
                writef("%s,", i);
            }
            writeln();      // flush line buffer
        }
    )(500);
}
