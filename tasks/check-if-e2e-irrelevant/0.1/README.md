# Check-if-e2e-irrelevant Task

**Version:** 0.1

## Overview

The **Check-if-e2e-irrelevant Task** checks if the files changed in the pull request are
 all irrelevant to the e2e tests.
If all files are irrelevant, the task will exit with code 0 unless an error occurs, and 
sets the result accordingly.

### Features

- Check if the PR is e2e irrelevant.

## Parameters

| Name                | Description                                                                 | Optional | Default value                  |
|---------------------|-----------------------------------------------------------------------------|----------|--------------------------------|
| base-branch         | The name of base branch.                                                    | ❌ No    | `main`                         |  
| irrelevant_pattern  | The regular expression for matching irrelevant files                        | ❌ No    | '\(^\|.*\/)(\.gitignore\|PROJECT\|LICENSE\|\.sonarcloud\.properties\|\.gitlint\|\.dockerignore\)$' |

## Results

It returns "false" if the PR is e2e relevant, otherwise it returns "true" (including any error occurs).

