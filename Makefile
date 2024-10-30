# Reset implicit rules as if using -r
.SUFFIXES:
# Reset implicit variables as if using -R
$(foreach var,$(filter-out .% MAKE% SUFFIXES,$(.VARIABLES)),\
  $(if $(findstring $(origin $(var)),default),\
    $(if $(filter undefine,$(.FEATURES)),\
      $(eval undefine $(var)),\
      $(eval $(var)=))))

# Build options
BUILTINS=1
PRAGMA_FP_CONTRACT=0
SIMD=1
OPENMP=1
DEBUG=0
PROFILE=0
SAVE_ASM=0
WINDOWS=0

# VARIABLES
CFLAGS+=-std=c11 -pedantic
CFLAGS+=-msse2 -mfpmath=sse
CFLAGS+=-g
WARN_FLAGS+=-Wall -Wextra -Winline -Wshadow
NO_WARN_FLAGS+=-w
ifeq ($(CC),)
CC=$(HOST)gcc
endif
ifeq ($(WINDRES),)
WINDRES=$(HOST)windres
endif
LIBS+=-ljpeg -lpng -lm -lz
OBJS+=jpeg2png.o utils.o jpeg.o png.o box.o compute.o logger.o progressbar.o fp_exceptions.o gopt/gopt.o ooura/dct.o
HOST=
EXE=

ifeq ($(BUILTINS),1)
CFLAGS+=-DBUILTIN_UNREACHABLE -DBUILTIN_ASSUME_ALIGNED -DATTRIBUTE_UNUSED
endif

ifeq ($(PRAGMA_FP_CONTRACT),1)
CFLAGS+=-DPRAGMA_FP_CONTRACT
else # not supported by gcc
CFLAGS+=-ffp-contract=off
endif

ifeq ($(SIMD),1)
CFLAGS+=-DUSE_SIMD
endif

ifeq ($(OPENMP),1)
BFLAGS+=-fopenmp
endif

ifeq ($(DEBUG),1)
CFLAGS+=-Og -DDEBUG
else
CFLAGS+=-O3 -DNDEBUG
endif

ifeq ($(PROFILE),1)
BFLAGS+=-pg
endif

ifeq ($(WINDOWS),1)
    # Determine if HOST should be set based on the environment
    ifeq ($(HOST),)
        ifeq ($(shell uname -s),Linux)
            ifeq ($(shell uname -m),x86_64)
                HOST=x86_64-w64-mingw32-
            else
                HOST=i686-w64-mingw32-
            endif
        else ifeq ($(shell uname -s),Darwin)
            ifeq ($(shell uname -m),x86_64)
                HOST=x86_64-w64-mingw32-
            else
                HOST=i686-w64-mingw32-
            endif
        else ifeq ($(findstring MINGW,$(shell uname -s)),MINGW)
            ifeq ($(shell uname -m),x86_64)
                HOST=x86_64-w64-mingw32-
            else
                HOST=i686-w64-mingw32-
            endif
        endif
    endif

    EXE=.exe
    LDFLAGS+=-static -s
    CFLAGS+=-mstackrealign # https://gcc.gnu.org/bugzilla/show_bug.cgi?id=48659
    RES+=icon.rc.o

    # Set WINDRES based on environment
    ifneq ($(findstring MINGW,$(shell uname -s)),)
        # For MinGW environments, use native windres without HOST prefix
        WINDRES=windres
    else
        # For other environments (Linux, macOS), use HOST-prefixed windres
        WINDRES=$(HOST)windres
    endif
endif

ifeq ($(SAVE_ASM),1)
CFLAGS+=-save-temps -masm=intel -fverbose-asm
endif

CFLAGS+=$(BFLAGS)
LDFLAGS+=$(BFLAGS)

# RULES
.PHONY: clean all install uninstall
all: jpeg2png$(EXE)

jpeg2png$(EXE): $(OBJS) $(RES) Makefile
	$(CC) $(OBJS) $(RES) -o $@ $(LDFLAGS) $(LIBS)

-include $(OBJS:.o=.d)

gopt/gopt.o: gopt/gopt.c gopt/gopt.h Makefile
	$(CC) $< -c -o $@ $(CFLAGS) $(NO_WARN_FLAGS)

%.o: %.c Makefile
	$(CC) -MP -MMD $< -c -o $@ $(CFLAGS) $(WARN_FLAGS)

%.rc.o: %.rc Makefile
	$(WINDRES) $< $@

clean:
	git clean -Xf

install: all
	install -Dm755 jpeg2png "$(DESTDIR)"/usr/bin/jpeg2png

uninstall:
	rm "$(DESTDIR)"/usr/bin/jpeg2png
