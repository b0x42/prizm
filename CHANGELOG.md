# Changelog

## Unreleased

- Fix a crash when locking the vault (including sleep and screen lock) by using
  the actual index ranges when zeroing sliced organization and vault key buffers.
