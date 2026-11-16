# Ideas and selected scope

Decision: build **Sideband** deeply, then **Pocket Pause** as a second independent app.
Both run on stock firmware, work without our backend, and remain useful at future events.

| Idea | Useful result | Demonstration | Decision |
| --- | --- | --- | --- |
| Sideband social radar | Find people with a complementary ask or offer | Two badges discover a match and exchange a mutual hello | Primary release |
| Pocket Pause | Take a quiet break or run a focus interval | One button starts a calm visual guide | Secondary release |
| Phone audio controller | Control a mic, recorder, or soundboard over BLE | Badge button triggers sound through phone earbuds | Next experiment. Physical BLE and phone compatibility are untested |
| Social voice channels | Talk with a group through phones | Badges act as push-to-talk remotes | Defer. Audio transport, identity, and signaling expand scope |
| Group light instrument | Coordinate visible crowd patterns | A group joins and creates an effect | Defer. Avoid distracting or unexpected flashing |
| Autonomous event helper | Summarize explicit requests and suggest introductions | Helpful suggestions on badge and phone | Defer until real demand and a trustworthy backend exist |
| Gossip game extensions | Build on the platform's creature/program network | Show game state spreading between badges | Research archived. Live 2.4.0 docs exceed the public source snapshot |

## Sideband's growth loop

1. Show a useful ask and offer.
2. Install with a friend and find a complementary match.
3. Exchange a mutual hello.
4. Meet in person.
5. Show the invite QR to the next person.

This is a product hypothesis, not a measured growth claim.
The loop depends on nearby users running the same app, so the first demo starts with two people.
Downloads and installs alone do not establish usefulness.

## Friction budget

- First launch requires no typing, project account, payment, wallet, or phone pairing.
- SELECT starts. D-pad buttons change optional topics.
- Sharing starts off on every launch. One button stops it.
- Topics and badge ID are public to nearby peers while sharing.
- Invite QR points to a public download page, rather than an unpublished store listing.
- Physical badges need a microSD card and a platform badge ID. A new badge gets its ID after its first Wi-Fi hello.

## Tomorrow's useful demo

Use complementary topics on two badges. Turn sharing on. Show the match.
Each person selects the other and sends a hello. Both badges show the mutual result.
Show the invite QR and explain that the badge app has no project-operated backend.
Then disconnect the internet and repeat on real badges when hardware becomes available.

Do not describe emulator networking as a physical radio-range demonstration.
