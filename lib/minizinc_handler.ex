defmodule MinizincHandler do
  @moduledoc """
    Behaviour, default implementations and helpers for solution handlers.
  """

  import MinizincResults

  @callback handle_solution(
              solution :: map,
              statistics:: map,
              timestamp :: DateTime.t(),
              solution_count :: integer)
            :: {:ok, term} | :stop | {:stop, any()}

  @callback handle_final(
              status :: atom,
              last_solution :: map,
              solver_stats :: map,
              fzn_stats :: map)
            :: :ok | {:ok, any()}

  @callback handle_minizinc_error(mzn_error :: any) :: any

  ## Provide stubs for MinizincHandler behaviour
  defmacro __using__(_) do
    quote do
      @behaviour MinizincHandler
      def handle_solution(_sol, _stats, _ts, _count) do :ok end
      def handle_final(_status, _last_sol, _solver_stats, _fzn_stats) do :ok end
      def handle_minizinc_error(_error) do :ok end
      defoverridable MinizincHandler
    end
  end

  @doc """
    Helper to call handler callbacks uniformly.
    The solution handler can be either a function, or a callback module.
  """
  ## Solution handler as a function
  def handle_solver_event(event, results, solution_handler) when is_function(solution_handler) do
    solution_handler.(event, results)
  end

  ## Solution handler as a callback
  def handle_solver_event(:solution, results, solution_handler) do
    results_rec(solution_data: data, mzn_stats: stats, timestamp: ts, solution_count: count) = results
    solution_handler.handle_solution(data, stats, ts, count)
  end

  def handle_solver_event(:final, results, solution_handler) do
    results_rec(
      status: status, solution_data: last_solution,
      solver_stats: solver_stats, fzn_stats: fzn_stats) = results
    solution_handler.handle_final(status, last_solution, solver_stats, fzn_stats)
  end

  def handle_solver_event(:minizinc_error, results, solution_handler) do
    solution_handler.handle_minizinc_error(results_rec(results, :minizinc_output))
  end


end

defmodule MinizincHandler.DefaultAsync do
  require Logger
  use MinizincHandler

  def handle_solution(data, _stats, _timestamp, count) do
    Logger.info "Solution # #{count}: #{inspect data}"
  end

  def handle_final(status, last_solution, solver_stats, _fzn_stats) do
    Logger.info "Solution status: #{status}"
    Logger.info "Last solution: #{inspect last_solution}"
    Logger.info "Solver stats: #{inspect solver_stats}"
  end

  def handle_minizinc_error(error) do
    Logger.info "Minizinc error: #{error}"
  end
end

defmodule MinizincHandler.DefaultSync do
  require Logger
  use MinizincHandler

  def handle_solution(data, _stats, _timestamp, _count) do
    {:solution, data}
  end

  def handle_final(status, _last_solution, solver_stats, _fzn_stats) do
    {:solver_stats, {status, solver_stats}}
  end

  def handle_minizinc_error(error) do
    {:error, error}
  end
end

