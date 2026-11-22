# Discord bot "Bob" (set up later)

`tools/discord_bot.py` reads the FlipForever Discord channels, posts notes and adds check marks through a bot.
It is ready but not connected yet. To connect it:

1. Go to https://discord.com/developers/applications, choose **New Application** and name it **Bob**.
2. On the **Bot** page:
   - Click **Reset Token** and copy the token.
   - Turn on **Message Content Intent**, or the bot can't read message text.
3. On **General Information**, copy the **Application ID**. Put it in this link in place of `APP_ID`, open the link and add Bob to the FlipForever server:
   `https://discord.com/oauth2/authorize?client_id=APP_ID&scope=bot&permissions=199744`
   These are Bob's only rights: view channels, read message history, send messages, add reactions, mention @everyone.
4. Save the token on the developer PC, outside the repository. Never commit or share it.
   ```powershell
   '{"token": "PASTE_TOKEN_HERE"}' | Out-File -Encoding ascii "$env:LOCALAPPDATA\Programs\FlipForever\data\discord_bot.json"
   ```
5. Test it:
   ```powershell
   python tools\discord_bot.py channels
   ```

Once the token file exists, the scheduled runs use the bot:
- **Daily cycle:** runs `check` (reads #bug-reports, #beta-testing, #suggestions and #combat-data).
- **Morning:** runs `suggestions`.
- **Posts:** `post beta-updates <file>` for betas, `post announcements <file>` for stable releases.
- **Check marks:** `react <channel> <message id>`.

Until then, Discord posts are handed over as text to paste.

## Reports in the app
Once the token file exists, the app's Community, Developer page reads players' bug reports and suggestions itself (Get new reports): no Discord reading by hand. The bot needs Read Message History in #combat-data. Without it, Paste reports... works too.
