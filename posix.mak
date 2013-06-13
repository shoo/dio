SRCS=dio/core.d \
	dio/file.d \
	dio/socket.d \
	dio/port.d \
	dio/sys/posix.d \
	dio/util/meta.d \
	dio/util/metastrings_expand.d
#	dio/util/typecons.d \

DFLAGS=-property -w -I$(SRCDIR)

DDOCDIR=html/d
DOCS=\
	$(DDOCDIR)/dio_core.html \
	$(DDOCDIR)/dio_file.html \
	$(DDOCDIR)/dio_socket.html \
	$(DDOCDIR)/dio_port.html
DDOC=dio.ddoc
DDOCFLAGS=-D -c -o- $(DFLAGS)

IOLIB=lib/libdio.a
DEBLIB=lib/libdio_debug.a


# lib

lib: $(IOLIB)
$(IOLIB): $(SRCS)
	mkdir -p lib
	dmd -lib $(DFLAGS) -of$@ $^
	#dmd -lib -of$@ $(DFLAGS) -O -release -noboundscheck $(SRCS)

#deblib: $(DEBLIB)
#$(DEBLIB): $(SRCS)
#	mkdir lib
#	dmd -lib -of$@ $(DFLAGS) -g $(SRCS)

clean:
	$(RM) -rf lib
	$(RM) test/unittest test/pipeinput
	$(RM) -f html/d/*.html

# test

runtest: lib test/unittest test/pipeinput
	test/unittest
	test/pipeinput.sh

test/unittest: $(SRCS)
	dmd $(DFLAGS) -of$@ -unittest -main $^
test/pipeinput: test/pipeinput.d test/pipeinput.dat test/pipeinput.sh lib
	dmd $(DFLAGS) -of$@ test/pipeinput.d $(IOLIB)


# benchmark

runbench: lib test/default_bench
	test/default_bench
runbench_opt: lib test/release_bench
	test/release_bench

test/default_bench: test/bench.d
	dmd $(DFLAGS) -of$@ $^ $(IOLIB)
test/release_bench: test/bench.d
	dmd $(DFLAGS) -O -release -noboundscheck -of$@ $^ $(IOLIB)


# ddoc

html: $(DOCS)

$(DDOCDIR)/dio_core.html: dio/core.d $(DDOC)
	dmd $(DDOCFLAGS) -Df$@ $(DDOC) $<

$(DDOCDIR)/dio_file.html: dio/file.d $(DDOC)
	dmd $(DDOCFLAGS) -Df$@ $(DDOC) $<

$(DDOCDIR)/dio_socket.html: dio/socket.d $(DDOC)
	dmd $(DDOCFLAGS) -Df$@ $(DDOC) $<

$(DDOCDIR)/dio_port.html: dio/port.d $(DDOC)
	dmd $(DDOCFLAGS) -Df$@ $(DDOC) $<
