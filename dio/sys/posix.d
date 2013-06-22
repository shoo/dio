/**
Add some symbols not defined in core module.
*/
module dio.sys.posix;

public import core.sys.posix.sys.types,
    core.sys.posix.sys.stat,
    core.sys.posix.fcntl,
    core.sys.posix.unistd,
    core.stdc.errno,
    core.stdc.stdio : SEEK_SET;

alias int HANDLE;
