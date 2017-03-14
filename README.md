# Diskuto - an embeddable comment system

Discuto is a lightweight embeddable comment system made for integration with vibe.d sites. Its features include:

- Tree structured replies
- No user registration required
- Comments can be edited/deleted by their author for a few minutes
- Supports user voting to keep the best replies at the top
- New messages stay at the top for a while to ensure visibility
- Integrates [antispam](https://github.com/rejectedsoftware/antispam) for spam protection
- Generic backend support (currently support for MongoDB is implemented)
- Dynamic UI for replying, editing and deleting comments with JavaScript enabled
- Minimum functionality also works with JavaScript disabled
- Adjusts to the enclosing page's font family, color and size

[![Build Status](https://travis-ci.org/rejectedsoftware/diskuto.svg?branch=master)](https://travis-ci.org/rejectedsoftware/diskuto)

This is how it looks:

![Screenshot](https://github.com/rejectedsoftware/diskuto/raw/master/screenshot.png)