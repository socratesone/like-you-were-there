# Safety & Compliance Specification
## Time-Place Celebrity Walkthrough Generator (TPCWG)

## 1. Core Principle
This tool is for creating plausible, artistic historical dramatizations, **not** for creating photorealistic deepfakes, impersonating individuals, or generating defamatory content. All generated content should be clearly identifiable as an AI creation.

## 2. Default Guardrails (Required Implementation)
The following settings must be the default behavior of the system. They can only be overridden by explicit user configuration.

- `allow_living_people = false`
- `allow_minors = false`

The system **must** check for these flags and filter the subject list accordingly. Age must be computed for each subject, and if `birth_date` is unavailable, the subject should be treated with caution or rejected if their status (living/minor) cannot be determined.

## 3. Rules for Handling Living or Minor Subjects
If a user explicitly overrides the default guardrails, the following conditions **must** be met:

- **Attestation:** The user must provide an explicit confirmation that they have the rights and consent to use the likeness of any living person. This action must be logged.
- **Mandatory Labeling:** If `allow_living_people = true`, the final video output **must** include a clear and conspicuous disclaimer, such as "AI-generated dramatization." This is not optional.
- **Content Restrictions:** The generation prompts must not create content that is defamatory, misleading, or places the subject in a false light. Prompts should aim for neutral, plausible scenes.

## 4. Audit and Reproducibility
To ensure compliance and for debugging purposes, the following must be logged for every run:

- The final, resolved `job.json` configuration.
- The list of candidate subjects sourced from external databases.
- The final `subjects.json` produced by the LLM.
- All prompts (`prompt_image`, `prompt_video`) sent to the generation APIs.
- A report (`report.md`) containing provider IDs, costs, and timings.

These logs provide a clear audit trail of how and why a piece of content was generated.
