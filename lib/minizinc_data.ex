defmodule MinizincData do
  @moduledoc false
  ## Merges list of dzn files and/or maps and writes the result to a (temporary by default) target file.
  ## TODO: validate content?
  def make_dzn(data, target \\ nil)

  def make_dzn([], _) do
    {:ok, ""}
  end

  def make_dzn(data, nil) do
    make_dzn(data, String.trim(to_string(:os.cmd('mktemp'))))
  end


  def make_dzn(data, target) when is_list(data) do
    target_file = String.replace_suffix(target, ".dzn", "") <> ".dzn"
    for d <- data do
      {:ok, content} = read_dzn(d)
      File.write(target_file, content <> "\n", [:append])
    end
    {:ok, target_file}
  end

  def make_dzn(data, target) when is_binary(data) or is_map(data) do
    make_dzn([data], target)
  end


  # Dzn as filename
  def read_dzn(data) when is_binary(data) do
    {:ok, _dzn} = File.read(data)
  end

  # Dzn as dict/map
  def read_dzn(data) when is_map(data) do
    {:ok, map_to_dzn(data)}
  end

  # Convert map to the list of strings in .dzn format
  def map_to_dzn(data) do
    Enum.reduce(data, "",
      fn({k, v}, acc) ->
        "#{k} = #{elixir_to_dzn(v)};\n" <> acc
      end)
  end

  def output_to_elixir(data_dict) do
    Enum.reduce(data_dict, %{},
      fn({k, v}, acc) ->
        Map.put(acc, k, mzn_to_elixir(v))
      end)
  end

  def mzn_to_elixir(el) when is_map(el) do
    s = el["set"]
    if s == [], do: MapSet.new(s), else: MapSet.new(hd(s))
  end

  def mzn_to_elixir(el) do
    el
  end

  # Convert element to .dzn string
  # TODO: Support 0-base for arrays
  def elixir_to_dzn(el) when is_list(el) do
    dims = dimensions(el)
    if dims do
      "array#{length(dims)}d(" <>
      Enum.reduce(dims, "",
        fn d, acc ->
          "1..#{d}," <> acc
        end)
      <>"[#{Enum.join(List.flatten(el), ",")}]" <> ")"

    else
      throw {:irregular_array, el}
    end
  end

  def elixir_to_dzn(el) do
    el
  end

  ## Dimensions of a nested list of lists.
  ## The lengths of sublists within a dimension have to be the same,
  ## for instance, think of a proper matrix, where each row has the same number of columns etc.


  def dimensions(array) when is_list(array) do
    dimensions(array, [])
  end

  def dimensions(_el) do
    []
  end

  def dimensions([], _acc) do
    []
  end

  def dimensions(array, acc) when is_list(array) do
    [head | tail] = array
    Enum.all?(tail, fn t -> dimensions(t) == dimensions(head) end) and
    dimensions(head, [length(array) | acc])
  end

  def dimensions(_el, acc) do
    Enum.reverse(acc)
  end

end
