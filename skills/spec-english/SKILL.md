---
name: spec-english
description: Write output in ASD-STE100 Simplified Technical English — short active sentences, one meaning per word, simple tenses. Use when the user says "spec-english", "STE", "ASD-STE100", "simplified technical english", or asks for specs, procedures, or docs in controlled English. Accepts an optional intensity (0-100, default 80), e.g. "spec-english 100" or "intensity=50"; "stop spec-english" turns it off.
---

# Spec English (ASD-STE100)

Write all prose in ASD-STE100 Simplified Technical English at the active intensity.

## Intensity

- Default: **80**.
- The user sets it with a number from 0 to 100: `spec-english 100`, `intensity=50`, "spec-english at 60%".
- The level stays active for every response until the user changes it or says "stop spec-english" / "normal mode".
- When the level changes, confirm it in one line. Do not announce it again.

| Intensity | What applies |
|-----------|--------------|
| **100** | Every rule below, no exceptions. If a sentence breaks a rule, rewrite it. |
| **80** (default) | All sentence, grammar, and procedure rules are mandatory. Vocabulary is relaxed: prefer approved words, but use a common unapproved word when the approved alternative is longer or less clear. A rare sentence can exceed the length limit by a few words. |
| **50** | Mandatory: active voice, short sentences, one topic per sentence, one instruction per sentence, consistent terms. Tenses, -ing forms, and vocabulary are free. |
| **20** | Light touch: prefer short active sentences and consistent terms. Nothing is mandatory. |
| **0** | Off. |

For a value between two rows, apply the lower row fully and apply the rules of the higher row where they do not hurt clarity.

## Rules

### Words

1. Use words that are approved in the STE dictionary, with their approved part of speech and meaning. Example: "close" is a verb only, so write "Close the valve", not "The valve is close to the pump".
2. One word, one meaning. One thing, one name. Do not use synonyms for variety.
3. Technical names (nouns for things in the subject field: `endpoint`, `migration`, `pull request`) and technical verbs (`deploy`, `commit`, `rebase`) are permitted. Use them as that part of speech only.
4. Common replacements: "use" not "utilize", "do" not "perform" or "carry out", "start" not "commence" or "initiate", "stop" not "terminate", "make sure" not "ensure" or "verify that", "show" not "indicate" or "display", "before" not "prior to", "about" not "approximately", "sufficient" not "enough", "but" not "however".
5. Modal verbs: use "must" for an obligation and "can" for a capability or possibility. Do not use "should", "may", "might", "could", "would", or "shall".
6. No contractions, slang, idioms, or figures of speech.
7. Noun clusters: three words maximum. Break a longer cluster with a preposition or a hyphen. "The cover of the fuel pump inlet", not "the fuel pump inlet cover plate".
8. Do not omit words to make a sentence shorter. Keep the articles ("the", "a") and the subject.

### Sentences

9. Procedure (instructions): 20 words maximum for each sentence.
10. Description (explanations): 25 words maximum for each sentence.
11. One topic for each sentence. One instruction for each sentence, unless two actions occur at the same time.
12. Use the active voice. In a procedure, always. In a description, use the passive only when the agent is unknown or not important.
13. Use simple tenses only: simple present, simple past, simple future. No perfect tenses ("has changed") and no progressive tenses ("is running").
14. Do not use the -ing form of a verb, unless it is part of a technical name ("load balancing").
15. Use a vertical list when a sentence has three or more parallel items.

### Procedures

16. Write instructions as commands in the imperative: "Run the migration."
17. Put a condition before the instruction: "If the test fails, read the log."
18. Number the steps when their sequence is important.
19. Start a warning or a caution with a clear command or condition, then give the reason. Put it before the step it applies to.

### Descriptions

20. Six sentences maximum for each paragraph. One topic for each paragraph.
21. Start the paragraph with the topic sentence.
22. Give information in a logical sequence: general before specific, known before new.

## Not in scope

Do not change these to STE. Keep them exact:

- Code, commands, file paths, identifiers, and configuration values.
- Error messages, logs, and text that you quote.
- Text that the user tells you to keep as written.
- Text in a different language.

The rules apply to prose that you write: chat responses, documents, specs, comments, commit messages, and PR descriptions.

## Dictionary limit

The STE dictionary is not in this skill. Apply the vocabulary rule from your knowledge of ASD-STE100. If you are not sure that a word is approved, use the simplest common word with one clear meaning. Do not tell the user that a text is certified STE-compliant.

## Example

Before:

> Prior to deploying, you should ensure that the database migrations have been run, as failing to do so may result in the service being unable to start.

After (80):

> Before you deploy, make sure that the database migrations are complete. If they are not complete, the service cannot start.
