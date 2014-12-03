SRCS=dio\package.d \
	dio\core.d \
	dio\file.d \
	dio\serial.d \
	dio\socket.d \
	dio\port.d \
	dio\sys\windows.d \
	dio\util\meta.d \
	dio\util\metastrings_expand.d

DFLAGS=-w -de -I$(SRCDIR)

DDOCDIR=html\d
DOCS=$(DDOCDIR)\dio.html \
	$(DDOCDIR)\dio_core.html \
	$(DDOCDIR)\dio_file.html \
	$(DDOCDIR)\dio_serial.html \
	$(DDOCDIR)\dio_socket.html \
	$(DDOCDIR)\dio_port.html
DDOC=dio.ddoc
DDOCFLAGS=-D -c -o- $(DFLAGS)

IOLIB=lib\dio.lib
DEBLIB=lib\dio_debug.lib


# lib

lib: $(IOLIB)
$(IOLIB): $(SRCS)
	mkdir lib
	dmd -lib $(DFLAGS) -of$(IOLIB) $(SRCS)
	#dmd -lib -of$@ $(DFLAGS) -O -release -noboundscheck $(SRCS)

#deblib: $(DEBLIB)
#$(DEBLIB): $(SRCS)
#	mkdir lib
#	dmd -lib -of$@ $(DFLAGS) -g $(SRCS)

clean:
	rmdir /S /Q lib  2> NUL
	del /Q test\*.obj test\*.exe  2> NUL
	del /Q html\d\*.html  2> NUL


# test

runtest: lib test\unittest.exe test\pipeinput.exe
	test\unittest.exe
	test\pipeinput.bat

test\unittest.exe: $(SRCS)
	dmd $(DFLAGS) -of$@ -unittest -debug -g -main $(SRCS)
test\pipeinput.exe: test\pipeinput.d test\pipeinput.dat test\pipeinput.bat lib
	dmd $(DFLAGS) -of$@ -debug -g test\pipeinput.d $(IOLIB)


# benchmark

runbench: lib test\default_bench.exe
	test\default_bench.exe
runbench_opt: lib test\release_bench.exe
	test\release_bench.exe

test\default_bench.exe: test\bench.d
	dmd $(DFLAGS) -of$@ test\bench.d $(IOLIB)
test\release_bench.exe: test\bench.d
	dmd $(DFLAGS) -O -release -noboundscheck -of$@ test\bench.d $(IOLIB)


# ddoc

html: $(DOCS) $(SRCS)

$(DDOCDIR)\dio_core.html: $(DDOC) dio\core.d
	dmd $(DDOCFLAGS) -Df$@ $(DDOC) dio\core.d

$(DDOCDIR)\dio_file.html: $(DDOC) dio\file.d
	dmd $(DDOCFLAGS) -Df$@ $(DDOC) dio\file.d

$(DDOCDIR)\dio_socket.html: $(DDOC) dio\serial.d
	dmd $(DDOCFLAGS) -Df$@ $(DDOC) dio\serial.d

$(DDOCDIR)\dio_socket.html: $(DDOC) dio\socket.d
	dmd $(DDOCFLAGS) -Df$@ $(DDOC) dio\socket.d

$(DDOCDIR)\dio_port.html: $(DDOC) dio\port.d
	dmd $(DDOCFLAGS) -Df$@ $(DDOC) dio\port.d

$(DDOCDIR)\dio.html: $(DDOC) dio\package.d
	dmd $(DDOCFLAGS) -Df$@ $(DDOC) dio\package.d
