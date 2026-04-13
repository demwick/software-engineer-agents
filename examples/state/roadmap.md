# Project Roadmap

## Project: example-todo-app
## Created: 2026-04-14
## Status: in-progress

## Phases

### Phase 1: Scaffolding & data layer
**Goal:** Bootstrap the project with a working data layer and in-memory persistence.
**Scope:**
- Next.js 15 + TypeScript scaffold
- `src/lib/todos.ts` with CRUD against an in-memory Map
- Basic types in `src/types/todo.ts`
- Root README with `npm run dev` instructions
**Deliverable:** Running dev server, CRUD callable from a Node REPL.
**Depends on:** none
**Status:** done

### Phase 2: List & detail UI
**Goal:** Render the todo list and a single-todo detail view.
**Scope:**
- `/` page: list of todos, empty state, "add" form
- `/todos/[id]` page: detail + edit + delete
- Shared `TodoCard` component
- Minimal Tailwind styling
**Deliverable:** User can view, add, edit, delete todos in the browser.
**Depends on:** Phase 1
**Status:** in-progress

### Phase 3: Persistence with SQLite
**Goal:** Replace the in-memory store with a durable SQLite database.
**Scope:**
- `better-sqlite3` dependency
- Migration: `todos` table
- Adapter in `src/lib/todos.ts` (same interface, different backend)
- Seed script for dev data
**Deliverable:** Todos survive server restart.
**Depends on:** Phase 2
**Status:** pending

### Phase 4: Auth (single-user token)
**Goal:** Gate the app behind a single shared token (simplest possible auth for MVP).
**Scope:**
- Env var `APP_TOKEN`
- Middleware that checks `Authorization: Bearer <token>` on `/api/*`
- Client-side login form storing the token in `localStorage`
**Deliverable:** Unauthenticated requests get a 401; authenticated requests work as before.
**Depends on:** Phase 3
**Status:** pending

### Phase 5: Deploy to Fly.io
**Goal:** Ship a running instance on Fly.io with a public URL.
**Scope:**
- Dockerfile
- `fly.toml`
- Volume for SQLite file
- Deploy docs in README
**Deliverable:** Live URL, `APP_TOKEN` set via Fly secrets.
**Depends on:** Phase 4
**Status:** pending
