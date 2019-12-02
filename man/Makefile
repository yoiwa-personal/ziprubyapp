FILES=ziprubyapp.1 ziprubyapp.1.html

all: $(FILES)

% %.html: %.md
	ronn $<

clean::
	rm -f $(FILES)
