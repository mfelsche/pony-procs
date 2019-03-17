use "ponytest"
use "ponycheck"
use ".."
use "process"
use "files"
use "cli"
use "promises"
use "collections"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  new make() => None

  fun tag tests(test: PonyTest) =>
    test(Property1UnitTest[Array[String]](ArgsTest))
    test(ExitCodeTest)
    test(EnvVarsTest)
    test(ExecutableNotInPathTest)
    test(ExecutableInPathTest)
    test(EmptyExecutableTest)
    test(SlashExecutableTest)
    test(Property1UnitTest[String](StdinEchoTest))

class ProcessResultChecker
  let _eout: (String | None)
  let _eerr: (String | None)
  let _eec: (I32 | None)
  let _epe: (ProcessError | None)

  new create(stdout: (String | None) = None,
             stderr: (String | None) = None,
             exit_code: (I32 | None) = None,
             err: (ProcessError | None) = None) =>
    _eout = stdout
    _eerr = stderr
    _eec  = exit_code
    _epe  = err

  fun check(h: (PropertyHelper|TestHelper), promise: Promise[(ProcessResult | ProcessError)]) =>
    promise.next[None]({(pres) =>
      match pres
      | let actual: ProcessResult =>
        match _epe
        | let epe: ProcessError =>
          h.log("Expected run to fail, but it succeeded with: " + actual.string())
          h.complete(false)
          return
        end

        match _eout
        | let eout: String =>
          h.assert_eq[String](eout, actual.stdout, "STDOUT mismatch: " + actual.string())
        end

        match _eerr
        | let eerr: String =>
          h.assert_eq[String](eerr, actual.stderr, "STDERR mismatch" + actual.string())
        end

        match _eec
        | let eec: I32 =>
          h.assert_eq[I32](eec, actual.exit_code, "Exitcode mismatch" + actual.string())
        end

      | let actual_err: ProcessError =>
        match _epe
        | None =>
          h.log("Expected run to succeed, but it failed.")
          h.complete(false)
          return
        | let expected_error: ProcessError =>
          h.assert_is[ProcessError](actual_err, expected_error, "ProcessError mismatch")
        end
      end
      h.complete(true)
    })


class iso ArgsTest is Property1[Array[String]]
  fun name(): String => "procs/args"

  fun params(): PropertyParams =>
    PropertyParams(where async' = true, timeout' = 10_000_000_000)

  fun gen(): Generator[Array[String]] =>
    Generators.array_of[String](Generators.ascii_letters(1, 100) where min=1)

  fun ref property(sample: Array[String], h: PropertyHelper) ? =>
    let executable = EnvVars(h.env.vars)("PROCS_TEST_EXECUTABLE")?
    let args: Array[String] iso = [ executable; "--args" ]
    for s in sample.values() do
      args.push(s)
    end
    ProcessResultChecker(where stdout = executable + " --args " + " ".join(sample.values()), exit_code=0)
      .check(h, Procs.run_env(h.env, consume args)?)

class iso ExitCodeTest is UnitTest
  fun name(): String => "procs/exitcode"

  fun apply(h: TestHelper) ? =>
    let executable = EnvVars(h.env.vars)("PROCS_TEST_EXECUTABLE")?
    h.long_test(10_000_000_000)
    let args: Array[String] val = [ executable; "--exit-code"; "4" ]
    ProcessResultChecker(where exit_code=4)
      .check(h, Procs.run(h.env.root as AmbientAuth, h.env.vars, args)?)

class iso EnvVarsTest is UnitTest
  fun name(): String => "procs/envvars"
  fun apply(h: TestHelper) ? =>
    let executable = EnvVars(h.env.vars)("PROCS_TEST_EXECUTABLE")?
    h.long_test(10_000_000_000)
    let args: Array[String] val = [ executable; "WADDUP" ]
    let vars: Map[String, String] val = recover val
      Map[String, String]().>update("WADDUP", "NOT_MUCH")
    end
    ProcessResultChecker(where stdout = "NOT_MUCH", exit_code=0)
      .check(h, Procs.run_env(h.env, args, vars)?)

class iso ExecutableNotInPathTest is UnitTest
  fun name(): String => "procs/exec-not-in-path"
  fun apply(h: TestHelper) =>
    let args: Array[String] val = [ "i-do-not-exist-do-i-who-knows-who-cares"; "--yolo" ]
    h.assert_error({() ? => Procs.run_env(h.env, args)? })

class iso ExecutableInPathTest is UnitTest
  fun name(): String => "procs/exec-in-path"
  fun apply(h: TestHelper) ? =>
    h.long_test(10_000_000_000)
    let args: Array[String] val =
      ifdef windows then
        [ "cmd.exe"; "/c"; "echo"; "cool" ]
      else
        [ "echo"; "cool" ]
      end
    ProcessResultChecker(where stdout="cool" + ifdef windows then "\r\n" else "\n" end, exit_code=0)
      .check(h, Procs.run_env(h.env, args)?)

class iso EmptyExecutableTest is UnitTest
  fun name(): String => "procs/exec-empty"
  fun apply(h: TestHelper) =>
    let args: Array[String] val = [""]
    h.assert_error({() ? => Procs.run_env(h.env, args)? })

class iso SlashExecutableTest is UnitTest
  fun name(): String => "procs/exec-slash"
  fun apply(h: TestHelper) =>
    let args: Array[String] val = ["/"]
    h.assert_error({() ? => Procs.run_env(h.env, args)? })

class iso StdinEchoTest is Property1[String]

  fun name(): String => "procs/stdin-echo"

  fun params(): PropertyParams =>
    PropertyParams(where async' = true, timeout' = 10_000_000_000)

  fun gen(): Generator[String] => Generators.ascii_letters()

  fun ref property(sample: String, h: PropertyHelper) ? =>
    let executable = EnvVars(h.env.vars)("PROCS_TEST_EXECUTABLE")?

    let args: Array[String] val = [executable; "--echo"]
    ProcessResultChecker(where stdout=sample, exit_code=0)
      .check(h, Procs.run_env(h.env, args where input=sample)?)

