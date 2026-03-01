# Audio Chaptering Tool — PRD Planning

You are planning a new feature: an **audio chaptering tool** that automatically
generates chapter markers for audio files (podcasts, audiobooks, lectures, meetings)
using transcription and AI summarization.

**Important:** Each session starts fresh with no memory of previous sessions.

## Your Task

1. Interview the user in depth using the `ask_user_questions` MCP tool
2. Based on answers, write a complete PRD to `tasks/prd-audio-chaptering.md`
3. Convert the PRD to `prd.json` for Ralph execution

## Interview Process

Use the `ask_user_questions` tool to interview the user about literally anything:
technical implementation, UI & UX, concerns, tradeoffs, architecture, edge cases,
deployment, pricing — whatever is needed to produce an unambiguous PRD.

**Rules:**
- Ask 3-5 questions per round (the tool supports up to 5)
- Make questions non-obvious and in-depth — do NOT ask surface-level things
- Each round should go deeper based on previous answers
- Continue interviewing for as many rounds as needed (typically 3-5 rounds)
- Only stop when you have full clarity on every aspect

### Round Structure

**Round 1 — Problem & Users:**
Who is this for? What pain does it solve? What exists today and why is it insufficient?

**Round 2 — Core Experience:**
What does the happy path look like? What's the input/output? How does the user
interact with the result? What formats matter?

**Round 3 — Technical Depth:**
Transcription approach (local vs cloud)? Audio processing pipeline? How to handle
long files? Streaming vs batch? What about cost?

**Round 4 — Edge Cases & Tradeoffs:**
What happens with poor audio quality? Multiple speakers? Music segments?
What are you willing to sacrifice for v1? Performance vs accuracy?

**Round 5+ — Refinement:**
Fill in any remaining gaps. Clarify ambiguities from earlier answers.
Nail down acceptance criteria specifics.

### Question Quality Guidelines

BAD (too obvious):
- "What audio formats should we support?"
- "Should it have a CLI?"

GOOD (insightful, forces real decisions):
- "When a chapter boundary is ambiguous (e.g., a topic shift happens gradually
  over 30 seconds), should the marker go at the start of the transition, the
  middle, or the end — and should users be able to adjust this threshold?"
- "If transcription costs $0.006/min via cloud API but local whisper is free
  and 3x slower, which is the default and should users be able to switch?"
- "Should chapter titles be factual summaries ('Discussion of Q3 revenue') or
  engaging hooks ('The revenue surprise nobody expected') — and who decides?"

### After All Rounds Complete

Once you have full clarity, write the PRD following this structure:

1. **Introduction/Overview** — problem and solution summary
2. **Goals** — measurable objectives
3. **User Stories** — small, implementable stories with acceptance criteria
4. **Functional Requirements** — numbered, unambiguous (FR-1, FR-2, ...)
5. **Non-Goals** — explicit scope boundaries
6. **Technical Considerations** — architecture, dependencies, constraints
7. **Success Metrics** — how we know it worked

Save to `tasks/prd-audio-chaptering.md`.

Then convert to `prd.json` with this structure:
```json
{
  "project": "AudioChaptering",
  "branchName": "ralph/audio-chaptering",
  "description": "...",
  "userStories": [
    {
      "id": "US-001",
      "title": "...",
      "description": "...",
      "acceptanceCriteria": ["...", "..."],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
```

Keep each story small enough to complete in one focused session.
