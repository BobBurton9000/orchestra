Risk describes what could go wrong if a story is implemented incorrectly, incompletely, or without enough safeguards, and why that matters.

- Technical risk: design complexity, hidden implementation constraints, brittle logic, or solutions that are hard to maintain.
- Integration risk: failures at boundaries with APIs, services, queues, files, identity providers, or third-party systems.
- Data risk: incorrect reads or writes, corruption, duplication, loss, leakage, retention mistakes, or bad assumptions about data shape and quality.
- Permission risk: missing, weak, or inconsistent authorisation; privilege escalation; actors seeing or changing data they should not access.
- Abuse and security risk: malicious input, injection, spoofing, replay, automation abuse, unsafe defaults, or missing validation and rate limits.
- Error-handling risk: unclear failure behaviour, silent failures, partial success, poor retries, bad rollback behaviour, or missing user/operator feedback.
- Performance and scale risk: slow paths, excessive resource use, timeouts, contention, or behaviour that degrades badly with volume.
- Reliability and availability risk: the feature may be correct when it works but too fragile to stay up, recover cleanly, or tolerate dependency failures.
- Compatibility risk: changes may break existing clients, contracts, browsers, devices, environments, versions, or legacy workflows that still need to be supported.
- Accessibility and usability risk: the feature may technically work but still fail for users because it is confusing, inaccessible, or too error-prone in real usage.
- Operational risk: poor observability, weak alerting, hard-to-support behaviour, manual recovery steps, or missing run book considerations.
- Deployment and migration risk: unsafe roll-out steps, incompatible schema or contract changes, failed back-fills, or no safe rollback path.
- Dependency and supply-chain risk: delivery or runtime may depend on unstable packages, vendors, external teams, or third-party services outside the team's control.
- Regression and testability risk: important behaviour that is hard to verify, missing coverage for edge cases, or changes likely to break existing flows.
- Delivery and scope risk: unclear boundaries, hidden dependencies, ambiguous ownership, or assumptions that can derail implementation.
- Cost and commercial risk: the change may drive unexpected infrastructure cost, vendor spend, licensing impact, or support overhead.
- Compliance and audit risk: gaps in logging, traceability, consent, policy enforcement, or regulatory handling when the domain requires it.

A good risk entry is concrete. It should name:

- what could go wrong,
- who or what is affected,
- the likely impact,
- and, when useful, the safeguard the team should expect in scope or acceptance criteria.

Example:

- Risk: An operator could trigger the action twice if the request is retried after a timeout.
- Impact: Duplicate downstream records could be created, requiring manual cleanup and causing reporting errors.

Do not list generic risks that apply to every story. Focus on the failure modes that are plausible for this specific change.
