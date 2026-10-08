# Contributing to Business Engineer Labs

Thanks for helping make these labs better. Small fixes are as welcome as new ideas.

## Ways to help

- **Report a problem:** open an issue with the lab name, the file and part you ran, and the error message or result you saw.
- **Fix a mistake:** typos, unclear comments and wrong expected results are all worth a pull request.
- **Suggest a lab:** describe the business problem first, then the platform. A good lab idea starts with a scenario, not a feature.

## Pull request checklist

- [ ] Every block of SQL has a `GOAL` comment and a `WHY` comment.
- [ ] Scripts run top to bottom on a fresh trial account.
- [ ] Anything destructive is commented out by default.
- [ ] No real credentials, usernames, account identifiers or customer data. Use placeholders such as `<your_username>`.
- [ ] Plain, friendly wording. Explain the idea before the syntax.

## Folder conventions

Each lab lives in `labs/NN-lab-name/` with a `README.md`, a `sql/` folder of numbered scripts, and a `docs/` folder for the guide and diagrams.
