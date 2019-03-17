"""
## Procs

A simple interface to running child processes:

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
"""
use "process"
use "promises"
use "collections"
use "files"
use "cli"

class val ProcessResult is Stringable
  """
  The result of running a process successfully.
  """
  let exit_code: I32
    """A.k.a. return code"""
  let stdout: String
    """The collected output from the process stdout as String."""
  let stderr: String
    """The collected output from the process stderr as String."""

  new val create(exit_code': I32, stdout': String, stderr': String) =>
    exit_code = exit_code'
    stdout = stdout'
    stderr = stderr'

  fun string(): String iso^ =>
    recover iso
      String.>append("ProcessResult(exit_code=")
            .>append(exit_code.string())
            .>append(", stdout=\"")
            .>append(stdout.trim(0, 100))
            .>append(if stdout.size() > 100 then "..." else "" end)
            .>append("\", stderr=\"")
            .>append(stderr.trim(0, 100))
            .>append(if stderr.size() > 100 then "..." else "" end)
            .>append("\")")
    end

class iso _ProcessResultNotify is ProcessNotify
  let _promise: Promise[(ProcessResult|ProcessError)]
  var _stdout: String trn = recover trn String end
  var _stderr: String trn = recover trn String end

  new iso create(promise: Promise[(ProcessResult|ProcessError)]) =>
    _promise = promise

  fun ref stdout(process: ProcessMonitor ref, data: Array[U8] iso) =>
    _stdout.append(consume data)

  fun ref stderr(process: ProcessMonitor ref, data: Array[U8] iso) =>
    _stderr.append(consume data)

  fun ref failed(process: ProcessMonitor ref, err: ProcessError) =>
    _promise(err)

  fun ref dispose(process: ProcessMonitor ref, child_exit_code: I32) =>
    let result =
      ProcessResult(where
        exit_code' = child_exit_code,
        stdout' = (_stdout = recover trn String end),
        stderr' = (_stderr = recover trn String end)
      )
    _promise(result)

primitive Procs
  fun _env_map_2_array(env_map: Map[String, String] val): Array[String] val =>
    let arr = recover iso Array[String](env_map.size()) end
    for (k, v) in env_map.pairs() do
      let s = recover val
        String(k.size() + 1 + v.size())
          .>append(k)
          .>append("=")
          .>append(v)
      end
      arr.push(s)
    end
    consume arr

  fun run(
    auth: AmbientAuth,
    parent_env_vars: Array[String] val,
    cmd: Array[String] val,
    vars: (Map[String, String] val | None) = None,
    input: (String | None) = None)
    : Promise[(ProcessResult | ProcessError)] ?
  =>
    """
    Execute a child process given an array of command-line arguments.
    Return its result as a union of [ProcessResult](procs-ProcessResult.md) | [ProcessError](process-ProcessError).

    The first element of the `cmd` array needs to be the executable to run.
    If it is not given as an absolute path, it will be resolved by searching for
    it on the `PATH`.

    `auth` and `parent_env_vars` are used to construct the objects necessary for executing a child process.

    If `vars` is given, it will be the environment for the child process, if `vars` is None, `parent_env_vars` will be used.

    If `input` is given, it will be written to the child process' stdin, if it is `None`, nothing will be written.

    This function errors if `PATH` search fails, `cmd` is empty or the given executable path is not accessible.
    """
    let p = Promise[(ProcessResult|ProcessError)]
    let notify = _ProcessResultNotify(p)

    let env_vars = EnvVars(parent_env_vars)

    let cmd0 = cmd(0)?

    let executable =
      if cmd0.contains(Path.sep()) then
        let abs_exec = FilePath(auth, cmd0)?
        if not (abs_exec.exists() and FileInfo(abs_exec)?.file) then
          error
        else
          abs_exec
        end
      else
        let path = env_vars("PATH")?
        var executable: (FilePath | None) = None
        for path_elem in Path.split_list(path).values() do
          let candidate =
            FilePath(
              auth,
              Path.join(path_elem, cmd0))?
          if candidate.exists() and FileInfo(candidate)?.file then
            executable = candidate
          end
        end
        match executable
        | None => error
        | let fp: FilePath => fp
        end
      end

    let child_vars =
      match vars
      | None => env_vars // take this process' environment variables
      | let map: Map[String, String] val => map
      end
    let monitor = ProcessMonitor(
      auth,
      auth,
      consume notify,
      executable,
      cmd,
      _env_map_2_array(child_vars))
    // write to subprocess
    match input
    | let child_input: String => monitor.write(child_input)
    end
    monitor.done_writing()
    p

  fun run_env(
    env: Env,
    cmd: Array[String] val,
    vars: (Map[String, String] val | None) = None,
    input: (String | None) = None)
    : Promise[(ProcessResult|ProcessError)] ?
  =>
    """
    Execute a child process given an array of command-line arguments.
    Return its result as a union of [ProcessResult](procs-ProcessResult.md) | [ProcessError](process-ProcessError).

    The first element of the `cmd` array needs to be the executable to run.
    If it is not given as an absolute path, it will be resolved by searching for
    it on the `PATH`.

    If `vars` is given, it will be the environment for the child process, if `vars` is None, the parent environment will be used.

    If `input` is given, it will be written to the child process' stdin, if it is `None`, nothing will be written.

    This function errors if `PATH` search fails, `cmd` is empty or the given executable path is not accessible.
    """
    run(
      env.root as AmbientAuth,
      env.vars,
      cmd,
      vars,
      input)?
