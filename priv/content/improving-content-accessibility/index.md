title: Improving Content Accessibility on mariovega.dev
published: true
description: Because website performance is sometimes important
category: Technical
tags:
 - phoenix
 - elixir
image: /images/jigsaw.avif
date: "2023-10-25"
slug: improving-content-accessibility
---
I’ve been writing more, which means I’ve spent more time on my own website. I recently converted it from NextJS to Elixir’s Phoenix framework, but the development process wasn’t focused on getting the site to run fast as much as getting it to run at all. 

Since I’m not using any existing content management system, building out features from scratch that I’ve come to expect in more batteries-included frameworks has proven a welcome challenge.

You can find the [GitHub project for my website here](https://github.com/mariowhowrites/mww-phoenix), but in the meantime I’d like to go over some of the changes I made to improve the accessibility of my website + content.

## Caching Article Data with GenServer

For now, I’m saving blog articles on disk, committing new articles as Markdown files under a directory in my site’s `priv` directory.

My original implementation involves reading articles from disk in response to each request. As I/O operations are oftentimes computationally expensive and article data doesn’t change often, caching this data in memory offered an easy route to improve performance.

One of the nice parts about building on Elixir is that implementing this cache didn’t require anything outside of the constructs provided by the language itself.

First, I made a GenServer:

```elixir
defmodule MwwPhoenix.Blog.Cache do
  use GenServer

  alias MwwPhoenix.Blog

  # client fns

  def start_link(_args) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def all() do
    GenServer.call(__MODULE__, {:all})
  end

  def get(slug) do
    GenServer.call(__MODULE__, {:get, slug})
  end

  # server fns
  def init(_state) do
    {:ok, Blog.list_articles()}
  end

  def handle_call({:all}, _caller, articles) do
    {:reply, articles, articles}
  end

  def handle_call({:get, slug}, _caller, articles) do
    article = Enum.find(articles, &(&1.slug == slug))

    {:reply, article, articles}
  end
end
```

When started, this GenServer fetches all articles from disk and saves them into memory. By calling `Cache.all` and `Cache.get`, we save ourselves the need to fetch each blog post from memory and speed up our website considerably. 

Notice that when we start the server using `GenServer.start_link`, we pass a `name` argument set to the name of the current module. This allows us to use `__MODULE__` instead of a PID when calling `GenServer` functions, which in turn allows us to call `Cache.all()` and `Cache.get(slug)` without needing to know the cache’s PID.

The other main step, besides changing the appropriate client-facing code to use `Cache.all` and `Cache.get`, is adding this cache to our application’s child spec:

```elixir
defmodule MwwPhoenix.Application do
  # ...

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      MwwPhoenixWeb.Telemetry,
      # Start the Ecto repository
      MwwPhoenix.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: MwwPhoenix.PubSub},
      # Start Finch
      {Finch, name: MwwPhoenix.Finch},
      # Start the Endpoint (http/https)
      MwwPhoenixWeb.Endpoint,
      # Start a worker by calling: MwwPhoenix.Worker.start_link(arg)
      # {MwwPhoenix.Worker, arg},
      MwwPhoenix.Blog.Cache
    ]

    # ...
  end

	# ... 
end
```

## RSS Feed

The need for an RSS feed wasn’t immediately obvious, but creating an RSS feed of my blog proved useful in more than one capacity.

The primary reason I pursued this goal was an interest in creating a representation of my content separate from its presentation on my website. Conforming my content structure to a separate format helped me get a better grasp of how much information I needed to include in my frontmatter for blog posts. For example, it was during the construction of this feature that the need for a caching system such as the one described above became apparent.

Most of the heavy lifting for this feature was done using a library called XmlBuilder to create an XML string adhering to the RSS format. It was a bit tricky to find a “standard” structure for my RSS feed to take, as each blog RSS I found seemed to organize their content slightly differently, but I settled on a structure that most RSS readers I found could interpret:

```elixir
defmodule MwwPhoenix.Blog.RSS do
  alias MwwPhoenix.Blog

  import XmlBuilder

  @doc """
  Return all articles as RSS.

  Uses the xml_builder library to format blog posts according to the RSS 2.0 specification.
  """
  def all() do
    articles = Blog.list_published_articles()

    xml = document(:rss, %{version: "2.0"}, [
      element(:channel, %{}, [
        element(:title, %{}, "mariovega.dev"),
        element(:link, %{}, "https://mariovega.dev"),
        element(:description, %{}, "mariovega.dev is a blog about software development, magic, and life."),
        element(:language, %{}, "en-us"),
        element(:pubDate, %{}, DateTime.utc_now() |> to_rfc822()),
        element(:lastBuildDate, %{}, DateTime.utc_now() |> to_rfc822()),
        element(:generator, %{}, "Phoenix LiveView"),
        element(:docs, %{}, "https://validator.w3.org/feed/docs/rss2.html"),
        element(:ttl, %{}, 1440),
        articles |> Enum.map(fn article ->
          # we need to add time data to make the date RFC822 compliant
          {:ok, published_date, 0} = DateTime.from_iso8601("#{article.frontmatter["date"]}T13:30:00.0Z")

          element(:item, %{}, [
            element(:title, %{}, article.frontmatter["title"]),
            element(:link, %{}, "https://mariovega.dev/articles/#{Blog.get_slug(article)}"),
            element(:description, %{}, {:cdata, article.content}),
            element(:pubDate, %{}, published_date |> to_rfc822()),
            element(:guid, %{}, "https://mariovega.dev/articles/#{Blog.get_slug(article)}")
          ])
        end)
      ])
    ]) |> generate

    {:ok, xml}
  end

  defp to_rfc822(date) do
    date |> Calendar.strftime("%a, %d %b %Y %H:%M:%S %z")
  end
end
```

RSS uses RFC822 timestamps by default, which includes both date and time information, while my average blog post metadata included only date information. I used the `DateTime.from_iso8601` and picked an arbitrary time (in this case, 1:30PM), welding that to the given date to create a valid DateTime object.

Note also that the content for each article, stored in the `description` property of each individual `item`, is wrapped in a tuple alongside the atom `:cdata`. Without this, XmlBuilder will escape all the HTML in each blog post, turning an otherwise intelligible article into a farrago of gibberish. 

## Optimizing Images

One of the biggest performance issues I ran into was image optimization. In true rookie fashion, my original workflow was A) find a thematic image and B) upload it to my website. In some cases, according to performance tests, the images I was uploading could have been 1% of their actual size with no noticeable changes. 

This challenge had an unusually large range of potential solutions. The one I had been previously most familiar with was Cloudinary, and it’s entirely possible in the future that I might switch back to Cloudinary or another third-party solution.

However, for the moment my philosophy is simple: do the simplest thing that meaningfully automates the process. Where I ended up for now is an ImageMagick integration that I can invoke from within my Phoenix application to convert all images from my `content` directory into an `assets` directory. I used [RespImageLint](https://ausi.github.io/respimagelint/) to settle on image widths for mobile and desktop, then plugged those into my image converter script:

```elixir
defmodule MwwPhoenix.ResponsiveImageGenerator do
  @dimensions [
    mobile: "512",
    desktop: "1024"
  ]

  @moduledoc """
  This module is used to generate responsive images for the website.
  """

  @doc """
  This function is used to generate responsive images for the website.

  Firstly, we want to fetch every image in the priv/content directory.
  Then, we want to generate a responsive image for each image.
  Finally, we want to save the responsive image in the priv/static directory.
  """
  def generate_responsive_image() do
    # fetch all images in the priv/content directory
    old_paths = Path.wildcard("priv/content/**/*.{jpg,jpeg,png,avif,webp}")

    # generate a responsive image for each image
    Enum.each(old_paths, fn old_path ->
      Enum.each(@dimensions, fn {device, width} ->
        image_name = Path.basename(old_path)
        new_path = Application.app_dir(:mww_phoenix, "priv/static/images/responsive/#{device}/#{image_name}")

        run_imagemagick(old_path, new_path, width)
      end)
    end)
  end

  defp run_imagemagick(old_file_path, new_file_path, width) do
    # from https://www.smashingmagazine.com/2015/06/efficient-image-resizing-with-imagemagick/
    System.cmd("convert", [
      old_file_path,
      "-filter",
      "Triangle",
      "-define",
      "filter:support=2",
      "-thumbnail",
      width,
      "-unsharp",
      "0.25x0.25+8+0.065",
      "-dither",
      "None",
      "-posterize",
      "136",
      "-quality",
      "82",
      "-define",
      "jpeg:fancy-upsampling=off",
      "-define",
      "png:compression-filter=5",
      "-define",
      "png:compression-level=9",
      "-define",
      "png:compression-strategy=1",
      "-define",
      "png:exclude-chunk=all",
      "-interlace",
      "none",
      "-colorspace",
      "sRGB",
      "-strip",
      new_file_path
    ])
  end

  def dimensions(), do: @dimensions
end
```

As the code comment suggests, I did not come up with the ImageMagick arguments myself. For now, I am using the defaults suggested in [this Smashing Magazine article](https://www.smashingmagazine.com/2015/06/efficient-image-resizing-with-imagemagick/), though I must admit the images don’t look as crisp as I’d like on desktop. All the same, with these compression settings my images load much faster and my bandwidth thanks me dearly.