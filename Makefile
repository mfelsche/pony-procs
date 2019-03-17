PONYC ?= ponyc
config ?= debug
ifdef config
  ifeq (,$(filter $(config),debug release))
    $(error Unknown configuration "$(config)")
  endif
endif

ifeq ($(config),debug)
	PONYC_FLAGS += --debug
endif

PONYC_FLAGS += -o build/$(config)


ALL: test

build/$(config)/test: .deps procs/*.pony procs/test/*.pony | build/$(config)
	stable env $(PONYC) ${PONYC_FLAGS} procs/test

build/$(config)/test_program: procs/test/test_program/*.pony | build/$(config)
	stable env $(PONYC) $(PONYC_FLAGS) procs/test/test_program

build/$(config):
	mkdir -p build/$(config)

.deps:
	stable fetch

test: build/$(config)/test_program build/$(config)/test
	PROCS_TEST_EXECUTABLE=$(PWD)/build/$(config)/test_program build/$(config)/test

clean:
	rm -rf build

.PHONY: clean test
