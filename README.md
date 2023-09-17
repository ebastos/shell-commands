# shell-commands

This is a proof-of-concept repository to demonstrate how to create a complex command structure using Bash.
The idea is to keep things as organized as possible, creating sub-commands with a modern command-line behaviour that one would expect.

To be clear, if you find yourself in a situation where the future holds a complex command hierarchy, shell script is the wrong choice of tool. However, you may be in a situation where you need to refactor an existing codebase created in shell, and small incremental refactorings will help increase the readability and maintainability. In this case, feel free to follow the examples on this repository.

## Structure

### Root Command

The main command is called `super`. Think of it like the root command in any other multi-command application like `aws` or `kubectl`.
You can rename that script to anything you want, and it will pick the new name up.

### Sub-commands

You should put the desired sub-commands under the `commands` folder. Create a new file for each, which should not have any suffix (e.g. `.sh`). Make sure to add the `shebang` and make the new file executable.

Each file must have three default functions: `$COMMAND_show_help`, `$COMMAND_describe`, `$COMMAND_run`.

Let's assume the sub-command name is `hello`. In this case, the file should also be called `hello`, and it must contain the following functions:

- `hello_show_help`
- `hello_describe`
- `hello_run`

As you probably guessed, we are using `$COMMAND_` to organize the namespacing of the sub-commands.

### Libraries

There is also a library directory where you can place utilities that can be used by any sub-command, like loggers.
Just like the sub-commands, you can create independent files which you can import inside each sub-command as you see fit. Libraries imported at the root command will be available inside all sub-commands.

For the libraries, we are using `::` for namespacing instead of the `_` we used for the subcommands. For example, `common::load_config`

## Recommendations

To keep things easy to read and understand it is recommended that functions internal to commands be prefixed with a single `_` 

## TODO

Need to add unit tests using `bats`
