import dio.core, dio.port;

void main()
{
    long num;
    write("num>"), dout.flush(), readf("%s\n", &num);
    writefln("num = %s\n", num);
    assert(num == 10);

    string str;
    write("str>"), dout.flush(), readf("%s\n", &str);
    writefln("str = [%(%02X %)]", str);
    assert(str == "test");
}
