# Procs

A simple interface to running child processes in [Ponylang](https://ponylang.io):

```pony
use "procs"

actor Main
  new create(env: Env) =>
    try
      let result_promise = Procs.run_env(env, ["/usr/bin/echo"; "how"; "awesome"; "is"; "this;"])?
      result_promise.next[None]({(res) =>
        match res
        | let pres: ProcessResult =>
          env.out.write(pres.stdout)
        | let perr: ProcessError =>
          env.err.print("Meh! :(")
        end
      })
    end
```

No need to create a [ProcessNotify](process-ProcessNotify.md) or a [ProcessMonitor](process-ProcessMonitor.md) and
accumulate chunks received from stdout, while all you want is to get stdout as `String`. Just run your process and
handle the [Promise](promises-Promise.md) containing either the [ProcessResult](procs-ProcessResult.md) with `exit_code`,
`stdout` and `stderr` or an instance of [ProcessError](process-ProcessError.md).

It is possible to pass environment variables and write something to stdin of the child process.

## Status

[![CircleCI](https://circleci.com/gh/mfelsche/pony-procs.svg?style=svg)](https://circleci.com/gh/mfelsche/pony-procs) [![Build status](https://ci.appveyor.com/api/projects/status/mns3ld1foja8mo7n/branch/master?svg=true)](https://ci.appveyor.com/project/mfelsche/pony-procs/branch/master) [![Build Status](https://travis-ci.org/mfelsche/pony-procs.svg?branch=master)](https://travis-ci.org/mfelsche/pony-procs)

## Installation

* Install [pony-stable](https://github.com/ponylang/pony-stable)
* Update your `bundle.json`

```json
{ 
  "type": "github",
  "repo": "mfelsche/pony-procs"
}
```

* `stable fetch` to fetch your dependencies
* `use "procs"` to include this package
* `stable env ponyc` to compile your application
