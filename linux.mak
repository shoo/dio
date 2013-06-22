SRCS=dio/package.d \
	dio/core.d \
	dio/file.d \
	dio/socket.d \
	dio/port.d \
	dio/util/meta.d \
	dio/util/metastrings_expand.d

DFLAGS=-property -w -I$(SRCDIR) -g

DDOCDIR=html/d
DOCS=$(DDOCDIR)/dio.html \
	$(DDOCDIR)/io_core.html \
	$(DDOCDIR)/io_file.html \
	$(DDOCDIR)/io_socket.html \
	$(DDOCDIR)/io_port.html
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

$(DDOCDIR)/io_core.html: $(DDOC) io/core.d
	dmd $(DDOCFLAGS) -Df$@ $(DDOC) io/core.d

$(DDOCDIR)/io_file.html: $(DDOC) io/file.d
	dmd $(DDOCFLAGS) -Df$@ $(DDOC) io/file.d

$(DDOCDIR)/io_socket.html: $(DDOC) io/socket.d
	dmd $(DDOCFLAGS) -Df$@ $(DDOC) io/socket.d

$(DDOCDIR)/io_port.html: $(DDOC) io/port.d
	dmd $(DDOCFLAGS) -Df$@ $(DDOC) io/port.d

$(DDOCDIR)/dio.html: $(DDOC) dio/package.d
	dmd $(DDOCFLAGS) -Df$@ $(DDOC) dio/package.d
