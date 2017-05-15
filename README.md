# `require` _for Bash_

`require` _for Bash_ is a script that allows you to simply require _remote_ or local
shell script modules/files from within scripts or the terminal (similar to the
builtin `source my_script.sh`/`. my_script.sh`).
Out of the box, it supports public and private _GitHub_ repositories, as well as
pretty much any _http(s)_ or _ftp_ host. In addition to that, any other scheme
can be supported through an extensible interface.

# Table of Contents

<!-- TOC depthFrom:1 depthTo:3 withLinks:1 updateOnSave:0 orderedList:0 -->
- [Usage examples](#usage-examples)
	- [For files on the local filesystem](#for-files-on-the-local-filesystem)
	- [For files on GitHub](#for-files-on-github)
	- [For any http(s) or ftp URL](#for-any-https-or-ftp-url)
	- [Options](#options)
	- [Exit codes](#exit-codes)
- [Installation](#installation)
- [Configuration](#configuration)
	- [Configuring script search paths](#configuring-script-search-paths)
	- [Configuring non-local modules/files handling](#configuring-non-local-modulesfiles-handling)
	- [Advanced resolver configuration](#advanced-resolver-configuration)
		- [GitHub resolver](#github-resolver)
		- [Curl resolver](#curl-resolver)
- [Developing modules for `require` _for Bash_](#developing-modules-for-require-for-bash)
	- [What is a module?](#what-is-a-module)
	- [Naming conventions for modules](#naming-conventions-for-modules)
	- [Other considerations when develping modules](#other-considerations-when-develping-modules)
	- [Why should I develop a module?](#why-should-i-develop-a-module)
- [Creating your own resolver](#creating-your-own-resolver)
- [Future plans/TODOs](#future-planstodos)
<!-- /TOC -->

# Usage examples

Here are some examples of how the use looks like:

### For files on the local filesystem

```sh
require '/absolute/path/to/my/script'
require './relative_path/to/my/script'
require 'somewhere/in/shell_module_path'
```

### For files on GitHub

```sh
# Default
require '@gh:jtrefke/shell_require/master/tests/test_runner'

# Or if configured to resolve the above repository and branch when referring to "test" using "scripts:"
require '@scripts:tests/test_runner'
# Or if configured to resolve the above repository and branch when referring to "test" in general
require '@tests/test_runner'
```


### For any http(s) or ftp URL

```sh
# Default
require '@https://raw.githubusercontent.com/jtrefke/shell_require/master/tests/test_runner'

# Or if configured to resolve any package name without scheme
require '@raw.githubusercontent.com/jtrefke/shell_require/master/tests/test_runner'
# Or if configured to resolve only a specific prefix, for example raw.githubusercontent.com/jtrefke/shell_require/
require '@master/tests/test_runner'
# Or if configured to resolve only a specific prefix, for example
# raw.githubusercontent.com/jtrefke/shell_require/master using the scheme req:
require '@req:tests/test_runner'
```


### Options

`require` will load a file only once, unless explicitly specified. To do so use `reload`:
```sh
require 'my/module' reload
```

### Exit codes

As per convention, `0` means successful execution and anything else is an error.
However, to simplify debugging, the following different codes are used:

| Code | Meaning                                                         |
| ---- | --------------------------------------------------------------- |
| 0    | successful termination                                          |
| 64   | no input provided (command line usage error)                    |
| 65   | resolved module not a valid shell file (data format error)      |
| 69   | module not available/found (service unavailable)                |
| 78   | resolver does not implement interface (configuration error)     |
| *    | Anything else: result from actual source operation              |

_Exit codes based on:_ `/usr/include/sysexits.h`

# Installation

In order to install `require`, simply, paste the following line into your Bash shell:
```sh
curl -L https://raw.githubusercontent.com/jtrefke/shell_require/master/install.sh | bash
```
Alternatively, clone or download the repository and run `install.sh`.

By default, `require` will be installed in `${HOME}/.shell_require` and the path
to the function will be added to your `~/.bashrc` or `~/.bash_profile` if writable.
If you have any issues, make sure at least `~/.bash_profile` exists or that
`~/.bash_profile` sources `~/.bashrc`.

Besides `curl`, which is only used for some external resolvers, it should not
require more software than the GNU core utilities.

# Configuration

There is _no configuration required_ for local filesystem scenarios and the default external
schemes for (GitHub (`gh:`) as well as `http:`, `https:` and `ftp:`).
For all resolvers, `require` _for Bash_ will always search for the specified module
name ending with `.sh`. On the local filesystem, it will also search for the
specified module name withouth the `.sh` ending, if the first one does not exist.


Additional configuration can take place through the `shellmodulerc` file or more
specifically environment variables, though. There is a `shellmodulerc` template
file in your installation directory, which you can adapt.
If a `shellmodulerc` file setting the environment variables is found in the
installation directory or in `$HOME/.shellmodulerc` it will be sourced by
`require` _for Bash_ so these variables are available.

The next sections provide some more details about the configuration options.

## Configuring script search paths

By default, `require`_ for Bash_ will only resolve files stored on the local filesystem.
To resolve non-absolute file names, `require` will search several directories.

By default, it will search in the following order:
1. current directory (`${PWD}`)
1. directory where the script that uses `require` is executed is in
1. user's `${HOME}` directory
1. `require`_ for Bash_ installation directory

In all of these directories it will additionally look in any `shell_modules` directory, if it exists.
In addition to any of the aformentioned search paths, it searches in any path, that is configured using the `ShellModule_PATH` environment variable.
For example:
```sh
# Adding ${HOME}/bin, /opt/my_place and /etc to search path
export ShellModule_PATH="${HOME}/bin:/opt/my_place:/etc"
```

## Configuring non-local modules/files handling

In order to use resolvers for any methods, the module to be required must be
explicitly prefixed with `@`. However, even if it is prefixed, the local
search path will still be searched first (using the default local resolver).
As opposed to the local filenames, where the module name + `.sh` as well as
without `.sh` is searched, the external resolvers can be expected to always only
search for a module name ending with `.sh` (and even if `.sh` is not provided,
it will be added).

By default, `require` _for Bash_ comes with two resolvers: `GitHubResolver` and `CurlResolver`.
These resolvers are registered with one or multiple prefixes (schemes), which are by default:
- _GitHubResolver_: `gh:`
- _CurlResolver_: `https:`, `http:`, `ftp:`

By default, any valid external module, will be stored locally in a `shell_modules`
directory, wherever the currently invoked script file is placed.
This can be disabled using the `ShellModule_STORE_EXTERNAL_MODULES` environment
variable; simply set it to `false` to avoid storing them.
```sh
# To disable storing external modules
export ShellModule_STORE_EXTERNAL_MODULES=false
```
If external modules are stored, the next time they are required from the same
script, the stored copy is used.

--------------------------------------------------------------------------------

## Advanced resolver configuration

In addition to the aformentioned default resolvers' schemes, the same or other resolvers
can be configured using the `ShellModule_RESOLVERS` variable to accept specific
schemes, prefixes or resolve only specific paths.

The variable is an optional array that can contain (multiple) resolvers and
their configurations:
```sh
export ShellModule_RESOLVERS=(
  'import_resolvers/git_hub_resolver --config-option=value --another-one=here'
  'import_resolvers/curl_resolver'
)
```

Any resolver, that implements the resolver interface can be added here (even
multiple times with different configurations) - for more details see
[Creating your own resolver](#creating-your-own-resolver).

By default, all resolvers implement at least the following (optional) options:
- `--match-scheme=`: Colon separated scheme used to refer to the resolver; example: `--match-scheme=scripts:`
- `--prefix=`: Path to be prepended to the module name when this resolver is used; example: `--prefix=mysite.com/path/to/scripts`
- `--resolve-only=`: Prefix(es) of module names that are accepted by the resolver; example: `--resolve-only=module/path` or `--resolve-only='module/path1 another_module'`

### GitHub resolver

Assuming the GitHub user `jtrefke` has a repository `shell_modules`, there are
different configuration options to tie the resolver to, for instance all directories
in that repository without having to type everything everytime.

**Using private repositories**

If you want to use shell files from private repositories, you'll have to use a
method of authentication. The GitHub resolver uses GitHub's personal access
tokens for this purpose (see [Personal access tokens in the GitHub settings](https://github.com/settings/tokens)).

To provide your personal access token use the `--token` option:
```sh
  # --token=YOUR_TOKEN_HERE

  # For example
  export ShellModule_RESOLVERS=(
    'import_resolvers/git_hub_resolver --token=4a68631afb82ba1a9f9c49892e0e3c82eaa7ef66'
  )
```

**Bind resolver to repository owner**
```sh
  # --owner=REPOSITORY_OWNER

  # For example
  # ...
    'import_resolvers/git_hub_resolver --owner=jtrefke'
  # ...
```

**Bind resolver to a owner and repository**
```sh
  # --owner=REPOSITORY_OWNER --repo=REPOSITORY

  # For example
  # ...
    'import_resolvers/git_hub_resolver --owner=jtrefke --repo=shell_modules'
  # ...
```

**Bind resolver to an owner, repo, and branch (tag/release?)**
```sh
  # --owner=REPOSITORY_OWNER --repo=REPOSITORY --ref=BRANCH

  # For example
  # ...
    'import_resolvers/git_hub_resolver --owner=jtrefke --repo=shell_modules --ref=master'
  # ...
```

**Bind resolver to any prefix**
```sh
  # --owner=REPOSITORY_OWNER --repo=REPOSITORY --ref=BRANCH --prefix=SOME_PATH/AND_MORE/
  # OR simply
  # --prefix=REPOSITORY_OWNER/REPOSITORY/BRANCH/SOME_PATH/AND_MORE/

  # For example
  # ...
    'import_resolvers/git_hub_resolver --owner=jtrefke --repo=shell_modules --ref=master --prefix=scripts/'
  # ...
  # OR
  # ...
    'import_resolvers/git_hub_resolver --prefix=jtrefke/shell_modules/master/scripts/'
  # ...
```

**Resolve only specific paths**

By default, the GitHub resolver will try to load any given repository-path. In order
to use the resolver only for specific repositories or paths, use `--resolve-only`
```sh
  # --resolve-only=PREFIX_A
  # OR
  # --resolve-only='PREFIX_A PREFIX_B PREFIX_C'

  # For example
  # ...
    'import_resolvers/git_hub_resolver --resolve-only=jtrefke/shell_modules/master/scripts/'
  # ...
  # OR
  # ...
    'import_resolvers/git_hub_resolver --prefix=jtrefke/shell_modules/master/ --resolve-only="scripts/ helpers/ lib/"'
  # ...
```

### Curl resolver

By default, the CurlResolver will try to load any given module name.
If there is no scheme/protocol in the module name, `http` will be used as the default.
Only web results with a status code less than 400 will be accepted as a result.


**Use basic authentication**
To configure the resolver for basic authentication, it will accept a username
and password combination. If there is no user/password for ftp connections
provided, `anonymous` will be used as username and password.
```sh
  # --user=USERNAME:PASSWORD
  # OR
  # --user=USERNAME
  # For example
  # ...
    'import_resolvers/curl_resolver --user=shellscript:secretpass'
  # ...
  # OR
  # ...
    'import_resolvers/curl_resolver --user=anonymous'
  # ...
```

**Bind resolver to any prefix**
```sh
  # --prefix=URL_PREFIX
  # For example
  # ...
    'import_resolvers/curl_resolver --prefix=http://acme.org/jtrefke/shell_modules/'
  # ...
  # OR
  # ...
    'import_resolvers/curl_resolver --prefix=ftp://acme.org/jtrefke/shell_modules/'
  # ...
```

**Resolve only specific paths**

Similar to the _GitHubResolver_, the curl resolver resolves all given module names
by default. To resolve only certain module names, use the `--resolve-only`
configuration option.

```sh
  # --resolve-only=PREFIX_A
  # OR
  # --resolve-only='PREFIX_A PREFIX_B PREFIX_C'

  # For example
  # ...
    'import_resolvers/curl_resolver --resolve-only=jtrefke/shell_modules/scripts/'
  # ...
  # OR
  # ...
    'import_resolvers/curl_resolver --prefix=http://acme.org/jtrefke/shell_modules/ --resolve-only="scripts/ helpers/ lib/"'
  # ...
```

**Using any curl options**

In addition to any options provided above, you can configure the provider to
use/pass through any curl options:

```sh
  # For example
  # ...
    'import_resolvers/curl_resolver --proxy http://proxy.acme.org:8080 --keepalive-time 10'
  # ...
  # OR
  # ...
    'import_resolvers/curl_resolver --insecure'
  # ...
```
_NOTE:_ Passing in curl options curl options might result in errors with the resolver,
if certain arguments are used, so be careful.
 In any case, the following curl options should _never_ be passed through:
- `-o`/`--output`
- `-D`/`--dump-header`
- `-L`/`--location`
- `-u`/`--user`
- `-S`/`--show-error`

# Developing modules for `require` _for Bash_

The idea behind `require` _for Bash_ is, that scripts follow certain conventions
to be safely and reliably usable together with other scripts without side-effects.
In addition to that, sharing scripts with others and understanding what they do
becomes easier.
This is not to say that, if scripts don't follow the conventions, that they don't
work, _**but**_ they might not work as expected. For instance if multiple modules are
used in a file, there would be no guarantee, that one module does not override
another modules' functions or variables.
Unfortunately, with the existing traditional shell naming conventions, where
everything is `snake_cased` collisions may happen easily.

## What is a module?

A script that follows these conventions listed here is considered a module.
When loading a module, it should not execute any arbitrary code or modify other
independent modules. A module consists of one file; the file always starts
with a "shebang" that involves a `sh`ell, like `#!/usr/bin/env bash`,
`#!/bin/bash` or `#!/bin/sh`

## Naming conventions for modules

The basic idea is, that modules should not collide with each other (for instance
that a function of one module overrides another module's function).
From a module development standpoint, it should also simplify the
identification of what belongs to one module and if it is for instance a function
name or variable name.

The following naming scheme tries to address these issues. It introduces different naming
conventions to achieve a distinction between `modules`, `functions`, `variables` and `constants`.
In addtion to that the naming scheme introduces a differentiation for module-global/public
functions and constants that may be used by other developers/modules and
things that are only to be used internally (similar to public/private in
other programming languages).

To achieve this, basically different methods to build words for `modules`,
`functions`, `variables` and `constants`, as well as `public/private` are used:

- A module (in code) is uses `PascalCase`; examples: `MyModule`, `Console`
- A module's filename is equivalent to the module name, but `snake_cased` and ends with `.sh`; examples: `my_module.sh`, `console.sh`
- Module function names are `camelCased`
- Every function in a module is prefixed with the module name and `_`; examples: `MyModule_runSomething`, `Console_log`
- (Local) variables used in functions should be lowercase and `snake_cased`; examples: `some_value`, `message`
- Every module-global variable is prefixed with the module name and `_`
- Module constants or module-global variables/environment variables should be all
caps and `SNAKE_CASED`; examples: `MyModule_CONF_VALUE`, `Console_COLORS`
- Module functions or module-global variables which are not intended to be used by other modules, should be prefixed with `_`, i.e. two `_` in total; examples:
  - Non-public variables: `MyModule__RUN_CMD`, `Console__DEFAULT_FD`
  - Non-public functions: `MyModule__updateValue`, `Console__printColoredMsg`

## Other considerations when develping modules

- When requiring other modules, try to stick to the default scheme (see above)
- Ensure, that functions always return an exit status that reflects the success of their execution. For instance, if something went wrong in a function, but the last line is an `echo` statement, the program flow should rather be terminated right after the error occured before the `echo` or at least a `return $erroring_exit_code_here` or should be at the end
- Make use of exit status results; simple ways to handle them are `&&` and `||`
- Write error outputs to standard error (`>&2`) and anything else to standard out `>`
- Properly check inputs and outputs in functions
- Constants: Make use of the `readonly` builtin to ensure, they cannot be changed
- A function should clean up/unset after itself (basically reset state if modified, like changing back to initial directory, etc.)
- If a function gets very long, it might do too much and should be split up into multiple functions
- Write readable scripts; favor meaningful variable and function names over short ones, long options over short options, etc.; there will most certainly others be working with the script
- Try to make use of POSIX standards and apply best practices for shell scripts; be consistent :)

## Why should I develop a module?

Developing a module that can be used along with other modules ultimately allows
you to not repeat yourself over and over, get more done with existing code,
and can achieve better results in the end.
You will end up writing shorter scripts, that are easier to understand and to
debug.

Using and sharing code through `require` also enables you to centrally maintain
and update certain portions of scripts in today's system landscape where online/
interconnected systems are standard.
In addtion to that, sharing your modules and contributing to other modules
creates helps creating better scripts.


# Creating your own resolver

If necessary, creating your own resolver is not too difficult.
It's a simple bash script module, that has to implement four functions:
1. `ModuleName_canResolve`
1. `ModuleName_resolve`
1. `ModuleName_onRejected`
1. `ModuleName_onAccepted`

**Function `ModuleName_canResolve MODULE_SCHEME MODULE_NAME [OPTIONS]`**

This function will be called before a module is resolved, to ensure, that the resolver can resolve the module. If not, the resolver will not be used.

`MODULE_SCHEME: string` - Scheme used to resolve the module (for example: "gh:", "http:")
`MODULE_NAME: string` - Name of the module to be resolved (for example: "some_owner/scripts_repo/master/scripts")
`OPTIONS: array<string>` - Variable list of optional arguments that were used to configure the resolver. Any unrecognized options should be ignored by the resolver. At least the following options should be supported:
 - `-p=` and `--prefix=`: prefix to be prepended to the `MODULE_NAME`
 - `-s=` and `--match-scheme=`: scheme to be matched by the resolver
 - `-r=` and `--resolve-only=`: space separated list of prefixes of `MODULE_NAME` that should be resolved

`return` - `0`/`true` if the resolver in the given configuration has all information to resolve the given module and the `scheme` matches (if provided) as well as the `resolve-only` part (if provided) matches. Otherwise return `1`/`false`


**Function `ModuleName_resolve MODULE_SCHEME MODULE_NAME OUTPUT_FILE [OPTIONS]`**

The `resolve` function is supposed find the requested module based on the given inputs and save the contents in `OUTPUT_FILE`.

`MODULE_SCHEME: string` - Scheme used to resolve the module (for example: "gh:", "http:")
`MODULE_NAME: string` - Name of the module to be resolved (for example: "some_owner/scripts_repo/master/scripts")
`OUTPUT_FILE: string` - Path on the local filesystem where any resolved output file has to be written to
`OPTIONS: array<string>` - Variable list of optional arguments that were used to configure the resolver (see above)

`return` - `0`/`true` if the module could be resolved; `1`/`false` otherwise.

**Function `ModuleName_onRejected OUTPUT_FILE`**

If the content was resolved, but was not recognized as a valid bash script by `require` _for Bash_, the output file will be deleted and the `onRejected` function will be called.
Feel free to do any clean up work, if necessary, or simply return `true`

`OUTPUT_FILE: string` - Path on the local filesystem where any resolved output file had been written to

`return` - `0`/`true` or anything else; the result of this action will be ignored.

**Function `ModuleName_onAccepted MODULE_SCHEME MODULE_NAME OUTPUT_FILE`**

If the content was resolved and recognized as a valid bash script by `require` _for Bash_, the output file will be persisted in the path (if enabled/possible) and the `onAccepted` function will be called.
Feel free to do any clean up work, if necessary, or simply return `true`

`MODULE_SCHEME: string` - Scheme used to resolve the module (for example: `gh:`, `http:`)
`MODULE_NAME: string` - Name of the module to be resolved (for example: `some_owner/scripts_repo/master/scripts`)
`OUTPUT_FILE: string` - Path on the local filesystem where any resolved output file had been written to

`return` - `0`/`true` or anything else; the result of this action will be ignored.

To add your own resolvers, simply add them to any location in your search path (see [Script search paths](#configuring-script-search-paths)) and configure them to be used.


# Future plans/TODOs

- Look into other test frameworks (shpec or urchin)
- Increase test coverage/improve test base
- Extract common test functionality
- Clean up codebase
- Ensure POSIX shell compliance
- Add AWS S3 resolver
- Add SSH/scp resolver
- Add explicit versioning to module
- Implement `require "package" as "other_name"` to resolve potential name collisions
- Implement simple package manager/downloader for shell modules
- Support other shells than Bash
- Add uninstaller
