# Independent pre-merge review

Reviewer: review_1143 sub-agent.

The first review found a blocking apostrophe bypass: apostrophes are valid URI characters, but the initial regex stopped at them. A URL containing `download=it's&token=SECRETTOK` could therefore keep its secret in the logged error.

The correction allows apostrophes in matched URLs. The fixture covers a secret after an apostrophe in both installed handlers; image cases include URLs with and without userinfo. Reviewer rechecked the correction and reported no remaining actionable defects. Ordinary error objects and stack traces remain unchanged.
