defmodule GameControllerTest do
  use RoboSoccerPlatformWeb.ConnCase

  alias RoboSoccerPlatform.GameController
  alias RoboSoccerPlatform.Player

  @game_state "game_state"

  setup do
    state = %GameController.State{
      aggregation_interval_ms: nil,
      cooperation_metric_function: nil,
      speed_coefficient: nil,
      aggregation_function: nil,
      number_of_aggregations: 500,
      team_states: %{
        "red" => %GameController.State.TeamState{
          robot_connection: nil,
          robot_connection_module: nil,
          current_instruction: %{x: 0.4, y: 0.45},
          current_cooperation_metric: 0.22,
          total_cooperation_metric: 431.44
        },
        "green" => %GameController.State.TeamState{
          robot_connection: nil,
          robot_connection_module: nil,
          current_instruction: %{x: 0.1, y: 0.1},
          current_cooperation_metric: 1.00,
          total_cooperation_metric: 211.22
        }
      },
      player_inputs: %{
        "id1" => %{
          player: %Player{
            id: "id1",
            team: "red",
            username: "player1"
          },
          x: 0.0,
          y: 0.0
        },
        "id2" => %{
          player: %Player{
            id: "id2",
            team: "red",
            username: "player2"
          },
          x: 0.81,
          y: 0.9
        },
        "id3" => %{
          player: %Player{
            id: "id3",
            team: "green",
            username: "player3"
          },
          x: 0.1,
          y: 0.1
        }
      },
      player_pids: nil,
      game_state: :started,
      aggregation_timer: nil,
      room_code: "5555",
      game_dashboard_pid: nil
    }

    {:ok, state: state}
  end

  test "handle_call :get_game_state", %{state: state} do
    assert match?(
      {:reply, :started, _},
      GameController.handle_call(:get_game_state, nil, state)
    )

    refute match?(
      {:reply, :stopped, _},
      GameController.handle_call(:get_game_state, nil, state)
    )
  end

  test "handle_call :room_code_correct? for correct code", %{state: state} do
    assert match?(
      {:reply, true, _},
      GameController.handle_call(
        {:room_code_correct?, "5555"}, nil, state
      )
    )
  end

  test "handle_call :room_code_correct? for incorrect code", %{state: state} do
    assert match?(
      {:reply, false, _},
      GameController.handle_call(
        {:room_code_correct?, "1111"}, nil, state
      )
    )
  end

  test "handle_call :init_game_dashboard", %{state: state} do
    game_dashboard_pid = "pid"

    expected_steering_state = %{
      player_inputs: state.player_inputs,
      team_states: state.team_states,
      number_of_aggregations: 500
    }

    expected_reply = {
      :reply,
      {
        "5555",
        expected_steering_state,
        :started
      },
      %GameController.State{state | game_dashboard_pid: game_dashboard_pid}
    }

    assert expected_reply ==
      GameController.handle_call(
        {:init_game_dashboard, game_dashboard_pid}, nil, state
      )

  end

  test "handle_cast :reset_stats", %{state: state} do
    {:noreply, new_state} = GameController.handle_cast(:reset_stats, state)

    assert new_state.number_of_aggregations == 0
    assert new_state.team_states["green"].total_cooperation_metric == 0.0
    assert new_state.team_states["red"].total_cooperation_metric == 0.0
  end

  test "handle_cast :update_player_input existing player", %{state: state} do
    {:noreply, new_state} = GameController.handle_cast({:update_player_input, "id1", 0.2, 0.7}, state)

    assert new_state.player_inputs["id1"].x == 0.2
    assert new_state.player_inputs["id1"].y == 0.7
  end

  test "handle_cast :update_player_input nonexisting player", %{state: state} do
    {:noreply, new_state} = GameController.handle_cast({:update_player_input, "fake_id", 0.2, 0.7}, state)

    assert "fake_id" not in new_state.player_inputs
  end

  test "handle_info kick player that is not in game", %{state: state} do
    {:noreply, new_state} =
      GameController.handle_info(
        %{
          topic: @game_state,
          event: "kick",
          payload: %{player_id: "wrong_id"}
        },
        state
      )

    refute Map.has_key?(state.player_inputs, "wrong_id")
    refute Map.has_key?(new_state.player_inputs, "wrong_id")
  end
end
