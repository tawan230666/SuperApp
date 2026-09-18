# Shared API contracts

Runtime Zod schemas are the boundary for browser/mobile input. TypeScript types are generated from the schemas; services must parse untrusted JSON before domain logic. Money uses integer minor units. This package contains no credentials and no persistence.
