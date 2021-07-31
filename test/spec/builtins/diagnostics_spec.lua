local diagnostics = require("null-ls.builtins.diagnostics")

describe("diagnostics", function()
    describe("chktex", function()
        local linter = diagnostics.chktex
        local parser = linter._opts.on_output
        local file = {
            [[\documentclass{article}]],
            [[\begin{document}]],
            [[Lorem ipsum dolor \sit amet]],
            [[\end{document}]],
        }

        it("should create a diagnostic", function()
            local output = [[3:23:1:Warning:Command terminated with space.]]
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                row = "3",
                col = "23",
                end_col = 24,
                severity = 2,
                message = "Command terminated with space.",
            }, diagnostic)
        end)
    end)

    describe("clang_tidy", function()
        local linter = diagnostics.clang_tidy
        local parser = linter._opts.on_output
        local file = {
            [[int test(int* v) {]],
            [[  printf("%s", v);]],
            [[}]],
        }
        it("should create a diagnostic", function()
            local output =
                [[main.cpp:2:16: warning: format specifies type 'char *' but the argument has type 'int *' [clang-diagnostic-format] ]]
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                row = "2",
                col = "16",
                severity = 2,
                code = "clang-diagnostic-format",
                message = "format specifies type 'char *' but the argument has type 'int *'",
            }, diagnostic)
        end)
    end)

    describe("golangci_lint", function()
        local linter = diagnostics.golangci_lint
        local parser = linter._opts.on_output
        local file = {
            [[
              package main

              import (
                "fmt"
                "os/exec"
              )

              // snake_case should not be allowed.
              var go_version string
              // exporter variables should have comment.
              var ExitCode = 0
              //bad comment formatting.
              func main() {
                executable := "go"
                command := "version"
                command = "version"
                cmd := exec.Command(executable, command)
                stdout, err := cmd.Output()
                if err != nil {
                  // the `if` statement should have and empty line above it
                  fmt.Println(err.Error())
                  ExitCode = 1
                }
                // there should be an empty line below this assignment
                go_version = string(stdout)
                fmt.Printf("go_version is %v\n", go_version)
                fmt.Println("Checking the os version")
              }
            ]],
        }
        it("should create a diagnostic with a code", function()
            local output =
                [[cmd/main.go:12:1  gocritic     commentFormatting: put a space between `//` and comment text]]
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                row = "12",
                col = "1",
                severity = 1,
                code = "commentFormatting",
                message = "put a space between `//` and comment text",
                source = "gocritic",
            }, diagnostic)
        end)
        it("should create a diagnostic without a code", function()
            local output = [[cmd/main.go:15:2  ineffassign  ineffectual assignment to command]]
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                row = "15",
                col = "2",
                severity = 1,
                message = "ineffectual assignment to command",
                source = "ineffassign",
            }, diagnostic)
        end)
    end)

    describe("write-good", function()
        local linter = diagnostics.write_good
        local parser = linter._opts.on_output
        local file = {
            [[Any rule whose heading is ~~struck through~~ is deprecated, but still provided for backward-compatibility.]],
        }

        it("should create a diagnostic", function()
            local output = [[rules.md:1:46:"is deprecated" may be passive voice]]
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                row = "1", --
                col = 47,
                end_col = 59,
                severity = 1,
                message = '"is deprecated" may be passive voice',
            }, diagnostic)
        end)
    end)

    describe("markdownlint", function()
        local linter = diagnostics.markdownlint
        local parser = linter._opts.on_output
        local file = {
            [[<a name="md001"></a>]],
            [[]],
        }

        it("should create a diagnostic with a column", function()
            local output = "rules.md:1:1 MD033/no-inline-html Inline HTML [Element: a]"
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                row = "1", --
                col = "1",
                severity = 1,
                message = "Inline HTML [Element: a]",
            }, diagnostic)
        end)
        it("should create a diagnostic without a column", function()
            local output =
                "rules.md:2 MD012/no-multiple-blanks Multiple consecutive blank lines [Expected: 1; Actual: 2]"
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                row = "2", --
                severity = 1,
                message = "Multiple consecutive blank lines [Expected: 1; Actual: 2]",
            }, diagnostic)
        end)
    end)

    describe("tl check", function()
        local linter = diagnostics.teal
        local parser = linter._opts.on_output
        local file = {
            [[require("settings").load_options()]],
            "vim.cmd [[",
            [[local command = table.concat(vim.tbl_flatten { "autocmd", def }, " ")]],
        }

        it("should create a diagnostic (quote field is between quotes)", function()
            local output = [[init.lua:1:8: module not found: 'settings']]
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                row = "1", --
                col = "8",
                end_col = 17,
                severity = 1,
                message = "module not found: 'settings'",
                source = "tl check",
            }, diagnostic)
        end)
        it("should create a diagnostic (quote field is not between quotes)", function()
            local output = [[init.lua:2:1: unknown variable: vim]]
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                row = "2", --
                col = "1",
                end_col = 3,
                severity = 1,
                message = "unknown variable: vim",
                source = "tl check",
            }, diagnostic)
        end)
        it("should create a diagnostic by using the second pattern", function()
            local output = [[autocmds.lua:3:46: argument 1: got <unknown type>, expected {string}]]
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                row = "3", --
                col = "46",
                severity = 1,
                message = "argument 1: got <unknown type>, expected {string}",
                source = "tl check",
            }, diagnostic)
        end)
    end)

    describe("shellcheck", function()
        local linter = diagnostics.shellcheck
        local parser = linter._opts.on_output

        it("should create a diagnostic with info severity", function()
            local output = vim.fn.json_decode([[
            [{
              "file": "./OpenCast.sh",
              "line": 21,
              "endLine": 21,
              "column": 8,
              "endColumn": 37,
              "level": "info",
              "code": 1091,
              "message": "Not following: script/cli_builder.sh was not specified as input (see shellcheck -x).",
              "fix": null
            }] ]])
            local diagnostic = parser({ output = output })
            assert.are.same({
                {
                    row = 21, --
                    end_row = 21,
                    col = 8,
                    end_col = 37,
                    severity = 3,
                    message = "Not following: script/cli_builder.sh was not specified as input (see shellcheck -x).",
                },
            }, diagnostic)
        end)
        it("should create a diagnostic with style severity", function()
            local output = vim.fn.json_decode([[
            [{
              "file": "./OpenCast.sh",
              "line": 21,
              "endLine": 21,
              "column": 8,
              "endColumn": 37,
              "level": "style",
              "code": 1091,
              "message": "Not following: script/cli_builder.sh was not specified as input (see shellcheck -x).",
              "fix": null
            }] ]])
            local diagnostic = parser({ output = output })
            assert.are.same({
                {
                    row = 21, --
                    end_row = 21,
                    col = 8,
                    end_col = 37,
                    severity = 4,
                    message = "Not following: script/cli_builder.sh was not specified as input (see shellcheck -x).",
                },
            }, diagnostic)
        end)
    end)

    describe("selene", function()
        local linter = diagnostics.selene
        local parser = linter._opts.on_output
        local file = {
            "vim.cmd [[",
            [[CACHE_PATH = vim.fn.stdpath "cache"]],
        }

        it("should create a diagnostic (quote is between backquotes)", function()
            local output = [[init.lua:1:1: error[undefined_variable]: `vim` is not defined]]
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                row = "1", --
                col = "1",
                end_col = 3,
                severity = 1,
                code = "undefined_variable",
                message = "`vim` is not defined",
            }, diagnostic)
        end)
        it("should create a diagnostic (quote is not between backquotes)", function()
            local output =
                [[lua/default-config.lua:2:1: warning[unused_variable]: CACHE_PATH is defined, but never used]]
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                row = "2", --
                col = "1",
                end_col = 10,
                severity = 2,
                code = "unused_variable",
                message = "CACHE_PATH is defined, but never used",
            }, diagnostic)
        end)
    end)

    describe("eslint", function()
        local linter = diagnostics.eslint
        local parser = linter._opts.on_output

        it("should create a diagnostic with warning severity", function()
            local output = vim.fn.json_decode([[ 
            [{
              "filePath": "/home/luc/Projects/Pi-OpenCast/webapp/src/index.js",
              "messages": [
                {
                  "ruleId": "quotes",
                  "severity": 1,
                  "message": "Strings must use singlequote.",
                  "line": 1,
                  "column": 19,
                  "nodeType": "Literal",
                  "messageId": "wrongQuotes",
                  "endLine": 1,
                  "endColumn": 26,
                  "fix": {
                    "range": [
                      18,
                      25
                    ],
                    "text": "'react'"
                  }
                }
              ]
            }] ]])
            local diagnostic = parser({ output = output })
            assert.are.same({
                {
                    row = 1, --
                    end_row = 1,
                    col = 19,
                    end_col = 26,
                    severity = 2,
                    code = "quotes",
                    message = "Strings must use singlequote.",
                },
            }, diagnostic)
        end)
        it("should create a diagnostic with error severity", function()
            local output = vim.fn.json_decode([[ 
            [{
              "filePath": "/home/luc/Projects/Pi-OpenCast/webapp/src/index.js",
              "messages": [
                {
                  "ruleId": "quotes",
                  "severity": 2,
                  "message": "Strings must use singlequote.",
                  "line": 1,
                  "column": 19,
                  "nodeType": "Literal",
                  "messageId": "wrongQuotes",
                  "endLine": 1,
                  "endColumn": 26,
                  "fix": {
                    "range": [
                      18,
                      25
                    ],
                    "text": "'react'"
                  }
                }
              ]
            }] ]])
            local diagnostic = parser({ output = output })
            assert.are.same({
                {
                    row = 1, --
                    end_row = 1,
                    col = 19,
                    end_col = 26,
                    severity = 1,
                    code = "quotes",
                    message = "Strings must use singlequote.",
                },
            }, diagnostic)
        end)
    end)

    describe("hadolint", function()
        local linter = diagnostics.hadolint
        local parser = linter._opts.on_output

        it("should create a diagnostic with warning severity", function()
            local output = vim.fn.json_decode([[
                  [{
                    "line": 24,
                    "code": "DL3008",
                    "message": "Pin versions in apt get install. Instead of `apt-get install <package>` use `apt-get install <package>=<version>`",
                    "column": 1,
                    "file": "/home/luc/Projects/Test/buildroot/support/docker/Dockerfile",
                    "level": "warning"
                  }]
            ]])
            local diagnostic = parser({ output = output })
            assert.are.same({
                {
                    row = 24, --
                    col = 1,
                    severity = 2,
                    code = "DL3008",
                    message = "Pin versions in apt get install. Instead of `apt-get install <package>` use `apt-get install <package>=<version>`",
                },
            }, diagnostic)
        end)
        it("should create a diagnostic with info severity", function()
            local output = vim.fn.json_decode([[
                  [{
                    "line": 24,
                    "code": "DL3059",
                    "message": "Multiple consecutive `RUN` instructions. Consider consolidation.",
                    "column": 1,
                    "file": "/home/luc/Projects/Test/buildroot/support/docker/Dockerfile",
                    "level": "info"
                  }]
            ]])
            local diagnostic = parser({ output = output })
            assert.are.same({
                {
                    row = 24, --
                    col = 1,
                    severity = 3,
                    code = "DL3059",
                    message = "Multiple consecutive `RUN` instructions. Consider consolidation.",
                },
            }, diagnostic)
        end)
    end)

    describe("flake8", function()
        local linter = diagnostics.flake8
        local parser = linter._opts.on_output
        local file = {
            [[#===- run-clang-tidy.py - Parallel clang-tidy runner ---------*- python -*--===#]],
        }

        it("should create a diagnostic", function()
            local output = [[run-clang-tidy.py:3:1: E265 block comment should start with '# ']]
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                row = "3", --
                col = "1",
                severity = 1,
                code = "E265",
                message = "block comment should start with '# '",
            }, diagnostic)
        end)
    end)

    describe("misspell", function()
        local linter = diagnostics.misspell
        local parser = linter._opts.on_output
        local file = {
            [[Did I misspell langauge ?]],
        }

        it("should create a diagnostic", function()
            local output = [[stdin:1:15: "langauge" is a misspelling of "language"]]
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                row = "1", --
                col = "15",
                severity = 3,
                message = [["langauge" is a misspelling of "language"]],
            }, diagnostic)
        end)
    end)

    describe("vint", function()
        local linter = diagnostics.vint
        local parser = linter._opts.on_output

        it("should create a diagnostic with warning severity", function()
            local output = vim.fn.json_decode([[
                  [{
                    "file_path": "/home/luc/Projects/Test/vim-scriptease/plugin/scriptease.vim",
                    "line_number": 5,
                    "column_number": 37,
                    "severity": "style_problem",
                    "description": "Use the full option name `compatible` instead of `cp`",
                    "policy_name": "ProhibitAbbreviationOption",
                    "reference": ":help option-summary"
                  }]
            ]])
            local diagnostic = parser({ output = output })
            assert.are.same({
                {
                    row = 5, --
                    col = 37,
                    severity = 3,
                    code = "ProhibitAbbreviationOption",
                    message = "Use the full option name `compatible` instead of `cp`",
                },
            }, diagnostic)
        end)
    end)
end)
