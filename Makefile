.PHONY: clean

CLIP=0
out/%.c: examples/%.hvm src/rpphp.c Makefile
	hvm -M 100k c $< --single-thread -P src/rpphp.c
	mkdir -p out/
	mv examples/$*.c $@
	if test $(CLIP) = 1; then (xsel -ib <$@) fi

debug/%: out/%.c
	mkdir -p debug/
	gcc -g -DDEBUG $< -o $@
	chmod +x $@

clean:
	git clean -fdx
