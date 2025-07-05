defmodule MakeFakeData do
  @moduledoc """
  Generates fake data for blog generator:
  - Creates template file ./templates/page.tpl
  - Creates attribute files for N pages in ./data/
  """

  @template_content """
  <html>
    <head>
      <title>{title}</title>
      <meta name="description" content="{description}">
    </head>
    <body>
      <header>
        <h1>{heading}</h1>
        <nav>
          <a href="/">Home</a>
          <a href="/about">About</a>
        </nav>
      </header>
      <main>
        <article>
          {content}
        </article>
      </main>
      <footer>
        <p>Copyright {year} {author}</p>
      </footer>
    </body>
  </html>
  """

  @chars "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" |> String.split("", trim: true)

  def run do
    # Create directories if they don't exist
    File.mkdir_p!("./templates")
    File.mkdir_p!("./data")

    # Create template file
    create_template_file()

    # Create attribute files for N pages
    create_attribute_files(300)

    IO.puts("Fake data generation complete!")
  end

  defp create_template_file do
    File.write!("./templates/page.tpl", @template_content)
    IO.puts("Created template file: ./templates/page.tpl")
  end

  defp create_attribute_files(n) do
    attributes = %{
      "template" => fn _ -> "page" end,  # Default template name
      "title" => fn id -> "Page #{id} - My Awesome Blog" end,
      "description" => fn id -> "This is page #{id} of our amazing blog with fake content" end,
      "heading" => fn id -> "Welcome to Page #{id}" end,
      "content" => fn id ->
        paragraphs = [
          "This is the first paragraph of page #{id}. Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
          "Page #{id} continues with more interesting content. Nullam euismod, nisl eget aliquam ultricies.",
          "Did you know that page #{id} has this special content? Vivamus lacinia odio vitae vestibulum.",
          "Final thoughts on page #{id}. Praesent commodo cursus magna, vel scelerisque nisl consectetur."
        ]
        Enum.map(paragraphs, &"<p>#{&1}</p>") |> Enum.join("\n")
      end,
      "year" => fn _ -> "2023" end,
      "author" => fn _ -> "Fake Author" end
    }

    IO.puts("Generating #{n} pages...")

    batch_size = 50
    total_batches = div(n, batch_size)

    for batch_num <- 1..total_batches do
      start_idx = (batch_num - 1) * batch_size + 1
      end_idx = batch_num * batch_size

      IO.puts("Processing batch #{batch_num}/#{total_batches} (entries #{start_idx}-#{end_idx})")

      for _ <- start_idx..end_idx do
        page_id = generate_random_id(14)
        Enum.each(attributes, fn {attr_name, value_func} ->
          content = value_func.(page_id) |> to_string()
          File.write!("./data/#{page_id}-#{attr_name}.txt", content)
        end)
      end
    end

    IO.puts("Generated #{n} pages with #{map_size(attributes)} attributes each")
  end

  defp generate_random_id(length) do
    1..length
    |> Enum.map(fn _ -> Enum.random(@chars) end)
    |> Enum.join()
  end
end

# Run the script
MakeFakeData.run()
