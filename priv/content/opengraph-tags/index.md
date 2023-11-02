title: Setting Dynamic OpenGraph Tags with Phoenix/LiveView
published: true
description: "Using Elixir's Plug and a GenServer cache to maxmize discoverability with OpenGraph and Twitter tags"
category: Technical
tags:
 - elixir
 - liveview
 - opengraph
image: /images/plateau.jpg
date: "2023-11-01"
slug: opengraph-tags
---

# Building Dynamic OpenGraph Tags with Phoenix LiveView

In the spirit of writing more about my development process, I wrote this article alongside building a new feature for my Phoenix-backed blog. I made a deliberate effort to keep the feature small in scope so I could track the various iterations without writing a small novel. Fortunately, since I am building a blog without using any of the dozens of excellent existing CMSs, these kinds of small-but-important tasks abound. 

In this case, my task was to add OpenGraph tags to each page to maximize discoverability. For the uninitiated, OpenGraph tags are `meta` tags that you can include in your HTML’s `head` element to share information about the page’s content with popular social media sites. 

Because this data is used on most social media platforms to summarize links to your website, this information is oftentimes the first point of contact many people will have with your content. This pushed the feature from a “nice-to-have” priority to “need-it-yesterday”, so let’s get started!

When planning out features in writing, I tend to go by three steps:

1. Challenge
2. Solution
3. Implementation

Edits for clarity aside, I’ve left that structure intact for this article. It may seem self-evident, almost banal, to write outlines in this format, but I feel as if most of the mistakes I’ve made in engineering have come from not fleshing out one of these three concepts in enough detail. You can’t properly think about a solution until you fully understand what you’re trying to solve, and you can’t make a robust implementation until you’ve thought carefully about the right solution. It can be tempting to short-circuit this process by starting to code as soon as you’ve identified a problem, but this adds more development time than it saves in the long run.

## Challenge

SEO information needs to be set on a per-page basis, but LiveView (to my current knowledge) lacks primitives to set per-page head settings dynamically There’s a special exception for the `title` tag, which makes sense as the page title is displayed as the tab name in most modern browsers and frequently needs to change. 

What we need is a clear means of setting relevant SEO information (OpenGraph and Twitter tags) for each page. This information is primarily used when sharing information on social media, so we need to ensure this information is available as soon as possible, rather than waiting until the page is loaded to fetch this data.

This will likely mean a solution outside of the scope of LiveView, since LiveView communication happens primarily through a web socket, which only initiates a connection after the initial response has already been sent and the webpage has begun loading.

## Solution

At a most basic level, here’s what needs to be done:

We have access to blog information through a cache, by calling functions like `Cache.get(article_slug)`. These cache functions return Elixir maps, which we need to transform into relevant OpenGraph tags.

When converting data between two mediums that are largely dissimilar, it often helps to create an intermediate representation of data. In this case, our data “pipeline” could look something like:

Elixir map → List of HTML tags to render → HTML tags

This lets our HTML markup stay fairly logic-free. For each element in our list, render the tag:

```html
<%= for {tag, value} <- @meta_tags do %>
	<meta property={tag} content={value} />
<% end %>
```

So we know we’ll need to write the logic to convert a blog post into a list with tag information.  We’ll decide exactly what tags we need and in what format during the implementation section. For now, though, a more pressing question: when do we need to set this information?

This information will need to be accessible before the page is rendered. We should parse out headers when we fetch the article and put them into the assigns at that point.

I believe the answer has to do with `live_session`, and creating multiple live sessions to trigger regular page navigation. This should allow us to get some more flexibility around what layout we use and what’s stored in there.

First off, let’s consider what tags we want to support as a minimum case.

- og:title
- og:description
- og:image
- og:url
- twitter:card
- twitter:site
- twitter:creator

Right now, setting meta tags per-route should be easy because we have only two pages. However, the idea of having to carve out separate live_sessions for something that should realistically change from page to page is… strange. I want to think about how this could be improved, but for now let’s focus on getting *********something********* working, and refine our solution once we have one.

## Implementation

UItimately, we want to add `meta` HTML tags to the `head` element of our document. Each element has a `name` or `property` tag, depending on whether it’s used for OpenGraph or for Twitter tags. Here are some example values for the home page:

- og:title - “mariovega.dev”
- og:description - “a website with words on it”
- og:image - latest blog post image?
- og:url - “mariovega.dev”
- twitter:card - “large_summary”
- twitter:creator - “@mariowhowrites”

And for the article page:

- og:title - article.title
- og:description - article.description
- og:image - Article.desktop_image(article)
- og:url - Article.full_url(article)
- twitter:card -  “large_summary”
- twitter:creator - “@mariowhowrites”

Ok, so looking at this, we need the following new functions:

- Article.desktop_image(article): string
- Article.full_url(article): string

First implementation:

```elixir
defmodule MwwPhoenix.Blog.Article do
  # ..

  defp site_hostname() do
    Application.get_env(:mww_phoenix, MwwPhoenixWeb.Endpoint)[:url][:host]
  end

  def full_image_url(article) do
    "https://#{site_hostname()}#{article.image}"
  end

  def build_meta_tags(article) do
    %{
      "og:title" => article.title,
      "og:description" => article.description,
      "og:image" => desktop_image_url(article),
      "og:url" => full_url(article),
      "twitter:card" => "summary_large_image",
      "twitter:creator" => "@mariowhowrites"
    }
  end

  def desktop_image_url(article) do
    "https://#{site_hostname()}/images/responsive/desktop/#{Path.basename(article.image)}"
  end

  def mobile_image_url(article) do
    "https://#{site_hostname()}/images/responsive/mobile/#{Path.basename(article.image)}"
  end

  def full_url(article) do
    "https://#{site_hostname()}/articles/#{article.slug}"
  end
end
```

This makes meta tags based on article data. Next step is to push this data as far up the response chain as possible, as this data needs to exist when the page is first rendered to be useful at all from an SEO perspective. Let’s create a `show_root` layout file that will handle our SEO tags for a given article, and use that here:

```elixir
defmodule MwwPhoenixWeb.Router do
	# ...

	scope "/", MwwPhoenixWeb do
    pipe_through :browser

    live "/", ArticleLive.Index, :index

    get "/feed", RssController, :all

    live_session :show, root_layout: {MwwPhoenixWeb.Layouts, :show_root} do
      pipe_through [:assign_meta_tags]
      live "/articles/:slug", ArticleLive.Show, :show
    end
  end

  def assign_meta_tags(conn, _opts) do
    article = Cache.get(conn.params["slug"])

    assign(conn, :meta_tags, Article.build_meta_tags(article))
  end
end
```

Next, let’s actually make a `show_root` layout, and make sure to use our new `meta_tags` assign in it:

```html
<!DOCTYPE html>
<html lang="en" style="scrollbar-gutter: stable;">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="csrf-token" content={get_csrf_token()} />
    <.live_title suffix=" · mariovega.dev">
      <%= assigns[:page_title] || "MwwPhoenix" %>
    </.live_title>
		<%!-- add meta tags for SEO accessibility --%>
    <%= for {tag, value} <- @conn.assigns[:meta_tags] do %>
      <%= if String.contains?(tag, "twitter") do %>
          <meta name={tag} content={value} />
      <% else %>
          <meta property={tag} content={value} />
      <% end %>
    <% end %>
    <link phx-track-static rel="stylesheet" href={~p"/assets/app.css"}>
    <link media="print" onload="this.media = 'all'" rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.8.0/styles/an-old-hope.min.css">
    <script async src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.8.0/highlight.min.js"></script>
    <script defer phx-track-static type="text/javascript" src={~p"/assets/app.js"}></script>
  </head>
  <body class="bg-white antialiased">
    <%= @inner_content %>
  </body>
</html>
```

Having created a `live_session`, I now believe that there’s no need for a `live_session`. Instead, I think we can use one root layout, and write one `add_meta_tags` plug that’ll determine what SEO tags to use and apply them accordingly.

As far as I can think at the moment, the risk of this is that we end up with a “shadow router”, where for each route we also need a corresponding method in the plug. 

I think this is a fine tradeoff, since there’s no way we’ll ever be able to automatically derive this information anyways.

I made a new module under the namespace `Plugs.AssignMetaTags`:

```elixir
defmodule MwwPhoenixWeb.Plugs.AssignMetaTags do
  import Plug.Conn
  alias MwwPhoenix.Blog.{Cache, Article}

  def assign_meta_tags(conn, _opts) do
    {route, _list, _opts} = conn.private.phoenix_live_view

    assign_tags(conn, route)
  end

  defp assign_tags(conn, route) when route == MwwPhoenixWeb.ArticleLive.Show do
    article = Cache.get(conn.params["slug"])

    assign(conn, :meta_tags, Article.build_meta_tags(article))
  end

  defp assign_tags(conn, route) when route == MwwPhoenixWeb.ArticleLive.Index do
    assign(conn, :meta_tags, %{
      "og:title" => "mariovega.dev",
      "og:description" => "A website with words about various subjects",
      "og:url" => "https://mariovega.dev",
      "twitter:card" => "summary",
      "twitter:creator" => "@mariowhowrites"
    })
  end

  # default case, return nothing
  defp assign_tags(conn, _route) do
    assign(conn, :meta_tags, [])
  end
end
```

We get the route name from the connection’s `private` key, then match that in the guard for each iteration of `assign_tags`. This method does feel a tad brittle, as it depends on the structure of the conn’s `private` key staying the same across new versions of LiveView, but it works for the time being and provides a fairly readable structure to the code.

Testing this runs into an issue: because we are no longer partitioning out each route into its own `live_session`, head values do not change as we navigate from page to page since Phoenix no longer knows this is something we need to do.

For example, say we’re reading Article A. If we move to Article B, then look at our page’s HTML, we’ll still see the meta tags for Article A.

I’m actually inclined to believe this is an OK tradeoff for the time being. This is for two reasons:

1. The primary reason to include these meta tags is for better sharing and discovery on social media. Since the crawlers for social media websites only need information from the first page visited (the page being linked to), we should be able to satisfy those requirements if the initial request always produces correct meta tags.
2. Separating each page into new `live_session` instances won’t actually fix any case in which one article links to another. Since we wouldn’t be changing base routes, Phoenix wouldn’t know to rebuild the meta tags and we’d run into the same issue.

The solution as implemented will solve the immediate issue at hand, and I cannot think of an instance in which the way it isn’t optimal will make a difference.

I’m wondering what a better solution might look like. I’m not sure that there is a means of updating meta tags that doesn’t involve a PR into LiveView itself. 

We know that LiveView already contains one example of updating the root template in real time with the `page_title` assign. The question then becomes whether such an exemption should be expanded from a one-variable exemption to an arbitrary exemption allowing developers to register key-value pairs into LiveView. 

Ultimately, I don’t think updating OpenGraph tags in realtime is important enough to warrant such an expansion.