# External links

Every link below uses a URI scheme, so BrainFrame treats it as **external**. In
the read-only reader there is no external opener yet, so tapping one should do
**nothing** — no navigation, no error. That is the expected behavior to verify
(plan case F6, step 5).

- Inline web link: [Flutter](https://flutter.dev)
- Another web link: [Dart](https://dart.dev)
- Project site: [BrainFrame](https://brainframe.tech)
- Bare URL: https://brainframe.tech
- Autolink: <https://brainframe.tech>
- Email (mailto): [Email us](mailto:getbrainframe@gmail.com)

For contrast, this **intra-engram** relative link *should* navigate the reader
to the notebook index: [the field notebook index](../index.md) (plan case F6,
step 3).
