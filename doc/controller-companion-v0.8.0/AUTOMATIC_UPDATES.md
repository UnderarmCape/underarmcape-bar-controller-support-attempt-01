# Automatic updates

The bridge asynchronously checks the official public GitHub API at startup and every six hours. Requests use HTTPS, an explicit User-Agent, the current GitHub media type/API version, pagination, ETag/`If-None-Match`, and an on-disk last-good cache. Offline and rate-limited starts remain usable and do not generate per-frame errors.

GitHub Latest is the normal update target. Equal semantic versions are compared by release sequence, publication time, tag, and commit. Interactive consoles show U (update), N (this session only), V (notes), and R (Recovery Mode); redirected/noninteractive output never blocks. Controller/gameplay input is untouched.
