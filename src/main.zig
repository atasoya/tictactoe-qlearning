const std = @import("std");
const randomAgent = @import("randomAgent.zig");
const tictactoe = @import("tictactoe.zig");
const qlearning = @import("qlearning.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const rng_impl: std.Random.IoSource = .{ .io = io };
    const secureRand = rng_impl.interface();

    var debug_allocator = std.heap.DebugAllocator(.{}){};
    defer _ = debug_allocator.deinit();

    const allocator = debug_allocator.allocator();

    var qAgent = qlearning.Agent.init(allocator);
    defer qAgent.deinit();

    const episodes = 100_000;

    var q_wins: usize = 0;
    var random_wins: usize = 0;
    var draws: usize = 0;

    for (0..episodes) |episode| {
        var gameState = tictactoe.TicTacToeState{};

        while (!tictactoe.isGameWon(&gameState) and !tictactoe.isDraw(&gameState)) {
            // Q-agent turn
            const old_state_key = qlearning.getStateKey(gameState.board);

            const action_index = try qAgent.chooseAction(secureRand, old_state_key);
            const action = qlearning.actionIndexToMove(action_index);

            tictactoe.move(&gameState, action);

            // If Q-agent ended the game, update immediately
            if (tictactoe.isGameWon(&gameState) or tictactoe.isDraw(&gameState)) {
                const new_state_key = qlearning.getStateKey(gameState.board);

                const reward = qlearning.rewardFor(
                    gameState.winner,
                    1,
                    tictactoe.isDraw(&gameState),
                );

                try qAgent.update(
                    old_state_key,
                    action_index,
                    reward,
                    new_state_key,
                );

                break;
            }

            // Random opponent turn
            const random_action = randomAgent.randomAction(secureRand, &gameState);
            tictactoe.move(&gameState, random_action);

            // Now update Q-agent AFTER opponent response
            const new_state_key = qlearning.getStateKey(gameState.board);

            const reward = qlearning.rewardFor(
                gameState.winner,
                1,
                tictactoe.isDraw(&gameState),
            );

            try qAgent.update(
                old_state_key,
                action_index,
                reward,
                new_state_key,
            );
        }

        if (gameState.winner == 1) {
            q_wins += 1;
        } else if (gameState.winner == 2) {
            random_wins += 1;
        } else {
            draws += 1;
        }

        if (episode % 1000 == 0) {
            std.debug.print(
                "Episode {d}: Q wins={d}, Random wins={d}, Draws={d}, Q-table states={d}, epsilon={d:.3}\n",
                .{
                    episode,
                    q_wins,
                    random_wins,
                    draws,
                    qAgent.q_table.count(),
                    qAgent.epsilon,
                },
            );
        }
    }

    std.debug.print("\nTraining finished.\n", .{});
    std.debug.print("Q wins: {d}\n", .{q_wins});
    std.debug.print("Random wins: {d}\n", .{random_wins});
    std.debug.print("Draws: {d}\n", .{draws});
    std.debug.print("Q-table states learned: {d}\n", .{qAgent.q_table.count()});

    // Evaluation phase
    qAgent.epsilon = 0.0;

    var eval_q_wins: usize = 0;
    var eval_random_wins: usize = 0;
    var eval_draws: usize = 0;

    const eval_games = 10_000;

    for (0..eval_games) |_| {
        var gameState = tictactoe.TicTacToeState{};

        while (!tictactoe.isGameWon(&gameState) and !tictactoe.isDraw(&gameState)) {
            if (gameState.current_player == 1) {
                const state_key = qlearning.getStateKey(gameState.board);
                const action_index = try qAgent.bestAction(state_key);
                const action = qlearning.actionIndexToMove(action_index);

                tictactoe.move(&gameState, action);
            } else {
                const action = randomAgent.randomAction(secureRand, &gameState);
                tictactoe.move(&gameState, action);
            }
        }

        if (gameState.winner == 1) {
            eval_q_wins += 1;
        } else if (gameState.winner == 2) {
            eval_random_wins += 1;
        } else {
            eval_draws += 1;
        }
    }

    const eval_q_win_rate =
        @as(f64, @floatFromInt(eval_q_wins)) / @as(f64, @floatFromInt(eval_games)) * 100.0;

    const eval_random_win_rate =
        @as(f64, @floatFromInt(eval_random_wins)) / @as(f64, @floatFromInt(eval_games)) * 100.0;

    const eval_draw_rate =
        @as(f64, @floatFromInt(eval_draws)) / @as(f64, @floatFromInt(eval_games)) * 100.0;

    std.debug.print("\nEvaluation after training:\n", .{});
    std.debug.print("Q wins: {d} ({d:.2}%)\n", .{ eval_q_wins, eval_q_win_rate });
    std.debug.print("Random wins: {d} ({d:.2}%)\n", .{ eval_random_wins, eval_random_win_rate });
    std.debug.print("Draws: {d} ({d:.2}%)\n", .{ eval_draws, eval_draw_rate });
    std.debug.print("Q-table states learned: {d}\n", .{qAgent.q_table.count()});
}
