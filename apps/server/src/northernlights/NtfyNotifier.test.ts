import { assert, describe, it } from "@effect/vitest";
import { EnvironmentId, ThreadId } from "@t3tools/contracts";
import type { AgentAwarenessState } from "@t3tools/shared/agentAwareness";

import { ntfyMessage } from "./NtfyNotifier.ts";

const TOPIC = "https://ntfy.sh/nl-secret-topic";

const state = (phase: AgentAwarenessState["phase"]): AgentAwarenessState => ({
  environmentId: EnvironmentId.make("env-1"),
  threadId: ThreadId.make("thread-1"),
  projectTitle: "northernlights",
  threadTitle: "Fix the build",
  phase,
  headline: "Agent finished",
  modelTitle: "claude",
  updatedAt: "2026-11-11T00:00:00.000Z",
  deepLink: "/threads/env-1/thread-1",
});

describe("ntfyMessage", () => {
  it("alerts once when a known thread enters an alert phase", () => {
    assert.isNull(ntfyMessage(TOPIC, undefined, state("completed")));
    assert.isNull(ntfyMessage(TOPIC, "running", state("running")));
    assert.isNull(ntfyMessage(TOPIC, "completed", state("completed")));
    assert.isNull(ntfyMessage(TOPIC, "running", null));

    const message = ntfyMessage(TOPIC, "running", state("completed"));
    assert.strictEqual(message?.url, "https://ntfy.sh");
    assert.strictEqual(message?.body.topic, "nl-secret-topic");
    assert.strictEqual(message?.body.click, "t3code://threads/env-1/thread-1");
    assert.isNotNull(ntfyMessage(TOPIC, "running", state("waiting_for_approval")));
  });
});
