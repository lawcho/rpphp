.PHONY: clean test

# Simulator-ready C files
CLIP=0								# optionally copy to clipboard
out/%.c: examples/%.hvm build/rpp.plat.c hvm2c/target/debug/hvm Makefile
	./hvm2c/target/debug/hvm -M 100k c $< --single-thread -P build/rpp.plat.c
	mkdir -p out/
	mv examples/$*.c $@
	if test $(CLIP) = 1; then (xsel -ib <$@) fi

# Bare-metal binaries, for running on the RPP
UPLOAD=0							# optionally copy to RPP over USB
UPLOAD_PATH=/media/$(USER)/RPI-RP2	# where the RPP is mounted
out/%.uf2: out/%.c c2uf2/CMakeLists.txt
	cp $< c2uf2/generic_app.c
	cd c2uf2/ && cmake . && make
	cp c2uf2/generic_app.uf2 $@
	if test $(UPLOAD) = 1; then (cp $@ $(UPLOAD_PATH)) fi

# Debug binaries, for running on the host
debug/%: out/%.c
	mkdir -p debug/
	gcc -g -DDEBUG $< -o $@
	chmod +x $@

build/rpp.plat.c: src/ffi.hson src/rpp.h platgen.hs
	mkdir -p build/
	./platgen.hs src/ffi.hson src/rpp.h >$@

hvm2c/target/debug/hvm: hvm2c/Cargo.toml
	cd hvm2c && cargo build

test:
	@for TEST in $(shell find tests/ -type f -exec basename {} ";"); do\
      (echo "Testing example $$TEST..."\
      && $(MAKE) -s debug/$$TEST \
      && bash tests/$$TEST \
      && echo "✅ PASS" \
      || echo "❌ FAILED") \
    done

clean:
	git clean -fdx
