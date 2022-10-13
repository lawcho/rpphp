.PHONY: clean test

# Simulator-ready C files
out/%.c: examples/%.hvm build/rpp.plat.c hvm2c/target/debug/hvm Makefile
	./hvm2c/target/debug/hvm -M 100k c $< --single-thread -P build/rpp.plat.c
	mkdir -p out/
	mv examples/$*.c $@

# Bare-metal binaries, for running on the RPP
out/%.uf2: out/%.c c2uf2/CMakeLists.txt
	cp $< c2uf2/generic_app.c
	cd c2uf2/ && cmake . && make
	cp c2uf2/generic_app.uf2 $@

# Debug C files
build/debug/%.c: examples/%.hvm build/debug.plat.c hvm2c/target/debug/hvm Makefile
	./hvm2c/target/debug/hvm -M 100k c $< --single-thread -P build/debug.plat.c
	mkdir -p build/debug/
	mv examples/$*.c $@

# Debug binaries, for running on the host
debug/%: build/debug/%.c
	mkdir -p debug/
	gcc -g $< -o $@
	chmod +x $@

build/rpp.plat.c: src/rpp.hson platgen.hs
	mkdir -p build/
	./platgen.hs <$< >$@

build/debug.plat.c: src/debug.hson platgen.hs
	mkdir -p build/
	./platgen.hs <$< >$@

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

# Upload bare-metal binaries to RPP
UPLOAD_PATH=/media/$(USER)/RPI-RP2
upload/%: out/%.uf2
	@until test -d $(UPLOAD_PATH); do echo "Waiting for RPP to be mounted at $(UPLOAD_PATH)"; sleep 1; done
	cp $< $(UPLOAD_PATH)

# Copy simulator-ready C files to clipboard
clip/%: out/%.c
	xsel -ib <$<
