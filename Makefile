mandel.com: mandel.asm
	nasm -f bin -o $@ $<

.PHONY: clean
clean:
	rm -f mandel.com
