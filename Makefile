.PHONY: clean

CLIP=0
out/%.c: examples/%.hvm build/rpp.plat.c hvm2c/target/debug/hvm Makefile
	./hvm2c/target/debug/hvm -M 100k c $< --single-thread -P build/rpp.plat.c
	mkdir -p out/
	mv examples/$*.c $@
	if test $(CLIP) = 1; then (xsel -ib <$@) fi

out/%.uf2: out/%.c c2uf2/CMakeLists.txt
	cp $< c2uf2/generic_app.c
	cd c2uf2/ && cmake . && make
	cp c2uf2/generic_app.uf2 $@

debug/%: out/%.c
	mkdir -p debug/
	gcc -g -DDEBUG $< -o $@
	chmod +x $@

build/rpp.plat.c: src/ffi.hson src/rpp.h platgen.hs
	mkdir -p build/
	./platgen.hs src/ffi.hson src/rpp.h >$@

hvm2c/target/debug/hvm: hvm2c/Cargo.toml
	cd hvm2c && cargo build

clean:
	git clean -fdx
