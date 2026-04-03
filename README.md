# telegram for Stata: Free Push Notifications and Mobile Alerts

`telegram` is a Stata package that provides a no-nonsense way to send real-time status updates, free push notifications (mobile alerts), and exported graphs from Stata directly to your smartphone (iPhone or Android) or desktop via the Telegram messenger.

Let's be honest: staring at a screen while a massive script runs is terrible. Whether you are monitoring remote server batch jobs or waiting for a bootstrap to finish so you can finally grab a coffee (or pour some wine), this package is a hassle-free alternative to wrestling with SMTP email servers or paying for premium third-party apps.

## Features
* **100% Free Mobile Alerts:** Walk away from your desk. Get notified on iOS, Android, or Desktop the second your script finishes or hits an error.
* **Send Figures & Charts:** Export your Stata `.gph` graphs to `.png` and push them directly to your phone so you can review results from the couch.
* **Easy Setup:** No need to clutter your scripts with global macros. An interactive `telegram setup` routine quietly saves your credentials once.
* **Smart Chunking:** Telegram cuts off messages at 4,096 characters. If your Stata output is overly chatty, `telegram` automatically splits it into multiple texts without mangling your formatting.

## Installation

You can install the latest version directly from SSC:
```stata
net install telegram, from("[https://raw.githubusercontent.com/DObst/stata-telegram/main/](https://raw.githubusercontent.com/DObst/stata-telegram/main/)")
```

## Quick Start

**1. One-Time Setup** Run the interactive setup in Stata to set up your Bot API token and Chat ID.
```stata
telegram setup
```

**2. Send a Text Alert** Use `telegram` or the ultra-short alias `tg`.
```stata
tg "Data cleaning finished. I deserve a coffee."
```

**3. Format with Line Breaks** Use `||` to insert line breaks for highly readable mobile alerts.
```stata
tg "Model 1 Converged || R-squared: 0.85 || Let's pretend that's causal..."
```

**4. Send an Exported Graph** 
```stata
sysuse auto, clear
scatter price mpg
graph export "results.png", as(png) replace
tg "Scatter plot of Price vs. MPG", figure("results.png")
```

## Author & Support
**Daniel Obst** Email: daniel@danielobst.de  
License: MIT