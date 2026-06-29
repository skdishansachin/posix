## Contributing to posix

Contributions are welcome. The easiest way to contribute is by opening a pull request with a clear description of the change.

For larger changes, it is a good idea to open an issue first to discuss the idea before spending time on implementation.

## AI-assisted contributions

AI tools may be used to help with this project, but they do not replace human responsibility. Contributions are reviewed on their own merit, and AI use is not treated differently from any other contribution.

Any contribution intended to be merged into the project that was created or edited with the help of AI must be reviewed by a human before it is submitted or merged. AI-generated work must not be the sole source of any contribution.

If AI was used, that must be disclosed in the final state of the contribution, such as the pull request description and/or the final squashed commit message.

This applies to contributions intended to be merged into the project, including code, documentation, translations, and significant content changes in issues or pull requests.

It does not apply to minor day-to-day communication such as casual comments, simple discussion messages, or quick edits like grammar or spelling corrections.

A simple disclosure is enough, such as:

- AI-assisted code, reviewed and edited by <email>
- AI-generated code, reviewed by <email>

The contributor remains fully responsible for the accuracy, quality, and originality of the contribution.

## Commit messages

Please take the time to write clear commit messages. Good commit messages and a clean git history make the project easier to maintain and contribute to.

Good git hygiene is expected. Keep commits focused, avoid unrelated changes, and prefer a clean and understandable history.

A commit message should briefly explain what changed and, when useful, why it changed. Additional details may be added in the commit body.

Examples:

```text
build: add support for release-safe builds
```

```text
feat: improve error handling for invalid input

This changes the parser so invalid arguments are reported with a clearer
message and a non-zero exit code.
```

## Coding style

Please follow the Zig Style Guide and run `zig fmt` before every commit.

In general, keep the code simple and easy to read. Prefer straightforward solutions over clever ones.

When possible, avoid unnecessary complexity. Performance is only a reason for added complexity when there is clear evidence that it helps.

A small style preference for this project is to keep short conditionals on one line when it remains readable:

```zig
if (foo) bar();
```

Use braces when the body becomes more than a single simple statement.

## Conduct

Please treat others with respect. Disagreements are normal, but harassment, abusive language, personal attacks, or other inappropriate behavior will not be tolerated.

Maintainers reserve the right to remove comments, reject contributions, report abuse, or ban users when necessary. Such actions may be taken without prior warning.

Respect each other and things will go smoothly.

## Project governance

The project owner and maintainers have the final say on project direction, accepted changes, and other decisions regarding the repository.

Not every contribution or feature request will be accepted, and decisions may be made in the interest of keeping the project simple and maintainable.

## Questions

If something is unclear, open an issue or ask in the pull request before making a large change.

---

*Parts of this document are inspired by the
[river CONTRIBUTING.md](https://codeberg.org/river/river/src/branch/main/CONTRIBUTING.md). Thanks to the river developers for their work.*
