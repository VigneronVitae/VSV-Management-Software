---
Type: guide
Purpose: "How the assistant is switched on at a winery, what it can and cannot
          do, and where to look when it is wrong."
Depends on: [supabase/migrations/0170_an_assistant_asks_as_you.sql,
             supabase/functions/agent/index.ts]
Depended on by: [docs/status-ledger.md]
---

# The assistant

An **Ask** button on the home screen. Somebody types a question in a sentence;
the assistant reads the winery's records as that person and answers. When the
answer is that something should be recorded, it fills in the form for it, and
the person checks it and taps **Confirm** or **Not this**.

## What it can and cannot do

- **It reads as you.** Every read goes to the API with the asker's own sign-in,
  so it sees exactly what their phone would and nothing more. A cellar hand's
  question cannot read an administrator's records.
- **It records nothing.** A proposal is the capability's own form, filled in.
  Confirm makes the same call that form's screen makes, as the person who
  tapped it. A refusal reads the way it would by hand.
- **It only knows what the contract offers.** Its two tools, read and propose,
  are made from `agent_contract()`: every readable and capability in a module
  open to it. A capability added in a migration is there for the next
  question; nothing here has to be kept in step.
- **The books are closed to it** until an administrator opens them (the
  capability "Decide what the assistant may read"). Whatever it reads to answer
  a question goes to the outside provider, and money should not go there
  because somebody asked about a tank. See S-152 for the gap this leaves.
- **Administrators only**, until Who may do what allows cellar hands to ask.

## Switching it on

The keys live on the winery computer and nowhere else. A phone never sees one.

1. Copy `supabase/functions/agent/.env.example` to `supabase/functions/.env`.
2. Fill in a key and a model for each provider you want. Claude needs only the
   key; its model defaults to `claude-opus-5-5`. ChatGPT, DeepSeek and Kimi
   need a model name, and DeepSeek and Kimi an address, from each one's own API
   documentation. A provider with no key or no model is simply not offered.
3. Restart the stack, which is what starts the function and makes it read the
   file. Take a backup first; stopping keeps the data, and the backup is for
   the day it does not:

```sh
bun run db:backup
supabase stop
supabase start
```

Practice runs the same function from the same source, with its own keys in
`sandbox/supabase/functions/.env`, and `bash scripts/practice.sh stop` then
`start` restarts it.

## Where to look

- **What was asked, and by whom:** the readable "What the assistant was asked"
  (`agent_log`). An administrator sees everybody's; anybody else sees their own.
- **What it read and proposed for a question:** `agent_turn.reads` and
  `agent_turn.proposals`. Rows read are counted, not copied.
- **What became of a proposal:** `agent_outcome`, one row for each confirm,
  decline or refusal. A retry after a refusal is another row.
- **Why it did not answer:** `agent_turn.failure`, which always says why when
  there is no answer. The function's own log is
  `docker logs supabase_edge_runtime_vsv-management-software`.
