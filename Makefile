# Makefile for ziprubyapp

COMPRESSION = -C9
ZIPRUBYAPPOPT = $(COMPRESSION) --random-seed=314159265
SRCDIR = lib/ziprubyapp

all: bin/ziprubyapp

bin/ziprubyapp: $(SRCDIR)/main.rb $(SRCDIR)/zip_tiny.rb
	$(SRCDIR)/main.rb -I $(SRCDIR) $(ZIPRUBYAPPOPT) -o $@ $^
	$@ -I $(SRCDIR) $(ZIPRUBYAPPOPT) -o $@ $^
	$@ -I $(SRCDIR) $(ZIPRUBYAPPOPT) -o $@ $^

# running three-time bootstrap as a test
#  1st to generate the packed binary
#  2nd to check whether the original script emits correct outputs
#  3rd to check whether the compiled script emitted correct outputs
