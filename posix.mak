SRCS=dio/package.d \
	dio/core.d \
	dio/file.d \
	dio/socket.d \
	dio/port.d \
	dio/sys/posix.d \
	dio/util/meta.d \
	dio/util/metastrings_expand.d

DFLAGS=-property -w -I$(SRCDIR) -g

DDOCDIR=html/d
DOCS=$(DDOCDIR)/dio.html \
	$(DDOCDIR)/dio_core.html \
	$(DDOCDIR)/dio_file.html \
	$(DDOCDIR)/dio_socket.html \
	$(DDOCDIR)/dio_port.html
DDOC=dio.ddoc
DDOCFLAGS=-D -c -o- $(DFLAGS)

IOLIB=lib/libdio.a
DEBLIB=lib/libdio_debug.a


# lib

all: $(IOLIB)
$(IOLIB): $(SRCS)
	@[ -d lib ] || mkdir lib
	dmd -lib $(DFLAGS) -of$(IOLIB) $(SRCS)

#deblib: $(DEBLIB)
#$(DEBLIB): $(SRCS)
#	mkdir lib
#	dmd -lib -of$@ $(DFLAGS) -g $(SRCS)

clean:
	rm -rf lib
	rm -f test/*.o
	rm -f html/d/*.html


# test

runtest: $(IOLIB) test/unittest test/pipeinput
	test/unittest
	test/pipeinput.sh

test/unittest: $(SRCS)
	dmd $(DFLAGS) -of$@ -unittest -main $(SRCS)
test/pipeinput: test/pipeinput.d test/pipeinput.dat test/pipeinput.sh $(IOLIB)
	dmd $(DFLAGS) -of$@ test/pipeinput.d $(IOLIB)


# benchmark

runbench: $(IOLIB) test/default_bench
	test/default_bench
runbench_opt: $(IOLIB) test/release_bench
	test/release_bench

test/default_bench: test/bench.d
	dmd $(DFLAGS) -of$@ test/bench.d $(IOLIB)
test/release_bench.exe: test/bench.d
	dmd $(DFLAGS) -O -release -noboundscheck -of$@ test/bench.d $(IOLIB)


# ddoc

html: $(DOCS) $(SRCS)

$(DDOCDIR)/dio_core.html: $(DDOC) dio/core.d
	dmd $(DDOCFLAGS) -Df$@ $(DDOC) dio/core.d

$(DDOCDIR)/dio_file.html: $(DDOC) dio/file.d
	dmd $(DDOCFLAGS) -Df$@ $(DDOC) dio/file.d

$(DDOCDIR)/dio_socket.html: $(DDOC) dio/socket.d
	dmd $(DDOCFLAGS) -Df$@ $(DDOC) dio/socket.d

$(DDOCDIR)/dio_port.html: $(DDOC) dio/port.d
	dmd $(DDOCFLAGS) -Df$@ $(DDOC) dio/port.d

$(DDOCDIR)/dio.html: $(DDOC) dio/package.d
	dmd $(DDOCFLAGS) -Df$@ $(DDOC) dio/package.d
