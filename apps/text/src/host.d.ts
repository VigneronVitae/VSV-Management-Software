// The four things this periphery needs from whatever is running it, declared
// here rather than installed.
//
// `@types/node` would do this and it would be a new dependency, and CLAUDE.md's
// standing instruction is to consult before adding any. It is a reasonable thing
// to want and it should be asked for rather than slipped in under a feature, so
// this declares exactly the surface used and nothing else. If a later session
// needs more of the host than this, that is the moment to ask rather than the
// moment to keep extending this file.
//
// Deliberately narrow: `process.env` as a bag of strings, `exit`, the two
// streams, and the promise-shaped readline. Anything wider would be guessing at
// an api this code does not call.

declare const process: {
  env: Record<string, string | undefined>;
  exit(code?: number): never;
};

declare module "node:process" {
  export const stdin: unknown;
  export const stdout: { write(chunk: string): boolean };
}

declare module "node:readline/promises" {
  export function createInterface(options: { input: unknown; output: unknown }): {
    question(prompt: string): Promise<string>;
    close(): void;
  };
}
