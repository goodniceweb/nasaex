# Nasaex

NASA Fuel Calculator — a Phoenix LiveView application that calculates the fuel required for interplanetary missions.

## Original Task

I won't tell you as I'm not sure if it's private or public info. Though, you can read the code and guess / reverse engineer.

## Assumptions

- **Reverse-order fuel calculation**: fuel for earlier steps must account for the weight of fuel needed for all subsequent steps. This is the key insight — the path is processed in reverse to accumulate total mass correctly.
- **Recursive fuel-on-fuel**: fuel itself adds weight, requiring more fuel. This is computed recursively until the additional fuel needed floors to zero.
- **Floor rounding**: both formulas use `floor()` — fractional kg of fuel are not counted. This means very light spacecraft (< ~82 kg) may require 0 kg of fuel for simple paths.
- **Integer mass only**: spacecraft mass must be a positive whole number (kg).
- **First step can be either launch or land**: a spacecraft may already be in orbit (land first) or on a surface (launch first). The UI and backend both support this.
- **Path can end with launch**: a spacecraft may go to orbit without landing — this is valid.
- **Launch must depart from where you last landed**: if you land on Moon, you must launch from Moon next. The UI enforces this automatically.
- **No database**: all state is in-memory per LiveView session. Celestial body data is loaded from a YAML file at compile time.
- **Decimal arithmetic**: gravity values and fuel calculations use the `Decimal` library for precision, anticipating future celestial bodies with more precise gravity values.
- **YAML as data source**: celestial bodies (Earth, Moon, Mars) are defined in `priv/data/celestial_bodies.yml`. The app will not start without this file.
- **0 kg fuel is a valid result**: per the formulas, very small masses can result in 0 fuel. This is by spec, not a bug.

## How to run locally

Prerequisites: Elixir 1.19+, Erlang/OTP 28+, Node.js (for asset building).

```bash
# Install dependencies
mix setup

# Start the Phoenix server
mix phx.server

# Or start inside IEx
iex -S mix phx.server
```

Visit [localhost:4000](http://localhost:4000) in your browser.

No database or PostgreSQL is needed — the app is fully in-memory.

To run tests:

```bash
mix test
```

## Room for improvements

- **Better UX for tiny spacecraft**: instead of showing 0 kg fuel required (which is technically correct per spec), display a friendlier message like "We don't support sending too small spacecrafts to space".
- **Revisit the math**: according to the current formulas, sending a 100 kg spacecraft from Earth to orbit requires only 8 kg of fuel. That seems unrealistically low and may warrant reviewing the formula constants.
- **Better UI**: space-themed design, dark theme by default, slider for spacecraft mass input, visual/interactive path builder with drag-and-drop.
- **Database + admin area**: add a database so that new celestial bodies can be added through an admin interface, rather than editing YAML and redeploying.
- **Analytics**: track popular mission paths, average spacecraft masses, and usage patterns.
- **AI agent**: natural language interface where users can describe a mission in plain English (e.g., "Send a 28,000 kg ship from Earth to Moon and back") and have the path auto-built.

## License

MIT — see [LICENSE](LICENSE) for details.
