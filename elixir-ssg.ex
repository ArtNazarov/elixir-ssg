defmodule BlogGenerator do
  @moduledoc """
  Static Site Generator main module.
  Coordinates the generation process.
  """

  def main(_args) do
    start_time = System.monotonic_time()

    # Start supervisor
    {:ok, _pid} = Supervisor.start_link([], strategy: :one_for_one)

    # Create actors in pipeline order: Writer -> Processor -> Reader
    writer = spawn(WriterActorModule, :init, [])
    processor = spawn(ProcessingActorModule, :init, [])
    reader = spawn(ReaderActorModule, :init, [])

    # Tell processor about writer PID
    send(processor, {:set_writer, writer})

    # Get all unique page IDs from data files
    page_ids = discover_page_ids_from_data()
    total_pages = length(page_ids)
    # IO.puts("Found #{total_pages} pages to process")

    # Send processing messages and wait for completion
    Enum.each(page_ids, fn page_id ->
      send(reader, {:process_page, page_id, processor, self()})
    end)

    # Wait for all pages to be processed
    wait_for_completion(total_pages)

    # Calculate and print execution time
    end_time = System.monotonic_time()
    execution_time = System.convert_time_unit(end_time - start_time, :native, :millisecond)
    IO.puts("Total execution time: #{execution_time} ms")
  end

  defp wait_for_completion(0), do: :ok
  defp wait_for_completion(count) do
    receive do
      {:page_processed, _page_id} -> wait_for_completion(count - 1)
    after
      30_000 -> raise "Timeout waiting for pages to process"
    end
  end

  # Discovers all page IDs from files in ./data directory
  defp discover_page_ids_from_data() do
    Path.wildcard("./data/*-*.txt")
    |> Enum.map(fn path ->
      Path.basename(path)
      |> String.split("-")
      |> hd()
    end)
    |> Enum.uniq()
  end
end

defmodule ReaderActorModule do
  @moduledoc """
  Reads page templates and attributes.
  """

  def init() do
    loop(%{})
  end

  defp loop(state) do
    receive do
      {:process_page, page_id, processor, main_pid} ->
        # IO.puts("\nProcessing page: #{page_id}")

        template_name = get_template_name(page_id)
        template = read_template(template_name)
        attributes = read_page_attributes(page_id)

        # IO.puts("Attributes for #{page_id}:")
        # Enum.each(attributes, fn {key, value} ->
          # IO.puts("  #{key}: #{String.slice(value, 0..50) |> String.trim()}...")
        # end)

        send(processor, {:process, page_id, template, attributes, main_pid})
        loop(state)

      _ -> loop(state)
    end
  end

  defp get_template_name(page_id) do
    template_file = "./data/#{page_id}-template.txt"
    case File.read(template_file) do
      {:ok, name} -> String.trim(name)
      _ -> "page"
    end
  end

  defp read_template(template_name) do
    template_path = "./templates/#{template_name}.tpl"
    case File.read(template_path) do
      {:ok, content} -> content
      _ -> raise "Template not found: #{template_path}"
    end
  end

  defp read_page_attributes(page_id) do
    Path.wildcard("./data/#{page_id}-*.txt")
    |> Enum.reject(&String.ends_with?(&1, "template.txt"))
    |> Enum.reduce(%{}, fn path, acc ->
      attribute_name =
        Path.basename(path, ".txt")
        |> String.replace("#{page_id}-", "")
      value = path |> File.read!() |> String.trim()
      Map.put(acc, attribute_name, value)
    end)
  end
end

defmodule ProcessingActorModule do
  @moduledoc """
  Processes templates by replacing placeholders with attribute values.
  """

  def init() do
    loop(nil)
  end

  defp loop(writer_pid) do
    receive do
      {:set_writer, pid} -> loop(pid)

      {:process, page_id, template, attributes, main_pid} ->
        # IO.puts("Generating HTML for: #{page_id}")
        html = replace_placeholders(template, attributes)
        if writer_pid, do: send(writer_pid, {:write, page_id, html, main_pid})
        loop(writer_pid)

      _ -> loop(writer_pid)
    end
  end

  defp replace_placeholders(template, attributes) do
    Enum.reduce(attributes, template, fn {key, value}, acc ->
      String.replace(acc, "{#{key}}", value)
    end)
  end
end

defmodule WriterActorModule do
  @moduledoc """
  Writes generated HTML to files.
  """

  def init() do
    File.mkdir_p!("./build")
    loop()
  end

  defp loop() do
    receive do
      {:write, page_id, html, main_pid} ->
        # IO.puts("Writing output for: #{page_id}")
        File.write!("./build/#{page_id}.html", html)
        send(main_pid, {:page_processed, page_id})
        loop()

      _ -> loop()
    end
  end
end

# Start the application
BlogGenerator.main([])
