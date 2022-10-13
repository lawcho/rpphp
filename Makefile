## Makefile for building RPPHP examples

# Run automated tests
test:
	@echo "Running tests..."
	@for TEST in $(shell find tests/ -type f -exec basename {} ";"); do\
      (echo "Testing example $$TEST..."\
      && $(MAKE) -s debug/$$TEST \
      && bash tests/$$TEST \
      && echo "✅ PASS" \
      || echo "❌ FAILED") \
    done
	@echo "Done running tests."

# Copy simulator-ready C files to clipboard
clip/%: build/rpp/%.c
	xsel -ib <$<

# Upload bare-metal binaries to RPP
UPLOAD_PATH=/media/$(USER)/RPI-RP2
upload/%: build/rpp/%.uf2
	@until test -d $(UPLOAD_PATH); do echo "Waiting for RPP to be mounted at $(UPLOAD_PATH)"; sleep 1; done
	cp $< $(UPLOAD_PATH)

clean:
	git clean -fdx

## Intermediate build targets

# Platform files
build/%.plat.c: src/%.hson platgen.hs Makefile
	mkdir -p build/
	./platgen.hs <$< >$@

# HVM compiler
hvm2c/target/debug/hvm: hvm2c/Cargo.toml
	cd hvm2c && cargo build

.SECONDEXPANSION:	# enable GNU make's lazy $$(...) syntax

# Combined C files
build/%.c: examples/$$(shell basename $$*).hvm build/$$(shell dirname $$*).plat.c hvm2c/target/debug/hvm Makefile
	mkdir -p $(shell dirname $@)
	./$(word 3,$^) -M 100k c $(word 1,$^) --single-thread -P $(word 2,$^)
	mv examples/$(shell basename $*).c $@

# Bare-metal binaries, for running on the RPP
build/rpp/%.uf2 build/rpp/%.hex build/rpp/%.elf: build/rpp/%.c c2uf2/CMakeLists.txt Makefile
	mkdir -p build/rpp/
	cp $< c2uf2/generic_app.c
	cd c2uf2/ && cmake . && make
	cp c2uf2/generic_app.uf2 build/rpp/$*.uf2
	cp c2uf2/generic_app.hex build/rpp/$*.hex
	cp c2uf2/generic_app.elf build/rpp/$*.elf

# Debug binaries, for running on the host
build/debug/%.run: build/debug/%.c Makefile
	mkdir -p build/debug/
	gcc -g $< -o $@
	chmod +x $@

.PHONY: clean test # clip/* and upload/* should also be .PHONY, but make can't do that easily
.SECONDARY:	# leave all intermediate targets in place
