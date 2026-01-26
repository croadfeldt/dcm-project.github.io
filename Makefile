.PHONY: build serve clean

build:
	hugo --gc --minify

serve:
	hugo server

clean:
	rm -rf public/