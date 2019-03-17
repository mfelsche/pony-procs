use "cli"

actor Main
  new create(env: Env) =>
    let cs =
      try
        CommandSpec.leaf("test", "example program for testing", [
            OptionSpec.i64("exit-code" where default' = 0)
            OptionSpec.string("out" where default' = "")
            OptionSpec.string("err" where default' = "")
            OptionSpec.bool("args" where default' = false)
            OptionSpec.bool("echo" where default' = false)
          ],[
            ArgSpec.string("variable" where default' = "")
            ArgSpec.string_seq("catch_all")
          ])?
      else
        env.exitcode(1)
        return
      end
    let cmd =
      match CommandParser(cs).parse(env.args, env.vars)
      | let c: Command => c
      | let se: SyntaxError =>
        env.err.print(se.string())
        env.exitcode(1)
        return
      else
        env.err.print("meh!")
        env.exitcode(1)
        return
      end

    // set exit code
    let exit_code = cmd.option("exit-code").i64()
    env.exitcode(exit_code.i32())

    if cmd.option("args").bool() then
      env.out.write(" ".join(env.args.values()))
    end

    // write something to stdout
    let out = cmd.option("out").string()
    if out.size() > 0 then
      env.out.write(out)
    end

    // write something to stderr
    let err = cmd.option("err").string()
    if err.size() > 0 then
      env.err.write(err)
    end

    // print an environment variable
    let env_vars = EnvVars(env.vars)
    let arg = cmd.arg("variable").string()
    if arg.size() > 0 then
      try
        let env_var = env_vars(arg)?
        env.out.write(env_var)
      end
    end

    if cmd.option("echo").bool() then
      env.input(
        object iso is InputNotify
          fun ref apply(data: Array[U8] iso) =>
            env.out.write(consume data)

          fun ref dispose() => None
        end,
        512)
    end
