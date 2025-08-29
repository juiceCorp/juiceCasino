# Overview

This repo provides tools for a fully remote and secure casino server & database for Computer Craft.

# Features

## Security
- All requests to the central database verified via a HMAC key.
- Account creation, with balance, username, and password tied to said account.
- Session locking and time outs via a random 32 char token generated upon login.
- Active, READ/WRITE commands as a game is played to ensure fair play.
- Client is locked down to ensure game security.
## Content
- Roulette
- BlackJack
- Database is light-weight & stored on a single JSON file on the computer (Created automatically)
- Sign in page.

  
