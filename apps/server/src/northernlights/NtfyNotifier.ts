// Northern Lights: phone alerts through ntfy instead of the T3 Connect relay.
// Set NL_NTFY_URL to a topic URL such as https://ntfy.sh/<long-random-topic>.
// The topic name is the only secret, so make it long and random.
import type { EnvironmentId, ThreadId } from "@t3tools/contracts";
import {
  type AgentAwarenessPhase,
  type AgentAwarenessState,
  projectThreadAwarenessV2,
} from "@t3tools/shared/agentAwareness";
import * as Cause from "effect/Cause";
import * as Config from "effect/Config";
import * as Effect from "effect/Effect";
import * as Layer from "effect/Layer";
import * as Option from "effect/Option";
import * as Stream from "effect/Stream";
import * as HttpClient from "effect/http/HttpClient";
import * as HttpClientRequest from "effect/http/HttpClientRequest";
import * as HttpClientResponse from "effect/http/HttpClientResponse";

import * as ServerEnvironment from "../environment/ServerEnvironment.ts";
import * as ThreadManagement from "../orchestration-v2/ThreadManagementService.ts";
import * as ProjectService from "../project/ProjectService.ts";
import { shouldPublishAgentAwarenessEvent } from "../relay/AgentAwarenessRelay.ts";
import { forkParked } from "../serverActivation.ts";

const ALERTS: Partial<Record<AgentAwarenessPhase, { priority: number; tag: string }>> = {
  waiting_for_approval: { priority: 4, tag: "raised_hand" },
  waiting_for_input: { priority: 4, tag: "question" },
  completed: { priority: 3, tag: "white_check_mark" },
  failed: { priority: 4, tag: "x" },
};

/** The ntfy JSON message for a phase change, or null when it should stay quiet. */
export function ntfyMessage(
  topicUrl: string,
  previous: AgentAwarenessPhase | null | undefined,
  state: AgentAwarenessState | null,
): { readonly url: string; readonly body: Record<string, unknown> } | null {
  // `undefined` means this thread's first event since startup: record it, don't alert.
  if (previous === undefined || state === null || state.phase === previous) return null;
  const alert = ALERTS[state.phase];
  if (alert === undefined) return null;
  const url = new URL(topicUrl);
  return {
    url: url.origin,
    body: {
      topic: url.pathname.replace(/^\/+/, ""),
      title: `${state.headline}: ${state.threadTitle}`,
      message: state.detail ?? state.projectTitle,
      priority: alert.priority,
      tags: [alert.tag],
      // deepLink is "/threads/<env>/<thread>"; the app handles t3code://threads/...
      click: `t3code:/${state.deepLink}`,
    },
  };
}

export const layer = Layer.effectDiscard(
  Effect.gen(function* () {
    const topicUrl = (yield* Config.String("NL_NTFY_URL").pipe(Config.withDefault(""))).trim();
    if (topicUrl === "") return;
    const httpClient = yield* HttpClient.HttpClient;
    const threads = yield* ThreadManagement.ThreadManagementService;
    const projects = yield* ProjectService.ProjectService;
    const environmentId: EnvironmentId = yield* (yield* ServerEnvironment.ServerEnvironment)
      .getEnvironmentId;
    // ponytail: one entry per thread seen since startup; fine for a single user's server.
    const lastPhase = new Map<string, AgentAwarenessPhase | null>();

    // Untraced: runs once per domain event.
    const onEvent = Effect.fnUntraced(function* (threadId: ThreadId) {
      const thread = (yield* threads.getAgentAwarenessSnapshot(threadId)).threads[0];
      if (thread === undefined || thread.archivedAt !== null) return;
      const project = yield* projects.getById(thread.projectId);
      if (Option.isNone(project)) return;
      const state = projectThreadAwarenessV2({ environmentId, project: project.value, thread });
      const message = ntfyMessage(topicUrl, lastPhase.get(thread.id), state);
      lastPhase.set(thread.id, state?.phase ?? null);
      if (message === null) return;
      yield* HttpClientRequest.post(message.url).pipe(
        HttpClientRequest.bodyJson(message.body),
        Effect.flatMap(httpClient.execute),
        Effect.flatMap(HttpClientResponse.filterStatusOk),
        Effect.timeout("10 seconds"),
      );
    });

    yield* Effect.logInfo("Northern Lights ntfy alerts enabled");
    yield* forkParked(
      Stream.runForEach(threads.streamDomainEvents, (event) =>
        shouldPublishAgentAwarenessEvent(event)
          ? onEvent(event.threadId).pipe(
              Effect.catchCause((cause) =>
                Effect.logWarning("ntfy alert failed", { cause: Cause.pretty(cause) }),
              ),
            )
          : Effect.void,
      ),
    );
  }),
);
