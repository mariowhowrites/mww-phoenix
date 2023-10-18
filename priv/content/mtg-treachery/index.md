title: Building a Real-Time MTG Assistant with Phoenix/LiveView
published: true
description: "Because why spend an hour cutting out cards when you can spend two months building an app instead?"
category: Technical
tags:
 - elixir
 - liveview
 - mtg
image: /images/castle.avif
date: "2023-10-06"
slug: mtg-treachery
---G
I regularly play a version of Magic the Gathering called [Treachery](https://www.notion.so/MtgTreachery-Blog-Post-473d0c0e26484edcab975d49ff6f9743?pvs=21), a multiplayer format that’s effectively Mafia meets Commander. 

The primary way in which this format is unique is that every player is assigned one of four roles, each with a unique win condition and tied to a powerful, one-time ability.

- Leaders want to survive the Assassin and Traitors to be the last faction standing,
- Guardians are allied to the Leader, and win or lose with them,
- Assassins oppose the Leader, and win if the Leader dies,
- Traitors must be the last player standing, which implies killing the Assassins before the Leader/Guardians

When the game starts, each player receives a face-down Identity card describing their role and their unique in-game power, as well as what they must do to activate this power (the unveil cost). For example, one card might read:

**Identity** The Ambitious Queen

**Role** Assassin

**Unveil Cost** Pay 2 life, exile a card from your hand

**Ability** When The Ambitious Queen is unveiled, counter target spell.

In order to play the game, you need Identity cards. According to the official website, the most common way to do this is to print out the physical cards and sleeve them up like normal MTG cards. As someone with a lifelong allergy to arts and crafts, the idea of crafting 50+ cards was daunting enough inspire a search for alternate solutions. 

My crippling fear of fine motor skills notwithstanding, even if you do have the physical cards, setup before and between games often isn’t trivial. 

Identity cards, in addition to being organized by role, are also grouped according to one of three “rarities”: Uncommon, Rare and Mythic. These rarities differ from one another in the complexity of their abilities, with higher rarity denoting higher complexity. Combine this with the fact that the number of Guardians, Assassins and Traitors in the game changes depending on player count, alongside the need for the game host to select Identity cards at random from amongst all possible selections given player count and rarity, and you can see where things start to get difficult.

This particular aspect of the experience seemed ripe for digitization. There was an existing webapp, but the UX lacked a couple features I thought important. I had been learning how to use Elixir/Phoenix to build realtime applications, and this seemed like a perfect venue to apply that learning.

You can find the [code for this project on GitHub](https://github.com/mariowhowrites/mtg-treachery-identity-picker), but I’d like to walk through the application code and go over some inflection points.

## Walkthrough

## Overview

At the highest level, the app is divided into these main features:

1. Creating lobbies to play Treachery, with configuration options for player count and rarities    
2. Joining lobbies based on game codes
3. Assigning each player an identity when the game starts
4. Allowing players to privately peek at, or publicly reveal, their identity   
5. Tracking life total changes as players gain/lose life totals

### Enabling Multiplayer

From a high level, enabling real-time multiplayer involves using two libraries provided to us out-of-the-box in a Phoenix application:

1. LiveView enables realtime connections between client and server using WebSockets
2. PubSub enables realtime connections between processes on our server, allowing our LiveViews to subscribe to relevant data changes as they happen

Perhaps my first misconception when starting my realtime journey with Phoenix was assuming that LiveView was responsible for both parts of this equation.

In reality, LiveView is solely responsible for managing the connection between your server and each individual client who’s connected to it. At the risk of drastically oversimplifying things, one LiveView instance corresponds to one individual “mini-server”, spun up on our backend exclusively to track the relevant data for a single connected client. When our application writes a change — creating a game, adding a new player, etc — we are responsible for how and when our client LiveViews become aware of that change. 

I’ve been using a pattern I’ve seen used in other LiveView projects, and so far it seems to work out fairly well. 

This pattern takes advantage of the fact that a basic PubSub server is set up for you in Phoenix by default. In your Application’s `start/2` fn, an instance of `Phoenix.PubSub` is added with the alias `{YourAppNamespace}.PubSub`. In my case, this was `MtgTreachery.PubSub`.

The pattern is this:

1. Decide how data will be shared throughout your application. In my case, I had two primary data models: Games and Players. My first pass of the PubSub had each client sign up for multiple subscriptions:
    1. one per game,
    2. one for each player
    
    Eventually, I decided that, since each player must be attached to a game, it made more sense to instead only have one subscription — the game subscription — and allow clients to derive player information through the relevant game struct.
    
2. Add relevant broadcast/subscribe methods to your model modules. These are effectively syntactic sugar for your PubSub methods:
    
```elixir
defmodule MtgTreachery.Multiplayer.Game do
  alias Phoenix.PubSub

  @pubsub MtgTreachery.PubSub

  def subscribe_game(game_id) do
    PubSub.subscribe(@pubsub, "game:#{game_id}")
  end

  def broadcast_game(game_id) do
    PubSub.broadcast(@pubsub, "game:#{game_id}", {:game, game_id})
  end

  def broadcast_game_start(game_id) do
    PubSub.broadcast(@pubsub, "game:#{game_id}", {:game_start})
  end

  def subscribe_life_totals(game_id) do
    PubSub.subscribe(@pubsub, "life_totals:#{game_id}")
  end

  def broadcast_life_totals(game_id, life_totals) do
    PubSub.broadcast(@pubsub, "life_totals:#{game_id}", {:life_totals, life_totals})
  end
end
```
    
  Another thing to note here is that I opted to broadcast only the game ID, as opposed to the entire game struct. 
    

Instead of sending all relevant game data through the PubSub system, under this approach each LiveView is responsible for fetching its own game data from the database. 

For a while, I considered sending all data through the PubSub system, as in theory this could cut down on the amount of DB calls that must be made for each state change. However, I eventually decided against this approach to promote a looser coupling between publishers and subscribers. When sending just the game ID over the wire, the publisher doesn’t need to know what specific state update each subscriber is interested in. 

### Tracking Life Totals

A quick caveat to lead this section: adding the ability to track life totals to the application was highly instructive in at least two regards. From a technical standpoint, building a distributed architecture to manage life totals in realtime without excessive DB writes was easily the most backend-intensive part of this project. However, what I learned from a UX perspective was arguably more important: if user experience shows you that a feature isn’t necessary, it probably isn’t necessary.

In this case, I was intent on building life total tracking into my website, with the intention that people would use this feature while accessing the site on their phones to manage their life totals individually. In reality, when sitting around the same table, it’s typically easier to track life totals with one shared life total app running on a tablet or phone in the center of the table. Combine this with my natural aversion to fiddling around on my phone, and the life totals feature ended up being a concept I spent a long time working on to little actual benefit in UX. 

Bottom line: as much as possible, make sure the feature you’re building is worth the effort you spend to build it. If the data is telling you to go in a different direction, follow it. 

This being said, some more info on the technical tradeoffs:

I went into the design for this feature with two main goals:

1. Life total updates should be available to all players as soon as possible, and 
2. Life total updates should have a minimal impact on system performance, even at hundreds/thousands of updates per game

Balancing the need for real-time updates with the desire for minimal system impact led to some interesting decision points. 

The most straightforward solution was to write every life total update to the DB directly, but that felt like it could run afoul of goal #2 quite easily. With potentially thousands of life changes occurring per game, writing to the DB for each change then fetching from the DB in each LiveView in response to each new broadcast would result in tons of stress on the data layer.

Without writing to the DB with each update, I saw two main options:

1. Combine updates into “batches”, and only commit each batch to the DB once a batch is complete. For example, if someone loses 10 life as the result of an attack, 
2. Store life total updates in a different data layer, one that could more easily handle real time updates.

Speaking honestly, were I to know in advance how difficult option 2 would be, I would have gone with the other goal, but it is what it is.

Tracking life totals using a more realtime data layer seemed like the perfect place to test out the GenServer state architecture outlined in Sasa Juric’s [Elixir in Action](https://www.manning.com/books/elixir-in-action). The idea is to utilize the GenServer behavior included in Elixir by default to create one “source of truth” per game. Each client LiveView for a given game then subscribes to updates from this “source of truth” and makes any necessary UI changes.

Client LiveViews interact with these life total servers in two ways:

1. Receive updates through PubSub system
2. Send updates via LifeTotals.Cache, which fetches life total servers by ID

```elixir
defmodule MtgTreacheryWeb.GameLive.Show do
	def mount(params, session, socket) do
		if connected?(socket) do
      Multiplayer.Game.subscribe_game(game.id)
      Multiplayer.Game.subscribe_life_totals(game.id)
    end

		# ...
	end 

	def handle_info({:life_totals, life_totals}, socket) do
    {:noreply, socket |> assign(:life_totals, life_totals)}
  end
```

```elixir
defmodule MtgTreachery.Multiplayer do
	def create_game(attrs \\ %{}) do
		# ... create game here and assign to `game` var    

    # start life total server for this game
    Cache.server_process(game.id)

    {:ok, game}
  end
end
```

```elixir
defmodule MtgTreachery.LifeTotals.Cache do
  alias MtgTreachery.LifeTotals.Server

  def start_link() do
    IO.puts("Starting life total cache")
    DynamicSupervisor.start_link(name: __MODULE__, strategy: :one_for_one)
  end

  def child_spec(_arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :supervisor
    }
  end

  def server_process(game_id, players \\ %{}) do
    case existing_process(game_id) do
      nil ->
        new_process(game_id)

      pid ->
        pid
    end
  end

  defp existing_process(game_id) do
    Server.whereis(game_id)
  end

  defp new_process(game_id) do
    case DynamicSupervisor.start_child(__MODULE__, {Server, game_id}) do
      {:ok, pid} ->
        pid
      {:error, {:already_started, pid}} ->
        pid
    end
  end
end
```

Let’s walk through the life total server lifecycle quickly:

1. When the application is started, a supervisor is started to watch life total servers.
2. the `Cache` module
3. added to application children in `application.ex`
4. Life total server is created automatically if one does not exist when 
5. When life totals are updated, call `LifeTotals.lose_life` or `LifeTotals.gain_life` with game_id and player_id
6. LifeTotals context fetches appropriate server from cache and updates it using methods from `LifeTotals.Server` module
7. LiveView → LifeTotals → Cache → Server → PubSub → LiveView
8. If game is older than 24 hours old, life total servers are shutdown as part of cleanup script

I ran into some interesting issues when deploying this feature to production. When testing on my local server with multiple devices, each device had no problem connecting to the same life total server. When deploying live on Fly.io, however, life total servers would regularly desync between browsers and even between sessions. Hitting “refresh” on the browser page would sometimes yield all life totals, sometimes none, and often some combination in between.

The steps I went through to debug this issue were numerous enough to warrant an article to themselves, but ultimately the answer proved simpler than I had imagined. The breakthrough happened when I noticed that there were only ever, at most, two different versions of the same life total history happening, and that they were always mutually exclusive.

Let’s say, for example, there were 5 players in a lobby, Players 1 through 5. Hitting refresh once might show me the life totals for Players 1 and 3, but not 2, 4 or 5. Refreshing again would show me 2, 4, and 5, but not 1 or 3.

What I ultimately came to realize was that the default configuration of Phoenix on [Fly.io](http://Fly.io) (and, I believe, all apps on the Fly platform) is to deploy two application nodes. This is a sensible default that makes scaling more straightforward, but it does involve some architecture changes that I had not planned around when shipping the first few iterations.

Namely, I had originally been using the `ProcessRegistry` module to store PIDs for life total servers. To find the solution I turned once again to Elixir in Action, which recommends using the `:global` module to registers processes in a way such that they are available to all nodes in your application. 

On the frontend, I used [Alpine](https://alpinejs.dev/) to show visual feedback to players about how much life they had gained or lost in the last few seconds.

There were two main tricks to getting this component to work:

1. I had a `delta` variable responsible for tracking someone’s life total changes over time, but I needed to find a way to reset this number to 0 after the debounce window had passed. I also ideally wanted to avoid bringing in additional third-party JS libraries to handle a one-off frontend need.

My first attempt involved attaching two separate `@click` handlers to the element, one to change the delta immediately and one to reset it on a debounced timer. However, with Alpine not supporting multiple `@click` handlers on one element, this did not work.

I eventually settled on a Alpine-powered custom event. By calling `$dispatch.('delta')` within the component and catching the event with `@delta.debounce.5000ms` in the parent component, I s deas to make this feature more robust would include some sort of interaction between the life total servers and the DB representation of a game. At the moment, life totals are kept entirely on the life total servers, meaning that if a life total server crashes for whatever reason, life totals will not persist when the supervisor reboots the server.
2. In cases where AlpineJS and LiveView differ re: the DOM, LiveView will always take precedence unless you specify otherwise. Using `phx-update="ignore"` on a given DOM element allows you to carve out sections of HTML that won’t be updated when your LiveView changes, permitting AlpineJS to consistently display delta values. 

```html
<div
  x-data="{ delta: 0 }"
  @delta.debounce.5000ms="delta = 0"
  class="flex flex-col relative h-full w-full"
>
  <button
    @click="delta = delta + 1; navigator.vibrate(50); $dispatch('delta')"
    phx-click="gain_life"
    phx-value-player-id={@current_player.id}
    class="px-2 py-1 bg-green-500 text-white h-1/2"
  >
    <span class="hidden">
      +
    </span>
    <span
      x-text="delta"
      x-show="delta > 0"
      phx-update="ignore"
      id="positive-delta-indicator"
    >
    </span>
  </button>
  <div class="absolute w-full h-full flex items-center justify-center text-white font-bold text-4xl pointer-events-none">
    <%= @life_totals[@current_player.id] %>
  </div>
  <button
    @click="delta = delta - 1; navigator.vibrate(50); $dispatch('delta')"
    phx-click="lose_life"
    phx-value-player-id={@current_player.id}
    class="px-2 py-1  bg-red-700 text-white h-1/2"
  >
    <span class="hidden">
      -
    </span>
    <span
      x-text="delta"
      x-show="delta < 0"
      phx-update="ignore"
      id="negative-delta-indicator"
    >
    </span>
  </button>
</div>
```

The actual picking of identities was one of the most straightforward parts of the project. I created two JSON files, one to hold all identity data and the other to hold configuration data matching role counts to player counts. 

The `IdentityPicker` module uses this information to match players with appropriate identities:

```elixir
defmodule MtgTreachery.Multiplayer.IdentityPicker do
  def pick_identities(player_count, rarities) do
    identities = MtgTreachery.Multiplayer.list_identities()

    config = get_config(player_count)

    pick_identities_for_config(identities, config, rarities)
  end

  @doc """
  Given a player count, returns a map with :player_count => {:role, :number},
  where :role is a MTG Treachery role (Leader, Guardian, etc)
  and :number is the number of that role that should be in the game.
  """
  def get_config(player_count) do
    Application.app_dir(:mtg_treachery, "priv/configs/role-distributions.json")
    |> File.read!()
    |> Jason.decode!()
    |> Map.get(Integer.to_string(player_count))
  end

  @doc """
  Given a config of the type returned from `get_config` (:player_count => {:role, :number}),
  as well as a list of all possible identities and the desired rarity,
  pulls identities from the list of all identities based on the criteria in the config.
  """
  defp pick_identities_for_config(identities, config, rarities) do
    config
    |> Enum.flat_map(&pick_identities(&1, identities, rarities))
  end

  defp pick_identities({role, count}, identities, rarities) do
    identities
    |> Enum.filter(&is_valid_identity(&1, role, rarities))
    |> Enum.take_random(count)
  end

  # does the identity have the correct role and rarity?
  defp is_valid_identity(identity, role, rarities) do
    identity.role == role and
      Enum.member?(rarities, String.downcase(identity.rarity))
  end
end
```