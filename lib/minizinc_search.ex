defmodule MinizincSearch do
  @moduledoc false

  import MinizincUtils

  ## Given a function that 'destroys' parts of values
  ## of the solution's decision variables obtained in a previous iteration;
  ## run the solver on a
  def lns(instance, iterations, destruction_fun) do
    lns(Map.put(instance, :lns_constraints, []), iterations, destruction_fun, nil)
  end


  def lns(_instance, 0, _destruction_fun, acc_results) do
    acc_results
  end

  def lns(%{model: model, lns_constraints: constraints} = instance, iterations, destruction_fun, acc_results) when iterations > 0 do
    ## Run iteration
    lns_model = MinizincModel.merge(model, constraints)
    iteration_results = MinizincInstance.run(%{instance | model: lns_model})
    case MinizincResults.get_status(iteration_results) do
      status when status in [:satisfied, :optimal] ->
        ## Add LNS constraints
        constraints = lns_constraints(
                      destruction_fun,
                      MinizincResults.get_last_solution(iteration_results),
                      ## TODO: take 'method' from instance
                      MinizincResults.get_method(iteration_results)
                   )
        updated_instance = Map.put(instance, :lns_constraints, constraints)
        lns(updated_instance, iterations - 1, destruction_fun, iteration_results)
      _no_solution ->
        acc_results
    end
  end


  ## Apply destruction function and create a text representation of LNS constraints
  def lns_constraints(destruction_fun, solution, method) do
      Enum.map(destruction_fun.(solution, method),
        fn c -> {:model_text, c} end)
  end

  def lns_objective_constraint(solution, objective_var, method) when method in [:maximize, :minimize] do
      objective_value = MinizincResults.get_solution_value(solution, objective_var)
      inequality = if method == :maximize, do: ">", else: "<"
      constraint("#{objective_var} #{inequality} #{objective_value}")
  end

  ## Randomly choose (1 - rate)th part of values
  ## and return them keyed with their indices.
  ##
  def destroy(values, rate, offset \\ 0) when is_list(values) do
    Enum.take_random(Enum.with_index(values, offset),
      round(length(values) * (1 - rate)))
  end

  ## Takes the name and solution for an array of decision variables and
  ## creates the list of constraints for variables that will be fixed for the next iteration of solving.
  ## The destruction_rate (a value between 0 and 1) states the percentage of the variables in the
  ## the array that should be 'dropped'.
  ##
  def destroy_var(variable_name, values, destruction_rate, offset \\0) when is_binary(variable_name) do
    ## Randomly choose (1 - destruction_rate)th part of values to fix...
    ## Generate constraints
    list_to_lns_constraints(variable_name, destroy(values, destruction_rate, offset))
  end

  def list_to_lns_constraints(variable_name, values) do
    Enum.join(
      Enum.map(values,
        fn {d, idx} -> lns_constraint(variable_name, idx, d) end))
  end

  defp lns_constraint(varname, idx, val) do
    constraint("#{varname}[#{idx}] = #{val}")
  end



end
