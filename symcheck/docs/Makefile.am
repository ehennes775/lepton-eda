
EXTRA_DIST = $(html_man_files) lepton-symcheck.1.in

dist_man_MANS = lepton-symcheck.1

.1.in.1:
	d=`$(GUILE) -c '(setlocale LC_ALL "C") \
	  (display (strftime "%B %-d, %Y" \
	  (car (strptime "%Y%m%d" (cadr (program-arguments))))))' $(DATE_VERSION)` ; \
	v="$(DOTTED_VERSION).$(DATE_VERSION)" ; \
	y=`echo $(DATE_VERSION)| sed -e"s/\(....\).*/\1/"`; \
	sed -e"s:[@]DATE@:$$d:" -e"s:[@]VERSION@:$$v:" -e"s:[@]YEAR@:$$y:" < $< > $@

# Rules for converting man->html
html_man_files = lepton-symcheck.html
SUFFIXES = .1.in .1 .html

docsmandir=$(docdir)/man
docsman_DATA=$(html_man_files)
if ENABLE_GROFF_HTML
.1.html:
	rm -rf $@.tmp && \
	LC_NUMERIC=C $(GROFF) -man -T html  $< >$@.tmp && \
	mv -f $@.tmp $@
else
.1.html:
	@echo "No working groff available: cannot create $@"
	@! :
endif


MOSTLYCLEANFILES = *.log *~
CLEANFILES = $(dist_man_MANS) $(html_man_files)
DISTCLEANFILES = *.log core FILE *~
MAINTAINERCLEANFILES = *.log *~ Makefile.in $(html_man_files)
