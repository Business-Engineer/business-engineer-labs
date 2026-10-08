# Business Engineer Labs

![License: MIT](https://img.shields.io/badge/license-MIT-green)
![Labs](https://img.shields.io/badge/labs-1-blue)
![Platform](https://img.shields.io/badge/platform-Snowflake-29B5E8)

**Hands-on data and cloud case studies. Start from the business problem, finish with working code.**

Business Engineer is a video series about turning technology into business outcomes. Every video starts with a real business scenario, explains the design with plain-language analogies, then builds it live. This repository holds the code, scripts and diagrams for each lab so you can follow along and run everything yourself.

## The labs

| # | Lab | Platform | Level | Video |
| --- | --- | --- | --- | --- |
| 01 | [Row-level and column-level security on one shared table](labs/01-snowflake-row-and-column-security) | Snowflake | Beginner to intermediate | [Watch](#) |

More labs are on the way. Have a topic you want covered? [Open an issue](../../issues) and tell us the business problem.

## How every lab is organised

Each lab folder follows the same pattern, so you always know where to look.

```text
labs/NN-lab-name/
├── README.md        The scenario, what you will build, and how to run it
├── sql/             Numbered scripts: run them in order, one part at a time
└── docs/            Written guide and diagrams
```

The scripts are numbered and every block of SQL carries two comments: `GOAL` says what we are trying to achieve and `WHY` says why that step matters. If you only want to learn the idea, read the comments. If you want to run it, paste and execute.

## Getting started

1. Clone the repository: `git clone https://github.com/Business-Engineer/business-engineer-labs.git`
2. Open the lab you want and read its README for the requirements.
3. Run the scripts in a trial or sandbox account. Never run lab scripts against production.

## Community

- **Questions:** use [Discussions](../../discussions) or open an issue.
- **Found a mistake?** Pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).
- **Share your build:** if you adapted a lab for your own scenario, tell us. The best examples may feature in a future video.

## About

Business Engineer is created by Anshul, a technology leader with 19 years of experience across business intelligence, solution architecture, cloud and programme delivery. The channel is for people who want to understand not just how technology works, but why it matters to the business.

Connect on [LinkedIn](https://www.linkedin.com/in/anshulptiwari).

## Licence

Released under the [MIT Licence](LICENSE). Use the code freely, and please keep the attribution.
